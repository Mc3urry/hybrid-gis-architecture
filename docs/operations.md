# Operations Runbook

Incident-driven notes. Every entry: symptom -> diagnosis -> fix -> standing rule.

---

## OPS-001 — Blank public map: Martin silently skipped untyped view geometry

**Date:** 2026-07-10 · **Severity:** public tier fully down (no tiles) · **See:** ADR-008

**Symptom.** http://localhost:8088 rendered only the basemap. No feeders, no
outages. No errors in the browser console beyond 404s on tile URLs; no errors
from Martin or PostGIS.

**Diagnosis path.**
1. Checked http://localhost:3000/catalog — neither `feeders_public` nor
   `outages_public` was listed. So the problem was upstream of the web map.
2. Checked the views in psql: `\d public.outages_public` showed the geom
   column typed as bare `geometry` — no Point/4326 typmod.
3. Root cause: ST_SnapToGrid / ST_SimplifyPreserveTopology return untyped
   geometry; the matview column inherited that; Martin's auto-discovery
   skips columns it cannot type — silently.

**Fix.** Explicit typmod casts in db/init/03_public_views.sql:
`ST_SnapToGrid(geom, 0.002)::geometry(Point, 4326)` and
`ST_SimplifyPreserveTopology(geom, 0.0002)::geometry(LineString, 4326)`.
Then `docker compose down -v && docker compose up -d` (init SQL only runs on
a fresh volume) and hard-refresh the browser (cached 404 tiles).

**Standing rules.**
- Every public view geometry column carries an explicit `::geometry(Type, SRID)` cast.
- The Martin catalog check is step one of every bring-up and every debugging
  session: verify each layer's catalog before touching the client.
- Schema changes under db/init/ require a volume wipe to take effect; document
  any change that needs `down -v`.

---

*(Add future entries above this line: OPS-002, OPS-003, ...)*
