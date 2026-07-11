# ADR-002: Open-source vector tiles for the public outage map

Status: Accepted

## Context
Outage map traffic is anonymous, read-only, and storm-driven: a major weather
event can produce a 100x viewer spike overnight, then subside for months.
Esri delivery sized for that peak means paying peak infrastructure/licensing
year-round, or architecting around per-user licensing designed for staff.

## Decision
Public delivery is served by Martin (vector tiles) and GeoServer (OGC services)
from a PostGIS projection of the system of record. MapLibre GL on the client.
A CDN in front of Martin absorbs the storm spike.

## Consequences
+ Zero marginal license cost per viewer; the spike scales at infra cost only.
+ Vector tiles: client styling, small payloads, CDN-cacheable.
+ Public load physically cannot touch the system of record (see ADR-006).
- We own uptime of the public tier — precisely when it matters most (storms).
  Mitigated: stateless tier + CDN + read-only workload.
- Two stacks must be operated (accepted: this is the tradeoff inherent to a hybrid architecture).

## Observed consequences (post-implementation)
- Zero-license public delivery is running in practice: 320-feeder network +
  live outages served as vector tiles to an anonymous MapLibre client, with
  the sync updating it on a minutes cadence.
- The storm-scale claim is modeled, not yet load-tested — the economics are
  made explicit in ../cost-model.md, including the honest boundary where
  Esri-hosted delivery remains defensible.
- Grid-snapped, band-aggregated tiles are identical for every viewer, which
  is what makes the CDN-absorbs-the-storm strategy credible; no CDN is
  fronted in the reference deployment yet.
- "We own uptime" proved true immediately: the public tier's failures so far
  (OPS-001, OPS-003) were ours to diagnose — and both post-mortems made the
  system and its documentation stronger.
