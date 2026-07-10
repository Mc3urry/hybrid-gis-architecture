# ADR-004: Two-cadence scheduled sync now; event-driven as the storm-mode path

Status: Accepted

## Context
Two very different freshness requirements share one pipeline. Outages: public
expectation is minutes. Network geometry (feeders): changes via engineering
work orders; daily is fine. Options: (a) scheduled REST pull, (b) event-driven
push (webhooks/queue), (c) DB-level replication from the enterprise
geodatabase's PostgreSQL.

## Decision
Scheduled pull (sync_from_sor.py) at two cadences: minutes for the outage
layer, daily for network geometry. Upserts are idempotent; both public views
refresh CONCURRENTLY; every run logs to sor.sync_log.
Option (c) is rejected outright — it would couple to Esri's internal UN schema
(a moving, undocumented target) and bypass the service-layer contract.
Option (b) is the documented evolution path when a real OMS integration exists.

## Consequences
+ Simple, observable, restartable; REST contract keeps sides decoupled.
+ CONCURRENTLY refresh = zero public read downtime, even mid-storm.
- Outage freshness bounded by schedule interval (accepted at minutes-cadence;
  tighten toward (b) if the OMS can push).
- Full-table paging is O(n); move to editedDate-filtered incremental pulls as
  outage volume grows.
