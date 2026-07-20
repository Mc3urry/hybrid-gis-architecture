#!/usr/bin/env python3
"""
Utility Network (system of record) -> PostGIS sync.

The high-frequency object is the OUTAGE: during a storm this runs every few
minutes. Network geometry (feeders) changes rarely and syncs on a slow cadence
with the same pattern.

Modes:
  --simulate            (default) mutate outages locally to mimic OMS activity:
                        restore some active outages, open new ones. Lets the whole
                        pipeline be exercised with zero Esri access.
  --service-url URL     pull outages from a real ArcGIS feature service layer
                        (Enterprise or AGOL stand-in) via REST and upsert.
                        URL is the layer endpoint, e.g. .../FeatureServer/0
  --network-url URL     the slow-cadence leg (ADR-004): pull FEEDERS from an
                        ArcGIS feature service layer and upsert network
                        geometry. Run daily/weekly, in contrast to the
                        minutes-cadence outage sync.

Either way, the run finishes with REFRESH MATERIALIZED VIEW CONCURRENTLY so the
public outage map updates with zero read downtime. Every run is logged to
sor.sync_log.

Usage:
  python sync_from_sor.py --simulate
  python sync_from_sor.py --service-url https://services.arcgis.com/.../FeatureServer/0
"""
import argparse
import json
import os
import sys

import psycopg2
import requests

DSN = os.environ.get(
    "PUBLIC_GIS_DSN",
    "host=localhost port=5432 dbname=public_gis user=gis password=gis_dev_password",
)

UPSERT_OUTAGE = """
INSERT INTO sor.outages (outage_id, feeder_id, status, cause_category, crew_notes,
                         started_at, est_restoration, customers_affected, geom)
VALUES (%s, %s, %s, %s, %s, coalesce(%s::timestamptz, now()), %s::timestamptz, %s,
        ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326))
ON CONFLICT (outage_id) DO UPDATE SET
    status             = EXCLUDED.status,
    cause_category     = EXCLUDED.cause_category,
    crew_notes         = EXCLUDED.crew_notes,
    est_restoration    = EXCLUDED.est_restoration,
    customers_affected = EXCLUDED.customers_affected,
    geom               = EXCLUDED.geom;
"""


UPSERT_FEEDER = """
INSERT INTO sor.feeders (feeder_id, substation_id, voltage_class, phase,
                         customers_served, last_edited, geom)
VALUES (%s, %s, %s, %s, %s, now(),
        ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326))
ON CONFLICT (feeder_id) DO UPDATE SET
    substation_id    = COALESCE(EXCLUDED.substation_id, sor.feeders.substation_id),
    voltage_class    = COALESCE(EXCLUDED.voltage_class, sor.feeders.voltage_class),
    phase            = COALESCE(EXCLUDED.phase, sor.feeders.phase),
    -- feed may omit sensitive fields (view-based sync); NULLs preserve local values
    customers_served = COALESCE(EXCLUDED.customers_served, sor.feeders.customers_served),
    last_edited      = now(),
    geom             = EXCLUDED.geom;
"""


def log_start(cur, source):
    cur.execute("INSERT INTO sor.sync_log (source) VALUES (%s) RETURNING run_id", (source,))
    return cur.fetchone()[0]


def log_finish(cur, run_id, rows, status="ok"):
    cur.execute(
        "UPDATE sor.sync_log SET finished_at = now(), rows_upserted = %s, status = %s "
        "WHERE run_id = %s",
        (rows, status, run_id),
    )


def refresh(cur):
    cur.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY public.outages_public")
    cur.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY public.feeders_public")


def simulate(cur):
    """Mimic OMS activity: restore ~30% of active outages, open 5 new ones."""
    cur.execute(
        """
        UPDATE sor.outages
        SET status = 'restored', restored_at = now()
        WHERE status = 'active' AND random() < 0.3
        """
    )
    restored = cur.rowcount
    cur.execute(
        """
        INSERT INTO sor.outages (outage_id, feeder_id, status, cause_category, crew_notes,
                                 est_restoration, customers_affected, geom)
        SELECT
            'OUT' || lpad((floor(random()*9000000) + 1000000)::int::text, 7, '0'),
            d.feeder_id,
            'active',
            (ARRAY['equipment','weather','vegetation','vehicle','planned'])[1 + floor(random()*5)::int],
            'internal crew notes - not public',
            now() + (random() * interval '8 hours'),
            (10 + floor(random()*800))::int,
            d.geom
        FROM (SELECT * FROM sor.devices ORDER BY random() LIMIT 5) d
        ON CONFLICT (outage_id) DO NOTHING
        """
    )
    return restored + cur.rowcount


