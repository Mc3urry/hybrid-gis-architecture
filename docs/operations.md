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

## OPS-002 — Silent NULLs from a field-name drift in the AGOL feed

**Date:** 2026-07-11 · **Severity:** data quality (one attribute NULL for all synced rows) · **See:** ADR-004 field-mapping contract

**Symptom.** R analytics (outage_analysis.R) reported NA for all customer
sums and ggplot dropped 7 rows. SQL confirmed: every AGOL-synced outage had
customers_affected = NULL. Every other field mapped fine. No errors anywhere
in the pipeline.

**Diagnosis path.**
1. psql: NULLs confined to rows with outage_id LIKE 'AGOL%' — so the AGOL
   leg, not the schema or the simulate path.
2. AGOL item -> Data -> Fields: the field's real Name was
   `customer_affected` (singular) — created with a typo; the sync looks up
   `customers_affected` (plural). dict.get() returned None, the upsert wrote
   NULL, and nothing complained.

**Fix.** Added `customer_affected` as a lookup fallback in sync_from_sor.py.
Hardened the R aggregations with na.rm = TRUE plus an explicit n_missing
column — analytics should SURFACE upstream data quality problems, not be
blanked out by them or silently paper over them.

**Standing rules.**
- After creating any AGOL/Enterprise layer, verify actual field Names (not
  aliases) against the sync's lookups BEFORE first sync — one f=geojson
  request read carefully costs a minute.
- Aggregations in analytics always use na.rm plus an explicit missing-count
  column: report the hole, don't fall into it.
- Note the pattern: the analyst persona caught what the pipeline could not.
  Downstream consumers are part of the platform's error detection.

---

*(Add future entries above this line: OPS-003, OPS-004, ...)*
