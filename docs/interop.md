# OGC Interoperability Matrix

The bridge between the Esri and open-source halves, proven in both
directions. Same data, multiple standards, multiple clients.

| # | Producer | Standard/API | Consumer | Status | Notes |
|---|----------|--------------|----------|--------|-------|
| 1 | GeoServer (PostGIS views) | WFS 2.0 / GeoJSON | Browser (raw request) | ☑ done | GetFeature on public:outages_public returns boundary-filtered GeoJSON |
| 2 | GeoServer | WFS 2.0 | QGIS | ☐ | |
| 3 | GeoServer | WFS 2.0 | ArcGIS Pro | ☐ | Esri client consuming open-source services — the money screenshot |
| 4 | AGOL hosted view | ArcGIS REST / GeoJSON | sync_from_sor.py | ☑ done | The Phase 3 pipeline (see ADR-004 observed consequences) |
| 5 | AGOL hosted view | ArcGIS REST | QGIS | ☐ | |
| 6 | ArcGIS Enterprise | WMS / OGC API - Features | QGIS + MapLibre | ☐ blocked | Awaiting Phase 4 (UTD license) |
| 7 | Martin (PostGIS views) | Vector tiles (MVT) | MapLibre | ☑ done | The public map itself |

## Part 1 — GeoServer publishing (done)

- Workspace `public`; PostGIS store `public_gis` connecting as `svc_geoserver`
  (host `postgis`, i.e. the Docker service name — localhost inside a container
  is the container).
- The store's publishable-layer list showed exactly feeders_public and
  outages_public and nothing else: svc_geoserver inherits only tile_reader,
  so the boundary is visible in GeoServer's own UI.
- Both layers published with declared SRS EPSG:4326, bounds computed from data.
- Verified: Layer Preview (OpenLayers) + raw WFS GetFeature as GeoJSON.

## Part 2 — QGIS (next)

Add WFS connection: http://localhost:8080/geoserver/public/ows
Add AGOL view via ArcGIS REST Server connection. Screenshot both in one project.