def esri_geometry_to_geojson(g):
    """Convert Esri JSON geometry to GeoJSON. Not every ArcGIS layer serves
    f=geojson, but every layer serves Esri JSON — so the sync requests the
    universal format and converts (found the hard way; see operations.md)."""
    if g is None:
        return None
    if "x" in g:
        return {"type": "Point", "coordinates": [g["x"], g["y"]]}
    if "paths" in g:
        paths = g["paths"]
        if len(paths) == 1:
            return {"type": "LineString", "coordinates": paths[0]}
        return {"type": "MultiLineString", "coordinates": paths}
    if "rings" in g:
        return {"type": "Polygon", "coordinates": g["rings"]}
    raise ValueError(f"unsupported esri geometry: {list(g)}")


def pull_feeders(cur, service_url):
    """Page through an ArcGIS REST feeders layer (Esri JSON) and upsert."""
    rows, offset, page = 0, 0, 1000
    while True:
        r = requests.get(
            f"{service_url.rstrip('/')}/query",
            params={
                "where": "1=1",
                "outFields": "*",
                "outSR": 4326,
                "f": "json",
                "resultOffset": offset,
                "resultRecordCount": page,
            },
            timeout=60,
        )
        r.raise_for_status()
        body = r.json()
        if "error" in body:
            raise RuntimeError(f"service error: {body['error']}")
        features = body.get("features", [])
        if not features:
            break
        for f in features:
            p = f.get("attributes", {})
            geom = esri_geometry_to_geojson(f.get("geometry"))
            cur.execute(
                UPSERT_FEEDER,
                (
                    str(p.get("feeder_id") or p.get("FEEDER_ID")),
                    p.get("substation_id") or p.get("SUBSTATION_ID"),
                    p.get("voltage_class") or p.get("VOLTAGE_CLASS"),
                    p.get("phase") or p.get("PHASE"),
                    p.get("customers_served") or p.get("CUSTOMERS_SERVED"),
                    json.dumps(geom),
                ),
            )
            rows += 1
        offset += page
    return rows


def pull_arcgis(cur, service_url):
    """Page through an ArcGIS REST feature layer as GeoJSON and upsert outages."""
    rows, offset, page = 0, 0, 1000
    while True:
        r = requests.get(
            f"{service_url.rstrip('/')}/query",
            params={
                "where": "1=1",
                "outFields": "*",
                "f": "geojson",
                "resultOffset": offset,
                "resultRecordCount": page,
            },
            timeout=60,
        )
        r.raise_for_status()
        features = r.json().get("features", [])
        if not features:
            break
        for f in features:
            p = f.get("properties", {})
            cur.execute(
                UPSERT_OUTAGE,
                (
                    str(p.get("outage_id") or p.get("OUTAGE_ID") or p.get("OBJECTID")),
                    p.get("feeder_id") or p.get("FEEDER_ID"),
                    (p.get("status") or "active").lower(),
                    p.get("cause_category") or p.get("CAUSE"),
                    p.get("crew_notes"),
                    p.get("started_at"),
                    p.get("est_restoration"),
                    p.get("customers_affected") or p.get("CUST_AFFECTED") or p.get("customer_affected"),
                    json.dumps(f["geometry"]),
                ),
            )
            rows += 1
        offset += page
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--simulate", action="store_true")
    ap.add_argument("--service-url")
    ap.add_argument("--network-url")
    args = ap.parse_args()
    if not args.service_url and not args.network_url:
        args.simulate = True

    source = args.network_url or args.service_url or "simulate"
    conn = psycopg2.connect(DSN)
    conn.autocommit = True
    cur = conn.cursor()
    run_id = log_start(cur, source)
    try:
        if args.network_url:
            rows = pull_feeders(cur, args.network_url)
            kind = "feeder"
        elif args.simulate:
            rows, kind = simulate(cur), "outage"
        else:
            rows, kind = pull_arcgis(cur, args.service_url), "outage"
        refresh(cur)
        log_finish(cur, run_id, rows)
        print(f"run {run_id}: {rows} {kind} rows changed from {source}; public views refreshed")
    except Exception as e:
        log_finish(cur, run_id, 0, status=f"error: {e}")
        print(f"run {run_id} FAILED: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
