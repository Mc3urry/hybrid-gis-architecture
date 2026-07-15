# ADR-001: ArcGIS Enterprise (Utility Network) as the system of record

Status: Accepted

## Context
An electric distribution network needs connectivity-aware editing, tracing,
subnetwork management, and OMS/ADMS integration. The Utility Network on
ArcGIS Enterprise is the industry-standard platform for this, and utilities
value vendor support contracts and versioned multi-editor workflows.

## Decision
The Utility Network in the Enterprise geodatabase holds authoritative network
data. All editing and tracing happens there. Nothing edits PostGIS directly.

## Consequences
+ Connectivity model, tracing, versioned editing, vendor support, industry fit.
+ Engineers and editors keep their entire existing toolchain.
- License cost for every named internal user (accepted: bounded population).
- The sync tier (ADR-004) becomes mandatory infrastructure and a failure point.

## Observed consequences (post-implementation)
- AGOL currently stands in as the system of record; because the decision was
  made at the service-contract level, swapping to Enterprise is a one-URL
  change in the sync — verified when the same script consumed a
  hosted view with zero code changes beyond a field-name fallback.
- The contract is field names as much as endpoints: a singular/plural naming
  drift produced silent NULLs (OPS-002). "System of record" includes its
  schema discipline, not just its location.
- The Utility Network-specific claims of this ADR (versioned editing,
  tracing) remain projected until the ArcGIS Enterprise deployment; noted
  here for honesty rather than assumed.
