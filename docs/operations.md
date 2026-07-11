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

## OPS-003 — "Network split-brain" that was actually a wiped GeoServer config

**Date:** 2026-07-11 · **Severity:** GeoServer WFS unreachable from QGIS/curl/Python · **See:** interop matrix row 2

**Symptom.** QGIS WFS failed with an empty "server replied:". curl and
Python on 127.0.0.1 got bare 404s with a banner-obfuscated Tomcat page
("i_am_a_teapot"). The browser had loaded GetCapabilities fine — earlier.

**Wrong turns taken (preserved on purpose).**
1. Suspected localhost-vs-127.0.0.1 resolution. Wrong, but the test was right.
2. Suspected proxies. getproxies() == {} killed that cleanly.
3. netstat showed IPv4 and IPv6 loopback listeners with different PIDs and
   built a "split-brain between Docker's two port proxies" theory. Both
   PIDs turned out to be Docker's own components (com.docker.backend and
   wslrelay) doing their normal jobs.
4. Moved GeoServer to port 8085. Reasonable hygiene, didn't fix it.

**Actual root cause (found in 30 seconds of docker logs).**
`WARN [servlet.PageNotFound] - No mapping for GET /geoserver/public/ows` —
GeoServer had no workspace named `public`. The admin-UI configuration had
been wiped: the persistence volume was added to compose earlier, but the
container wasn't recreated until later (the port change), at which point
the empty volume mounted over the config. The browser's earlier success ran
against the old container before recreation. A workspace-qualified URL for
a nonexistent workspace returns a Tomcat-level 404 (the osgeo image ships a
banner-hardened Tomcat, hence the teapot).

**Fix.** Re-created workspace/store/layers once; config now persists in the
geoserver_data volume (verified across `docker compose restart geoserver`).
Full capabilities confirmed over plain IPv4 afterward.

**Standing rules.**
- `docker logs <container>` is debugging step ONE for any service 404 —
  the server tells you what it received and what it thinks is missing.
  We theorized about the network for an hour; the answer was one log line.
- Compose file changes do nothing until the container is recreated; the
  recreation happens on the NEXT `up -d`, possibly much later. Know when
  your config changes actually take effect.
- An error page in the wrong flavor (bare Tomcat 404 from a GeoServer URL)
  means the request didn't reach the application layer you expected —
  in this case GeoServer's dispatcher rejecting an unknown workspace.
- Timing matters in diagnosis: "the browser worked" was evidence from
  BEFORE the state change. Re-verify old evidence after anything restarts.

---

## OPS-004 — Git index corrupted by cloud-sync (OneDrive) mid-write

**Date:** 2026-07-11 · **Severity:** git unusable (`fatal: index file corrupt`) · **Data loss: none**

**Symptom.** `git status` failed with `error: bad index file sha1 signature /
fatal: index file corrupt`. Everything of value had been pushed to the
remote beforehand.

**Root cause.** The repo lives inside a OneDrive-synced folder; the sync
client and git wrote .git/index concurrently. The index is a rebuildable
cache of the staging area — corruption there is cosmetic as long as
.git/objects is intact (`git fsck` confirmed it was).

**Fix.** Delete and rebuild: `rm .git/index && git reset`. fsck clean
afterward; working tree unaffected.

**Standing rules.**
- The index is disposable; objects are not. Diagnose with `git fsck` before
  panicking: "index corrupt" and "object corrupt" are different severities.
- Push frequently precisely because the local .git sits on synced storage —
  the remote is the real safety net.
- If this recurs, either move the working clone outside OneDrive or exclude
  the .git folder from sync; the OneDrive copy of committed work is
  redundant with GitHub anyway.

---

*(Add future entries above this line: OPS-005, OPS-006, ...)*
