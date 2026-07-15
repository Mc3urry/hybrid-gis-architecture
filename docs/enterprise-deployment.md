# ArcGIS Enterprise Deployment — translating the open-source half

This document maps each component of the containerized open-source half to
its Esri equivalent, then gives the deployment order for the Enterprise
side. Once the Enterprise deployment is complete,
`sync_from_sor.py --service-url <enterprise URL>` is the only change
required in the open-source half; that property is the demonstration that
the architecture's service-contract boundary holds (ADR-004).

## 1. Component translation table

| Open-source component | Enterprise equivalent | Notes |
|---|---|---|
| PostGIS `sor.*` schema | Enterprise geodatabase in PostgreSQL | The same database engine — Esri's geodatabase is a schema and SDE layer *on top of* PostgreSQL. Created with Pro's "Create Enterprise Geodatabase" tool. |
| Hand-written DDL (01_schema.sql) | Electric UN Foundation asset package via untools | Deployed with Esri's utility network package tools (`untools`, installed into a cloned ArcGIS Pro conda environment): Asset Package to Geodatabase, or Stage Utility Network followed by Apply Asset Package. |
| Martin + GeoServer | ArcGIS Server (federated) | One server publishes map, feature, and OGC (WMS/WFS/OGC API - Features) services. |
| Keycloak | Portal for ArcGIS | Named users, groups, sharing model; identity federation (SAML/OIDC) permits Portal to delegate authentication to an external provider such as Keycloak. |
| PostGIS materialized views | Hosted feature layers in ArcGIS Data Store | The relational Data Store is Esri-managed PostgreSQL for *hosted* content. Your authoritative UN lives in the enterprise gdb; quick operational layers (e.g. outages) can be hosted. |
| nginx + MapLibre | Web Adaptor + Experience Builder / JS SDK app | Web Adaptor is the reverse proxy (their nginx); Experience Builder is the low-code client tier. |
| docker-compose.yml | ArcGIS Enterprise Builder / installers + federation | No container equivalent exists in a base deployment; installation and federation are documented in Section 4. |
| sync_from_sor.py | **Unchanged.** | The REST /query contract is identical between AGOL and Enterprise. |

## 2. Licensing (resolved)

Licensing for this reference deployment was obtained through an academic
education site license:
an academic-use ArcGIS Server authorization (ECP number, entered directly in
the Software Authorization Wizard during installation) at version 12.1,
valid through the license year. Portal for ArcGIS requires its own license
file (a .json with named-user counts) generated from the licensing portal;
ArcGIS Data Store and the Web Adaptor are licensed through Server and
require no separate authorization. Installer access is through My Esri and
requires the account to be connected to the organization by its
administrator. Authorization numbers are credentials and are recorded only
in private notes, never in this repository.

## 3. Provision the machine

A single-machine base deployment is a standard configuration for
development and reference use.
Reference specification: Windows Server 2022 (or RHEL), 8 vCPU, 32 GB RAM,
250 GB disk, a resolvable FQDN, and ports 6443 (Server), 7443 (Portal), and
2443 (Data Store) open internally with 443 exposed via the Web Adaptor.

This deployment deliberately deviates from the reference, and the deviations
are themselves documented decisions:
- Windows 11 workstation, 16 GB RAM — supported by Esri for basic testing
  and development use at 12.1. The memory constraint imposes an operating
  discipline: Docker Desktop is fully quit (and WSL capped at 3 GB via
  .wslconfig) during Enterprise sessions; components are installed and
  verified serially; ArcGIS Pro and the full Enterprise stack are not run
  simultaneously except during publishing.
- The machine hostname is used in place of an FQDN, with self-signed
  certificates accepted for development. The hostname must contain no
  underscore and must not change after installation.

## 4. Installation and Federation Order

ArcGIS Enterprise Builder automates single-machine installation; this
deployment uses the manual path deliberately, because the component-level
installation and federation steps are part of what the reference
architecture documents:

1. **ArcGIS Server** — install, authorize, create the site.
   Verify: https://FQDN:6443/arcgis/manager
2. **ArcGIS Data Store** — install, configure as *relational* (+ *tile cache*)
   against the Server. Verify: https://FQDN:2443/arcgis/datastore
3. **Portal for ArcGIS** — install, authorize, create the initial admin.
   Verify: https://FQDN:7443/arcgis/home
4. **Web Adaptor** — deliberately deferred in this deployment. The Web
   Adaptor exists to place all components behind IIS on port 443; for a
   development deployment the components' native ports (6443/7443) are used
   directly, which removes IIS and most certificate friction from the
   critical path. Adding the Web Adaptor later is documented as its own
   exercise.
5. **Federate** — Portal admin → Organization → Servers → Add Server, then
   designate it the **hosting server**. Federation is the step most prone
   to failure (certificate trust, hostname mismatches, admin URLs); errors
   encountered here are logged in operations.md.

## 5. Data tier: two stores, two jobs

1. **Enterprise geodatabase** (authoritative UN): stand up PostgreSQL
   (a second instance or cloud DB — do NOT reuse the public_gis PostGIS),
   run Pro's *Create Enterprise Geodatabase*, then register it as a data
   store on the Server.
2. **Deploy Electric UN Foundation** into it with untools (cloned ArcGIS
   Pro environment, `conda install -c esri untools`, then Stage Utility
   Network and Apply Asset Package for the enterprise-geodatabase path).
   Record the version set — solution package, untools, Pro, and Enterprise —
   as compatibility between them is version-sensitive.
3. **Publish** the UN as branch-versioned feature services from Pro
   (Utility Network editing is service-based by design; see ADR-001).
4. **Outages layer**: create a hosted feature layer (Data Store) with the
   sor.outages fields. In a production utility this layer would be fed by the
   outage management system; the reference deployment documents this
   substitution explicitly.

## 6. Services and the OGC bridge

On the published services enable: WMS, WFS, and OGC API - Features
capabilities (service properties in Server Manager/Pro). These endpoints are
what the interoperability matrix (docs/interop.md) consumes from the Esri side.

## 7. Swap it into the hybrid

```bash
python sync_from_sor.py --service-url https://<hostname>:6443/arcgis/rest/services/Outages/FeatureServer/0
```

Nothing else changes: the same upserts, the same materialized-view
refresh, the same tiles, the same public map. This one-line swap is the
architecture's design thesis demonstrated (ADR-004).

## 8. Deliverables from this phase

- Deployment topology diagram (machine, four components, ports, cert chain).
- Federation runbook with every gotcha (operations.md entries).
- Updated architecture.md: the Esri box now describes YOUR deployment.
- ADR revisions: ADR-001 gains observed consequences; consider ADR-009
  (single-machine vs multi-machine topology tradeoffs).
