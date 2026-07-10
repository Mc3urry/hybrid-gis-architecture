# ADR-008: Typed geometry columns are part of the public view contract

Status: Accepted (from observed failure)

## Context
The public tier depends on Martin auto-discovering the materialized views.
During the first live bring-up, the outage map rendered a basemap and nothing
else. Diagnosis: PostGIS functions that transform geometry —
ST_SnapToGrid, ST_SimplifyPreserveTopology, and most others — return UNTYPED
geometry. A view column defined by such an expression loses its SRID/type
metadata (typmod) in the catalog, and Martin's auto-discovery silently skips
columns it cannot type. Both public views were invisible to the tile server,
so no tiles were ever produced. Nothing errored anywhere.

## Decision
Every geometry column in a public view MUST carry an explicit typmod cast,
e.g. `ST_SnapToGrid(geom, 0.002)::geometry(Point, 4326)`. This is a contract
requirement of the serving tier, not a style preference. Verification of
`http://martin:3000/catalog` (both views listed) is part of the deployment
checklist — it is the earliest point this class of failure is observable.

## Consequences
+ Auto-discovery becomes reliable; the failure mode is eliminated at the
  schema layer, where it belongs.
+ The catalog check gives a cheap smoke test for every future view.
- Every new transformed geometry expression needs a deliberate cast — a
  reviewable, greppable convention (`::geometry(` must appear in every public
  view's geom column).

## Lesson (why this ADR exists)
The boundary views are not just a security control (ADR-005) — they are an
interface consumed by machines. Interfaces need contracts, and this failure
was a contract violation that produced silence instead of an error. Silent
integration failures are found by verifying each layer's catalog/manifest,
not by staring at the final map.
