# ADR-007: PostGIS for the derived public tier (vs. file geodatabase or hosted layers)

Status: Accepted

## Context
The derived public-safe dataset needs: SQL-defined projections (the boundary —
banding, snapping, filtering), concurrent refresh under live public load,
direct serving by open-source tile servers, and role-based grants.
Alternatives: file geodatabase exports, or Esri-hosted feature layers.

## Decision
PostGIS. It is simultaneously the storage, the transformation layer
(materialized views), the security boundary (roles/grants), and a native
source for Martin/GeoServer.

## Consequences
+ One component plays four roles; the entire boundary is inspectable in SQL.
+ Standard Postgres operations story (backups, replicas, monitoring).
- File geodatabase exports cannot be served, secured, or refreshed
  concurrently (rejected).
- Hosted feature layers would reintroduce the storm-spike licensing economics
  ADR-002 exists to avoid (rejected).

## Observed consequences (post-implementation)
"The boundary is inspectable in SQL" cuts both ways: the SQL must also honor
the serving tier's contract. Transforming functions (ST_SnapToGrid,
ST_SimplifyPreserveTopology) return untyped geometry and stripped the views'
SRID metadata, making them invisible to Martin. Explicit typmod casts are now
mandatory in every public view — see ADR-008 / OPS-001.
