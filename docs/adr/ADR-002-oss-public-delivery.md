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
- Two stacks to operate (accepted: that is the hybrid tradeoff, and the point).
