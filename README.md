# Hybrid Enterprise GIS Reference Architecture â€” Electric Utility Network

![CI](https://github.com/Mc3urry/hybrid-gis-architecture/actions/workflows/ci.yml/badge.svg)

**ArcGIS Enterprise (Utility Network) as the system of record. Open-source for
public outage delivery. OGC standards as the only contract between them.**

This repo is the open-source half of a hybrid enterprise GIS for an electric
distribution utility, plus the architecture documentation for the whole system.
The documentation is the product; the running stack is the evidence.

## Why this architecture

Network editors, engineers, and OMS integrations need the Utility Network,
versioned editing, and the Esri toolchain â€” that's what the license buys.
The **public outage map** is the opposite workload: anonymous, read-only, and
storm-driven â€” a major weather event can send six figures of concurrent viewers
overnight. Sizing Esri per-viewer delivery for that spike is exactly the wrong
economics. So: the authoritative network lives in the Enterprise geodatabase,
a sync materializes public-safe layers into PostGIS, and open-source
infrastructure serves them as vector tiles at zero marginal license cost.

What never crosses the boundary: customer PII (service points), exact device
locations (CEII-adjacent), crew notes, precise customer counts. Outage points
are snapped to a ~200 m grid. The boundary is enforced in SQL â€” see ADR-005.

## Repo layout

```
hybrid-gis-architecture/
â”œâ”€â”€ docker-compose.yml      # the open-source half, one command to run
â”œâ”€â”€ GUIDE.md                # step-by-step build instructions, start here
â”œâ”€â”€ .github/workflows/      # CI: real PostGIS, init SQL, boundary + ADR-008 regression tests
â”œâ”€â”€ analytics/              # R: the analyst persona consuming the same platform
â”œâ”€â”€ db/init/                # schema, synthetic network, public-safe views (auto-run on first boot)
â”œâ”€â”€ sync/                   # utility network -> PostGIS sync script
â”œâ”€â”€ web/                    # public MapLibre outage map
â”œâ”€â”€ docs/
â”‚   â”œâ”€â”€ architecture.md     # system diagram, data flow, trust boundary
â”‚   â”œâ”€â”€ adr/                # ADR-001 .. ADR-008 (the tradeoff decisions)
â”‚   â”œâ”€â”€ enterprise-deployment.md  # open-source -> ArcGIS Enterprise translation + install order
â”‚   â””â”€â”€ operations.md       # incident runbook (symptom -> diagnosis -> fix -> rule)
â””â”€â”€ k8s/                    # illustrative Kubernetes manifests
```

## Quickstart

```bash
docker compose up -d
# PostGIS   -> localhost:5432  (gis / gis_dev_password, db: public_gis)
# Martin    -> http://localhost:3000       (tile catalog: /catalog)
# GeoServer -> http://localhost:8085/geoserver  (admin / geoserver)
# Keycloak  -> http://localhost:8081       (admin / admin_dev_password)
# Outage map-> http://localhost:8088
```

A synthetic DFW-metroplex distribution network loads on first boot:
32 substations clustered around 16 real urban anchors (Dallas, Fort Worth,
Arlington, Plano, ...), 320 feeders, 1,600 devices, 4,800 service points,
and 120 outages. Open http://localhost:8088:
feeders colored by voltage class, active outages sized by customers affected.

## The one-sentence pitch

> "I architect on ArcGIS Enterprise, and I know when and how to bridge to
> open-source to solve problems Esri alone can't â€” or shouldn't â€” solve."

Dev credentials are intentionally trivial; this is a reference design, not a
hardened deployment. See ADR-005 for the security model.
