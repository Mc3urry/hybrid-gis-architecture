# Setup & Reproduction Guide

How to stand up this reference architecture from a clean clone. Each stage
ends with a verification step — run them in order; they isolate faults by
tier. Troubleshooting for every failure encountered while building this is
in [docs/operations.md](docs/operations.md).

## Prerequisites

- Docker Desktop, Python 3.10+, Git
- Optional: QGIS (OGC test client), R 4.x (analytics), an ArcGIS Online or
  ArcGIS Enterprise account (system-of-record integration)

## 1. Stand up the open-source stack

```bash
docker compose up -d
docker compose ps        # wait for postgis: healthy; geoserver takes ~90s
```

Verify in this order:

1. **PostGIS** — `docker exec -it hybrid-postgis psql -U gis -d public_gis`
   - `\dt sor.*` → substations, feeders, devices, service_points, outages
   - `SELECT count(*) FROM sor.feeders;` → 320 (synthetic DFW network)
   - `\d public.outages_public` → note which columns are absent; that is the
     trust boundary (see ADR-005)
2. **Martin** — http://localhost:3000/catalog must list `feeders_public`
   and `outages_public`. **If either view is missing, stop** — nothing
   downstream can work (ADR-008 / OPS-001). This catalog check is always
   debugging step one.
3. **Public map** — http://localhost:8088: feeders by voltage class, active
   outages sized by customer band.
4. **GeoServer** — http://localhost:8085/geoserver (admin/geoserver).

Notes: the database only runs `db/init/*.sql` on a fresh volume — schema
changes require `docker compose down -v` (which also wipes GeoServer config;
see OPS-003). Dev credentials are placeholders by design (ADR-005).

## 2. Exercise the sync pipeline

```bash
cd sync && pip install -r requirements.txt
python sync_from_sor.py --simulate
```

Reload the map: some outages restore, new ones appear — that visible change
is the full path (upstream edit → sor.outages → concurrent matview refresh →
tiles → client). Audit trail: `SELECT * FROM sor.sync_log;`

For continuous operation, schedule it (cron / Windows Task Scheduler) at a
minutes-cadence — the two-cadence design is documented in ADR-004.

## 3. Connect a real ArcGIS source

The sync consumes any ArcGIS feature service layer over REST — AGOL and
Enterprise expose the identical contract (that equivalence is the point of
the service-layer boundary, ADR-004):

1. Publish a hosted point layer with fields matching `sor.outages`
   (outage_id, feeder_id, status, cause_category, customers_affected,
   crew_notes). Verify actual field *Names* against the script's lookups
   before first sync (OPS-002).
2. Create a **view layer** that hides `crew_notes`. Do not row-filter by
   status — the feed must carry all states; state filtering belongs at the
   serving boundary (ADR-004, observed consequences). Share the view
   publicly; keep the source private.
3. ```bash
   python sync_from_sor.py --service-url "https://services.arcgis.com/<org>/arcgis/rest/services/<view>/FeatureServer/0"
   ```
4. Edit a feature upstream, re-run, refresh the public map.

## 4. Publish OGC services (GeoServer)

1. Create a login service account that inherits only the read-only role —
   already provisioned in the schema as `svc_geoserver` / tile_reader.
2. GeoServer admin → workspace `public` (default) → PostGIS store: host
   **`postgis`** (the Docker service name — localhost inside a container is
   the container), db `public_gis`, user `svc_geoserver`.
3. The publishable-layer list should show exactly the two public views —
   the database role making the boundary visible in GeoServer's own UI.
4. Publish both (SRS EPSG:4326, compute bounds), then verify raw WFS:
   ```
   http://localhost:8085/geoserver/public/ows?SERVICE=WFS&REQUEST=GetCapabilities
   ```

## 5. Verify with standards clients

- **QGIS**: Add WFS Layer → URL `http://127.0.0.1:8085/geoserver/public/ows`,
  version 2.0. Add the AGOL view via ArcGIS REST Server connection (service
  URL ending `/FeatureServer`, no auth).
- **ArcGIS Pro**: Insert → Connections → Server → New WFS Server → same URL,
  version 2.0.0.
- Consumption results and evidence: [docs/interop.md](docs/interop.md).

## 6. The ArcGIS Enterprise half

Component mapping, install order, federation, and Utility Network
deployment: [docs/enterprise-deployment.md](docs/enterprise-deployment.md).
Once its services are live, only the `--service-url` changes in step 3 —
nothing else in this stack moves.

## 7. Kubernetes variant (optional)

`k8s/` contains illustrative manifests: PostGIS as a StatefulSet, Martin as
a horizontally scaled Deployment (the storm-response tier, ADR-006). Apply
postgis.yaml then martin.yaml on any local cluster.

## 8. Analytics consumer

```bash
Rscript analytics/outage_analysis.R
```

Reads the same PostGIS as the tile servers; outputs a cause summary and a
map plot. Aggregations surface missing data explicitly rather than hiding
it (OPS-002).
