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

## Observed consequences (post-implementation, ArcGIS Online integration)
- The sync deliberately reads a public *view* of the source layer, not the
  source itself: the pipeline is an anonymous consumer and never holds
  credentials or sees behind the boundary. crew_notes was verified absent
  from the feed before the pipeline ever ingested it (defense at two layers,
  cf. ADR-005).
- Filtered views break state-transition propagation: a view filtered to
  status = 'active' would silently drop rows the moment they flip to
  'restored', so the sync would never see the transition and the local copy
  would stay active forever. Rule: the FEED must carry all states (hide
  fields, not rows); state filtering belongs at the final serving boundary
  (the outages_public matview). Verified with a seeded 'restored' outage:
  present in sor.outages, correctly absent from the public map.
- Field mapping is a real contract: the REST feed's property names must match
  the upsert's lookups (lowercase here), and FK integrity (feeder_id must
  exist in sor.feeders) means upstream data quality failures surface as sync
  errors in sor.sync_log — which is where you want them.
