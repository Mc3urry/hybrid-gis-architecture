# ADR-006: Scaling and failure modes per tier

Status: Accepted

## Context
For an outage map, peak load and peak operational importance coincide
during severe weather. An architecture description is incomplete unless it
identifies, for each tier, the first component expected to fail under a
large demand multiple and the consequences of that failure.

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

## Observed consequences (post-implementation)
- The sync's failure isolation worked on its first real failure: a
  misconfigured service URL produced a clean `error` row in sor.sync_log
  (403, offending URL preserved) with no data corruption and automatic
  recovery on the next scheduled run.
- Dozens of scheduled runs with REFRESH CONCURRENTLY have produced zero
  observed public read downtime; the audit trail in sync_log is itself an
  operational artifact (staleness alerting hooks onto sync_log.status).
- A failure domain missing from the original analysis surfaced: CLICKED
  CONFIGURATION IS STATE. GeoServer's admin-UI config was lost to a
  container recreation because it had no volume (OPS-003) — state needs a
  home just like data does. The same lesson will apply to Portal's content
  directory and Server's configuration store in the Enterprise deployment.
- The horizontal-scaling claim was demonstrated on Kubernetes (Docker
  Desktop): the Martin Deployment scaled 3 -> 5 replicas in seconds via a
  single declarative command, and a manually deleted pod was replaced
  automatically to restore the declared state (see
  ../img/k8s-martin-scale.png). The same exercise surfaced OPS-005 — the
  scaling demo's evidence screenshot revealed the tile tier's
  over-privileged database connection — reinforcing that operational
  exercises double as audits.
- Local dev adds its own failure modes worth separating from architecture:
  dual-stack loopback confusion and cloud-sync git corruption
  (OPS-003/OPS-004) were environment problems, not design problems — but an
  architect must be able to tell the difference quickly, and docker logs /
  git fsck were the discriminators.
