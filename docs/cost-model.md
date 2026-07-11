# Cost Analysis of Public Outage Map Delivery Alternatives

## 1. Purpose and Scope

This document presents the economic analysis underlying ADR-002. The
question evaluated is what it costs to deliver a public-facing outage map
whose traffic profile is storm-driven: negligible for the majority of the
year, with the potential for very high concurrent viewership (100,000 or
more anonymous users) during major weather events. Three delivery
alternatives are compared: Esri-hosted delivery through ArcGIS Online
(Option A), self-hosted ArcGIS Enterprise provisioned for peak demand
(Option B), and the hybrid architecture implemented in this repository
(Option C).

Pricing figures cited below were verified in July 2026 against publicly
available Esri and cloud-provider pages and recent third-party pricing
guides (Section 7); the sole figure not publicly listed — ArcGIS
Enterprise licensing — is identified as requiring vendor quotation. Prices
change, and current figures should be confirmed before this analysis is
cited in any procurement or design decision. The structure of the comparison, rather
than any individual figure, is intended as the durable contribution.

## 2. Workload Characterization

The cost implications of the outage-map workload follow from three
characteristics. First, demand is episodic: traffic is near zero on the
majority of days and rises sharply during severe weather, such that peak
load coincides with peak operational importance. Second, viewers are
anonymous and read-only; no additional value is created by identifying or
licensing individual users. Third, the content served is identical for all
viewers — outage locations are grid-snapped and attribute values are
banded (ADR-005) — which makes the tile output highly cacheable.

These characteristics indicate that any pricing model tied to provisioned
capacity or named users requires paying year-round for capacity needed only
a few days per year. A cost structure that approaches zero when idle and
scales elastically under load is better matched to the workload.

## 3. Delivery Alternatives

### 3.1 Option A — Esri-Hosted Delivery (ArcGIS Online)

Publicly shared ArcGIS Online content does not require viewer accounts, so
per-viewer licensing overstates the cost of this option; the material costs
lie elsewhere. Staff publishing and administration require Creator-level
user types (approximately $700 per user per year at 2026 U.S. list;
Viewer seats, for comparison, list at $100 per year). Premium capabilities
are metered in credits (approximately $100–120 per 1,000 across recent
sources), with feature storage billed monthly. Of greatest relevance to
this workload, high-volume public feature serving is positioned by Esri
under the Premium Feature Data Store, a fixed-price dedicated-database
offering from approximately $2,700 per month at its entry level, with
higher tiers quoted. Because
standard hosted layers are served from shared infrastructure, sustained
six-figure concurrency would in practice require this premium tier,
purchased year-round to provide readiness for a small number of storm days.

### 3.2 Option B — Self-Hosted ArcGIS Enterprise Provisioned for Peak

ArcGIS Enterprise licensing is quoted through sales rather than publicly
list-priced (Esri's Enterprise pricing page directs buyers to a
representative); industry guides characterize typical deployments as an
annual five-figure commitment, and this analysis treats that figure as
requiring vendor quotation. The dominant cost, however, is infrastructural: Enterprise
components do not autoscale on the timescale of a developing storm, so
public-facing capacity must be provisioned in advance and carried
continuously. Operational staffing requirements are comparable to those of
Option C and are treated as equivalent across options. It should be
emphasized that this option remains the appropriate architecture for the
internal editing and analysis workload (ADR-001); the analysis here
concerns only the anonymous public tier.

### 3.3 Option C — Hybrid Delivery (This Architecture)

Under the hybrid design, the Esri platform remains the system of record,
priced per seat for a bounded internal population, while public delivery is
served by open-source components. The delivery tier (PostGIS, Martin,
GeoServer) carries no license cost and operates on one to two modest
virtual machines (approximately $50–150 per month at commodity
cloud-instance rates) because a content delivery network absorbs peak
demand. CDN pricing has moved further in this option's favor: as of 2026,
Amazon CloudFront offers flat-rate plans with no overage charges — $15 per
month covers 50 TB of transfer and 10 million requests (Pro tier), and
$200 per month covers 125 million requests (Business tier) — meaning
storm-day traffic incurs no marginal cost at all. The honest cost of this option is
engineering time: assembly, hardening, and operational documentation — the
expense that Options A and B outsource to the vendor.

## 4. Illustrative Comparison

Consider a storm day producing 100,000 viewers issuing approximately 30
tile requests each at roughly 30 KB per tile, or on the order of 90 GB of
tile traffic, of which approximately 95 percent is served from CDN cache
given the uniformity of the tile content.

Under Option C, that storm day — roughly 3 million requests and 90 GB of
transfer — fits entirely within CloudFront's $15-per-month flat-rate plan;
its marginal cost is zero. The delivery tier's all-in annual cost is
therefore origin infrastructure (on the order of $1,200–1,800) plus a CDN
plan ($180–2,400 depending on tier), or roughly $1,500–4,000 per year with
storm readiness included. Option A, carrying a Premium Feature Data Store
year-round for equivalent readiness, is on the order of $32,000 or more
annually at the verified entry price. Option B, provisioned for the same
peak, typically exceeds Option C by an order of magnitude in
infrastructure alone before licensing is considered. The separation
between options is large enough that reasonable variation in the inputs
does not change the ordering.

## 5. Counterargument

An important counterargument to the hybrid approach is that vendor-hosted
delivery provides contractual support, managed availability, and a single
point of accountability — properties whose value is greatest precisely
during high-visibility events such as storms. From this perspective, the
premium paid for Option A purchases risk transfer rather than capacity, and
organizations without engineering staff may rationally prefer it. This
analysis accepts that boundary: where public traffic is steady and modest,
or where no capability exists to operate two containers and a CDN, Esri-
hosted delivery is defensible. The hybrid option dominates specifically
when traffic is episodic and the organization already employs the
operational skills — conditions that describe most mid-size and large
utilities.

## 6. Limitations

Several limitations should be considered when interpreting this analysis.
The storm-day traffic model is illustrative rather than measured; no load
test has been performed against the reference deployment. Pricing figures
are drawn from public list pages at a single point in time and exclude
negotiated enterprise agreements, which can differ substantially. Internal
editing and analysis costs are excluded as common to all options (ADR-001),
and multi-year total-cost-of-ownership discounting is omitted as
unnecessary given the order-of-magnitude separation observed. Finally, the
value of vendor support on the public tier, while acknowledged in Section
5, is not quantified.

## 7. Sources

Figures verified July 2026 against the following (U.S. list prices):

- Esri, ArcGIS Online pricing and user types (Creator ≈ $700/yr; Viewer
  $100/yr): esri.com/en-us/arcgis/products/arcgis-online/buy and
  esri.com/en-us/arcgis/products/user-types/buy
- Esri, ArcGIS Online credits ($100–120 per 1,000 across recent sources):
  esri.com/en-us/arcgis/products/credits/buy
- Esri, Premium Feature Data Store (from ≈ $2,700/month; fixed-price
  dedicated tiers): esri.com/en-us/arcgis/products/premium-feature-data-store/buy
- Esri, ArcGIS Enterprise pricing (quotation via sales; no public list):
  esri.com/en-us/arcgis/products/arcgis-enterprise/pricing
- Amazon Web Services, CloudFront pricing (flat-rate plans, no overage:
  Free $0 / Pro $15 / Business $200 / Premium $1,000 per month):
  aws.amazon.com/cloudfront/pricing
