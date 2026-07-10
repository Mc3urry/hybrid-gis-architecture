# ADR-006: Scaling and failure modes per tier

Status: Accepted

## Context
For an outage map, peak load and peak importance are the same moment: the
storm. An architecture that cannot answer "what breaks first at 100x?" is a
diagram, not a design.

## Decision / Analysis
- Martin (stateless): scales horizontally behind a load balancer
  (k8s/martin.yaml), with a CDN absorbing most tile requests — grid-snapped
  outage tiles are identical for every viewer, so cache hit rates are high.
  Failure: restart; no state lost.
- PostGIS (read-only workload): scale up, then read replicas for tile servers.
  Failure: the public map goes stale/down but the system of record and OMS are
  untouched — a public-tier outage never corrupts network data.
- Sync: idempotent upserts + sync_log make it safely re-runnable; a missed run
  means staleness, not loss. Alert on sync_log.status and on staleness age.
- ArcGIS Enterprise: vendor HA patterns (multi-machine, standby); documented
  in the deployment topology, out of scope for the open half.
- GeoServer: low traffic; single instance with restart policy is acceptable.

## Consequences
+ Failure domains are isolated: storm-scale public load physically cannot
  reach the Utility Network.
- CDN adds cache-invalidation coupling to the sync cadence (documented:
  invalidate on refresh, or set max-age to the outage sync interval).
