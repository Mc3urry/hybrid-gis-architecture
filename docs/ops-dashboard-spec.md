# Internal Operations Dashboard — Build Specification

The internal outage-operations dashboard is the application-tier counterpart
to the public map. It reads the authoritative (unredacted) system-of-record
layer and is shared organization-internal only, so operations staff see the
fields the public tier is designed to withhold — crew notes and exact
customer counts. This document specifies each element and the Arcade used to
derive operational fields.

## Data source and access

| Property | Value |
|---|---|
| Source item | `outages_sor` (hosted feature layer, layer 0) |
| NOT | `outages_sor_public_view` — the redacted public view |
| Dashboard sharing | Organization only (never Everyone) |
| Default filter | `status = 'active'` (applied per element unless noted) |

The choice of source is the architectural point: the same trust boundary
(ADR-005) that strips `crew_notes` and bands `customers_affected` on the
public side is simply not applied here, because this audience is authorized.
The boundary is a property of the *view*, not of the data.

## Arcade data expression — derived operational fields

Several elements consume fields the source layer does not store directly:
severity band and minutes-to-restoration. A single Dashboards **data
expression** computes them once and is reused as the data source for the
indicators, the chart, and the list.

Add via any element's data source dropdown -> New data expression.

```arcade
// Active outages, enriched with severity and restoration ETA.
var p = Portal('https://www.arcgis.com');
var src = FeatureSetByPortalItem(
    p,
    'REPLACE_WITH_outages_sor_ITEM_ID',
    0,
    ['outage_id', 'cause_category', 'customers_affected',
     'crew_notes', 'status', 'started_at', 'est_restoration'],
    false
);

var active = Filter(src, "status = 'active'");

var feats = [];
var i = 0;
for (var f in active) {
    var eta = Round(DateDiff(f.est_restoration, Now(), 'minutes'));
    var sev = When(
        f.customers_affected >= 250, 'High',
        f.customers_affected >= 50,  'Medium',
        'Low'
    );
    feats[i++] = {
        attributes: {
            outage_id:          f.outage_id,
            cause_category:     f.cause_category,
            customers_affected: f.customers_affected,
            crew_notes:         f.crew_notes,
            severity:           sev,
            eta_minutes:        eta,
            overdue:            IIf(eta < 0, 1, 0)
        }
    };
}

return FeatureSet(Text({
    fields: [
        { name: 'outage_id',          type: 'esriFieldTypeString'  },
        { name: 'cause_category',     type: 'esriFieldTypeString'  },
        { name: 'customers_affected', type: 'esriFieldTypeInteger' },
        { name: 'crew_notes',         type: 'esriFieldTypeString'  },
        { name: 'severity',           type: 'esriFieldTypeString'  },
        { name: 'eta_minutes',        type: 'esriFieldTypeInteger' },
        { name: 'overdue',            type: 'esriFieldTypeInteger' }
    ],
    geometryType: '',
    features: feats
}));
```

Find the item id in the layer's item-page URL (`.../home/item.html?id=<ID>`).

## Element 1 — Indicator: active outages

| Setting | Value |
|---|---|
| Data | data expression (above), or `outages_sor` |
| Value type | Statistic -> Count |
| Filter | `status = 'active'` (implicit if using the expression) |
| Top text | `Active outages` |
| Middle text | `{value}` |
| No-data text | `No active outages` |

## Element 2 — Indicator: customers affected

| Setting | Value |
|---|---|
| Value type | Statistic -> Sum of `customers_affected` |
| Top text | `Customers affected` |
| Middle text | `{value}` with thousands separator enabled |

This is the field the public tier only exposes as a band; the exact sum here
is the clearest single demonstration that this dashboard sits inside the
boundary.

## Element 3 — Indicator: largest outage

| Setting | Value |
|---|---|
| Value type | Statistic -> Max of `customers_affected` |
| Top text | `Largest outage` |

## Element 4 — Serial or pie chart: outages by cause

| Setting | Value |
|---|---|
| Category field | `cause_category` |
| Statistic | Count |
| Filter | `status = 'active'` |
| Sort | Count descending |
| Colors | one per category; keep consistent with the map symbology |

## Element 5 — Map

| Setting | Value |
|---|---|
| Web map | a map containing `outages_sor` and the network layers |
| Outage symbology | by `cause_category`, or graduated by `customers_affected` |
| Feeders | drawn as context |
| Pop-ups | full attributes, including crew_notes (internal map) |

## Element 6 — List: active outage crew view (the boundary element)

This element displays the fields absent from the public view. Data source:
the data expression, sorted by `customers_affected` descending, filtered to
`status = 'active'`.

Line-item title:

```
{outage_id} — {cause_category}
```

Line-item content (rich-text editor with field placeholders):

```
{crew_notes}
Customers affected: {customers_affected}   ETA: {eta_minutes} min
```

### Arcade — list advanced formatting (severity color)

Enable the list element's Advanced formatting toggle to color each row by
severity. The expression returns a dictionary Dashboards applies to the line.

```arcade
// Row accent by severity; overdue rows flagged red.
var sev = $datapoint.severity;
var over = $datapoint.overdue;

var color = When(
    over == 1,          '#A32D2D',   // overdue — red
    sev == 'High',      '#D85A30',   // coral
    sev == 'Medium',    '#BA7517',   // amber
    '#5F5E5A'                         // low — gray
);

return {
    attributes: {
        sev_color: color,
        sev_label: IIf(over == 1, sev + ' (overdue)', sev)
    }
};
```

Reference the returned values in the line-item template as
`{expression/sev_label}` and use `{expression/sev_color}` as a text or
selection color where the editor allows.

## Deliverable

Two screenshots, captured as the application-tier boundary evidence pair:

1. This dashboard, with the crew-view list showing crew_notes and exact
   customer counts.
2. The public map (localhost:8088) with the same outage's pop-up open —
   cause category and banded count only, no crew notes.

Same system of record, two audiences, boundary enforced at the serving/view
tier — the ops persona demonstrated rather than asserted (ADR-005).
