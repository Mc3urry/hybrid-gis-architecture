# ArcGIS Enterprise Deployment — translating the open-source half

This document maps every component you're running in Docker to its Esri
equivalent, then gives the deployment order for the Enterprise side. When
you're done, `sync_from_sor.py --service-url <enterprise URL>` is the ONLY
thing that changes in the open-source half. That sentence is the proof the
architecture works (ADR-004).

## 1. Component translation table

| You built (open-source) | Enterprise equivalent | Notes |
|---|---|---|
| PostGIS `sor.*` schema | Enterprise geodatabase in PostgreSQL | Same engine you already know — Esri's gdb is a schema + SDE layer *on top of* Postgres. Created with Pro's "Create Enterprise Geodatabase" tool. |
| Hand-written DDL (01_schema.sql) | Electric UN Foundation asset package via untools | Your WaterEssentials runbook applies verbatim: cloned Pro env → untools → Asset Package to Geodatabase / Stage Utility Network / Apply Asset Package. |
| Martin + GeoServer | ArcGIS Server (federated) | One server publishes map, feature, and OGC (WMS/WFS/OGC API - Features) services. |
| Keycloak | Portal for ArcGIS | Named users, groups, sharing model, identity federation (SAML/OIDC if you want to point it AT Keycloak later — architect flex). |
| PostGIS materialized views | Hosted feature layers in ArcGIS Data Store | The relational Data Store is Esri-managed PostgreSQL for *hosted* content. Your authoritative UN lives in the enterprise gdb; quick operational layers (e.g. outages) can be hosted. |
| nginx + MapLibre | Web Adaptor + Experience Builder / JS SDK app | Web Adaptor is the reverse proxy (their nginx); Experience Builder is the low-code client tier. |
| docker-compose.yml | ArcGIS Enterprise Builder / installers + federation | No container equivalent in a base deployment — this is why the deployment doc you'll write has real value. |
| sync_from_sor.py | **Unchanged.** | The REST /query contract is identical between AGOL and Enterprise. |

## 2. Get licensed (verify current terms before committing)

In order of preference: Esri Developer program tiers (some include Enterprise)
→ UT Dallas site license (ask the department — many universities carry
Enterprise entitlements) → official trial on a time-boxed cloud VM
(snapshot it; document fast).

## 3. Provision the machine

Single-machine base deployment is normal and interview-defensible (ADR it):
- Windows Server 2022 (or RHEL), 8 vCPU, 32 GB RAM, 250 GB disk.
- A resolvable FQDN (hosts-file hacks cause cert pain later; a cheap domain +
  DNS record is worth it).
- Open ports: 6443 (Server), 7443 (Portal), 2443 (Data Store), 443 (Web
  Adaptor/IIS). Internal-only except 443.

## 4. Install order (the federation dance)

ArcGIS Enterprise Builder automates all of this on one machine — but do it
manually once; the manual path is what you're learning:

1. **ArcGIS Server** — install, authorize, create the site.
   Verify: https://FQDN:6443/arcgis/manager
2. **ArcGIS Data Store** — install, configure as *relational* (+ *tile cache*)
   against the Server. Verify: https://FQDN:2443/arcgis/datastore
3. **Portal for ArcGIS** — install, authorize, create the initial admin.
   Verify: https://FQDN:7443/arcgis/home
4. **Web Adaptor** ×2 (IIS) — one for Portal (`/portal`), one for Server
   (`/server`). TLS cert on IIS first (Let's Encrypt is fine).
5. **Federate** — Portal admin → Organization → Servers → Add Server, then
   designate it the **hosting server**. This is the step where everything
   that's going to go wrong goes wrong (certs, FQDN mismatches, admin URLs).
   Log every error in operations.md — OPS-002 onward starts here.

## 5. Data tier: two stores, two jobs

1. **Enterprise geodatabase** (authoritative UN): stand up PostgreSQL
   (a second instance or cloud DB — do NOT reuse the public_gis PostGIS),
   run Pro's *Create Enterprise Geodatabase*, then register it as a data
   store on the Server.
2. **Deploy Electric UN Foundation** into it with untools — your existing
   runbook: cloned Pro environment, `conda install -c esri untools`,
   Asset Package to Geodatabase (or Stage Utility Network + Apply Asset
   Package for the enterprise-gdb path). Version quadruple rule applies.
3. **Publish** the UN as branch-versioned feature services from Pro
   (UN editing is service-based by design — that's an ADR-001 talking point).
4. **Outages layer**: create a hosted feature layer (Data Store) with the
   sor.outages fields — in a real utility this is fed by the OMS; say so.

## 6. Services and the OGC bridge

On the published services enable: WMS, WFS, and OGC API - Features
capabilities (service properties in Server Manager/Pro). These endpoints are
what Phase 5's interop matrix consumes from the Esri side.

## 7. Swap it into the hybrid

```bash
python sync_from_sor.py --service-url https://FQDN/server/rest/services/Outages/FeatureServer/0
```

Nothing else changes: same upserts, same matview refresh, same tiles, same
public map. Write that in the docs — it is the architecture's thesis proven.

## 8. Deliverables from this phase

- Deployment topology diagram (machine, four components, ports, cert chain).
- Federation runbook with every gotcha (operations.md entries).
- Updated architecture.md: the Esri box now describes YOUR deployment.
- ADR revisions: ADR-001 gains observed consequences; consider ADR-009
  (single-machine vs multi-machine topology tradeoffs).
