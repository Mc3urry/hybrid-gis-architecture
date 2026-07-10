# Build Guide — from empty directory to portfolio flagship
## Electric utility network edition

Work the phases in order. Each ends with a **Document** step; those artifacts
are the actual portfolio deliverable. Budget: phases 1–3 in a weekend, phase 4
is the long pole, phases 5–7 are a week of evenings each.

## Phase 0 — Prerequisites

- Docker Desktop (running), Python 3.10+, Git, a code editor.
- QGIS (free) — the OGC standards test client for Phase 5.
- Create a GitHub repo and push this scaffold as the first commit. Commit at
  the end of every phase — the history itself is portfolio evidence.
- CI runs on every push (.github/workflows/ci.yml): a real PostGIS executes
  your init SQL, then asserts row counts, typed geometry (the ADR-008 / OPS-001
  regression test), no sensitive columns in public views, and an end-to-end
  sync run. A green badge on this repo means the boundary holds.

## Phase 1 — Stand up the open-source half (1 evening)

```bash
docker compose up -d
docker compose ps        # all healthy?
```

Verify each tier and understand what you're looking at:

1. **PostGIS**: `docker exec -it hybrid-postgis psql -U gis -d public_gis`
   - `\dt sor.*` — substations, feeders, devices, service_points, outages.
   - `SELECT count(*) FROM sor.feeders;` → 320 across the DFW metroplex.
   - `\d public.outages_public` — note what's absent: crew_notes, exact
     counts, and there is NO public projection of devices or service_points
     at all. That's the boundary.
2. **Martin**: http://localhost:3000/catalog — `feeders_public` and
   `outages_public` auto-discovered. That's why Martin won ADR-003.
   **If either view is missing here, stop — the map cannot work.** The likely
   cause is an untyped geometry column (see ADR-008 / docs/operations.md
   OPS-001). This catalog check is always debugging step one.
3. **Outage map**: http://localhost:8088 — feeders by voltage class, active
   outages sized by customers affected. Click an outage: cause category and
   banded count, nothing sensitive.
4. **GeoServer**: http://localhost:8080/geoserver (admin/geoserver) — Phase 5.

**Document:** screenshot the map and the Martin catalog; a paragraph per
container in a devlog.

## Phase 2 — Exercise the sync pipeline (1 evening)

```bash
cd sync && pip install -r requirements.txt
python sync_from_sor.py --simulate
```

- Reload the map: some outages restored (gone), new ones appeared. That
  visible change IS the pipeline: OMS activity → sor.outages → concurrent
  matview refresh → tiles → public map.
- Audit trail: `SELECT * FROM sor.sync_log;`
- Schedule it every 5 minutes (cron / Task Scheduler) and let it run for a
  day — that's the outage cadence from ADR-004.

**Document:** sequence diagram of one sync run; paste a sync_log excerpt.

## Phase 3 — Connect a real Esri source (1–2 evenings)

AGOL stands in for Enterprise here because the REST contract is identical —
that's the point of the service-layer boundary (ADR-004):

1. In ArcGIS Online, publish a hosted feature layer of outages with fields
   matching sor.outages (outage_id, feeder_id, status, cause_category,
   started_at, est_restoration, customers_affected). Seed it with a few rows.
2. `python sync_from_sor.py --service-url https://services.arcgis.com/<org>/arcgis/rest/services/<layer>/FeatureServer/0`
3. Edit an outage in the AGOL map viewer, re-run the sync, watch it flow to
   the public map.

**Document:** update the architecture diagram to the real source; note the
field-mapping decisions (that's data modeling — say so).

## Phase 4 — The ArcGIS Enterprise + Utility Network deployment (the long pole)

Get access, in order of preference: Esri Developer program tiers → UT Dallas
site license (ask the department) → 21-day trial on a cloud VM (time-box it;
snapshot the VM).

Base deployment (single machine is fine and normal): ArcGIS Server →
Data Store (relational) → Portal → Web Adaptor → federate → hosting server.
**Full component mapping and step-by-step order: docs/enterprise-deployment.md.**

Then the part you already have muscle memory for: deploy Esri's **Electric
Utility Network Foundation** solution — same asset-package workflow as your
WaterEssentials build (cloned Pro environment, untools,
Asset Package to Geodatabase / Stage Utility Network / Apply Asset Package).
Your untools runbook applies verbatim; the version quadruple rule too.

Swap it into the architecture:
1. Publish the UN feature services; add an outages layer (in a real utility
   this comes from the OMS — say so in the docs).
2. Point sync_from_sor.py at the Enterprise service URL instead of AGOL —
   nothing else changes. Write that sentence in the docs; it proves the
   decoupling worked.
3. Enable WMS/WFS/OGC API capabilities on the services (Phase 5 needs them).

**Document (this is the gold):** deployment topology diagram, every
federation and asset-package step as a runbook, licensing/architecture
decisions. Esri friction documented = enterprise experience.

## Phase 5 — OGC interoperability walkthrough (1 week of evenings)

Prove the bridge in both directions; write docs/interop.md:

- **Esri → open**: consume the ArcGIS Server WMS and OGC API - Features
  endpoints in QGIS and in the MapLibre client.
- **Open → Esri**: publish feeders_public/outages_public from GeoServer as
  WFS (workspace → PostGIS store → layers), add that WFS to ArcGIS Pro.
- Same network, four consumption paths. Table them: endpoint, standard,
  client, what worked, what needed configuration.

**Document:** docs/interop.md with the matrix + screenshots of Pro consuming
GeoServer and QGIS consuming ArcGIS Server.

Also run analytics/outage_analysis.R here — the analyst persona. It reads the
same PostGIS directly (internal analyst) and documents the WFS path (external
analyst, zero credentials). Four client personas — public, editor, agency,
analyst — one platform. Say that sentence in interviews.

## Phase 6 — Finalize the ADRs and the cost model

- docs/adr/ has eight ADRs. ADR-008 (typed geometry contract) was born from
  an observed failure — that's the model: revise the others' Consequences
  with what you actually observed (real sync timing, anything that fought
  you), and log incidents in docs/operations.md as they happen. An ADR with
  observed consequences reads as real.
- Add the cost model doc: Esri-delivered public outage map at storm peak
  (credits/infrastructure/licensing) vs. open-source tier + CDN, and the
  crossover point. Rough public list prices are fine — the reasoning is the
  deliverable.

## Phase 7 — Kubernetes stretch + packaging

- Run k8s/ on Docker Desktop's Kubernetes or kind; scale Martin to 3 replicas
  and write down why that line is the storm response (ADR-006).
- Polish README.md as the landing page: diagram at top, quickstart, links to
  ADRs and interop doc. Pin the repo.
- Resume bullet shape: "Designed and documented a hybrid enterprise GIS for
  an electric utility network (ArcGIS Enterprise Utility Network system of
  record; PostGIS/Martin public outage delivery; OGC interop layer), including
  7 ADRs, a PII/CEII boundary enforced in SQL, and a federated ArcGIS
  Enterprise deployment with the Electric UN Foundation solution."

## Definition of done

- [ ] Stack runs from a clean clone with `docker compose up -d`
- [ ] Outage sync runs on a minutes-cadence against a real Esri service;
      sync_log shows history
- [ ] ArcGIS Enterprise deployed, federated, Electric UN Foundation applied,
      all documented as a runbook
- [ ] docs/interop.md: 4-path consumption matrix with screenshots
- [ ] 7 ADRs revised with observed consequences + cost model doc
- [ ] README is a self-explanatory landing page; repo pinned
