#!/usr/bin/env python3
"""
Export the network layers from PostGIS as GeoJSON for publishing to the
ArcGIS system of record.

Produces one FeatureCollection per layer in ./export/ :
  substations.geojson, feeders.geojson, devices.geojson,
  service_points.geojson

Each file is uploaded to ArcGIS Online / Enterprise as a hosted feature
layer (New item -> upload the .geojson -> publish). Property names are
preserved exactly on upload; verify them against the sync script's lookups
before the first network sync (see OPS-002).

Usage:
  python export_network.py
"""
import json
import os

import psycopg2

DSN = os.environ.get(
    "PUBLIC_GIS_DSN",
    "host=localhost port=5432 dbname=public_gis user=gis password=gis_dev_password",
)

LAYERS = {
    "substations": """
        SELECT substation_id, name, voltage_class, ST_AsGeoJSON(geom)
        FROM sor.substations""",
    "feeders": """
        SELECT feeder_id, substation_id, voltage_class, phase,
               customers_served, ST_AsGeoJSON(geom)
        FROM sor.feeders""",
    "devices": """
        SELECT device_id, feeder_id, device_type, ST_AsGeoJSON(geom)
        FROM sor.devices""",
    "service_points": """
        SELECT service_point_id, device_id, account_number, customer_name,
               ST_AsGeoJSON(geom)
        FROM sor.service_points""",
}


def main():
    os.makedirs("export", exist_ok=True)
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    for name, sql in LAYERS.items():
        cur.execute(sql)
        cols = [d[0] for d in cur.description[:-1]]
        features = [
            {
                "type": "Feature",
                "properties": dict(zip(cols, row[:-1])),
                "geometry": json.loads(row[-1]),
            }
            for row in cur.fetchall()
        ]
        path = os.path.join("export", f"{name}.geojson")
        with open(path, "w") as f:
            json.dump({"type": "FeatureCollection", "features": features}, f)
        print(f"{path}: {len(features)} features")
    conn.close()


if __name__ == "__main__":
    main()
