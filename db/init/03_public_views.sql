-- 03_public_views.sql
-- The trust boundary, expressed in SQL. Only these materialized views are
-- served publicly. Never crosses the boundary: customer PII (service_points),
-- exact device locations (CEII-adjacent), crew_notes, precise customer counts.
-- Outage locations are snapped to a ~200 m grid so no individual premise is
-- identifiable.
--
-- NOTE the ::geometry(...,4326) casts: ST_SnapToGrid and
-- ST_SimplifyPreserveTopology return UNTYPED geometry, which strips the
-- SRID/type metadata from the view column — and Martin's auto-discovery
-- skips columns it cannot type. The casts restore the typmod. (Found the
-- hard way; this is exactly the kind of gotcha that belongs in an ADR.)

CREATE MATERIALIZED VIEW public.feeders_public AS
SELECT
    feeder_id,
    voltage_class,
    CASE
        WHEN customers_served < 500  THEN 'under_500'
        WHEN customers_served < 1500 THEN '500_1500'
        ELSE 'over_1500'
    END AS customers_band,
    last_edited,
    ST_SimplifyPreserveTopology(geom, 0.0002)::geometry(LineString, 4326) AS geom
FROM sor.feeders;

CREATE UNIQUE INDEX feeders_public_pk  ON public.feeders_public (feeder_id);
CREATE INDEX feeders_public_gix ON public.feeders_public USING gist (geom);

CREATE MATERIALIZED VIEW public.outages_public AS
SELECT
    outage_id,
    status,
    cause_category,
    started_at,
    est_restoration,
    CASE
        WHEN customers_affected < 50  THEN 'under_50'
        WHEN customers_affected < 250 THEN '50_250'
        ELSE 'over_250'
    END AS customers_band,
    ST_SnapToGrid(geom, 0.002)::geometry(Point, 4326) AS geom   -- fuzz: ~200 m
FROM sor.outages
WHERE status = 'active';                           -- restored outages drop off

CREATE UNIQUE INDEX outages_public_pk  ON public.outages_public (outage_id);
CREATE INDEX outages_public_gix ON public.outages_public USING gist (geom);

-- Read-only role for the tile servers: the boundary enforced at the DB layer.
CREATE ROLE tile_reader NOLOGIN;
GRANT USAGE ON SCHEMA public TO tile_reader;
GRANT SELECT ON public.feeders_public, public.outages_public TO tile_reader;

-- Service login for GeoServer: inherits ONLY tile_reader. When GeoServer's
-- store connects as this user it can see the two public views and nothing
-- else -- the layer-publish screen itself demonstrates the boundary.
CREATE ROLE svc_geoserver LOGIN PASSWORD 'svc_dev_password' IN ROLE tile_reader;
