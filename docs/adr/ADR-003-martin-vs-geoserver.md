# ADR-003: Martin for tiles, GeoServer only where the full OGC surface is needed

Status: Accepted

## Context
GeoServer can also serve vector tiles, so a single-server design was on the
table. But GeoServer is a heavy JVM app with a large config surface, while
Martin is a single-purpose Rust binary that auto-discovers PostGIS geometry.

## Decision
Martin is the default tile path (fast, near-zero config, stateless, scales
horizontally — the storm-response tier). GeoServer runs alongside only to
expose WMS/WFS/OGC API - Features for consumers that require standards
endpoints (neighboring agencies, regulators, QGIS/Pro users).

## Consequences
+ The high-traffic path (tiles) is the simplest, cheapest component.
+ Standards consumers still get full OGC.
- Two service components instead of one (accepted: each is minimal for its job).

## Observed consequences (post-implementation)
Auto-discovery is Martin's best feature and its sharpest edge: it silently
skips geometry columns without typmod metadata. This took the public tier
down on first bring-up — see ADR-008 and OPS-001 for the failure, fix, and
the typed-column contract that resulted.
