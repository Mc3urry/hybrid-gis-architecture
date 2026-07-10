-- 02_sample_data.sql
-- Synthetic electric distribution network across the DFW metroplex.
-- Substations cluster around 16 real urban anchors (Dallas, Fort Worth,
-- Arlington, Plano, ...) rather than uniform random, so the network reads
-- like a service territory. Scale: 32 substations, 320 feeders, 1,600
-- devices, 4,800 service points, 120 outages.
-- In the real build these rows come from the Utility Network via the sync.

WITH anchors(name, lon, lat) AS (
    VALUES
        ('Dallas',        -96.797, 32.777),
        ('Fort Worth',    -97.330, 32.755),
        ('Arlington',     -97.108, 32.736),
        ('Plano',         -96.699, 33.020),
        ('Irving',        -96.949, 32.814),
        ('Garland',       -96.639, 32.913),
        ('Frisco',        -96.824, 33.150),
        ('McKinney',      -96.640, 33.198),
        ('Denton',        -97.133, 33.215),
        ('Richardson',    -96.730, 32.948),
        ('Grand Prairie', -97.000, 32.746),
        ('Mesquite',      -96.599, 32.767),
        ('Carrollton',    -96.890, 32.976),
        ('Lewisville',    -96.994, 33.046),
        ('Grapevine',     -97.078, 32.934),
        ('DeSoto',        -96.857, 32.590)
)
INSERT INTO sor.substations (substation_id, name, voltage_class, geom)
SELECT
    'SUB' || lpad((row_number() OVER ())::text, 3, '0'),
    a.name || ' Substation ' || s,
    (ARRAY['138kV/25kV','69kV/12.5kV'])[1 + ((row_number() OVER ()) % 2)],
    ST_SetSRID(ST_MakePoint(a.lon + (random()-0.5)*0.06,
                            a.lat + (random()-0.5)*0.06), 4326)
FROM anchors a, generate_series(1, 2) AS s;

-- 10 radial feeders per substation
INSERT INTO sor.feeders (feeder_id, substation_id, voltage_class, phase, customers_served, geom)
SELECT
    s.substation_id || '-F' || lpad(f::text, 2, '0'),
    s.substation_id,
    s.voltage_class,
    (ARRAY['ABC','ABC','ABC','AB','A'])[1 + floor(random()*5)::int],
    (200 + floor(random()*2300))::int,
    ST_MakeLine(s.geom,
        ST_Translate(s.geom, (random()-0.5)*0.05, (random()-0.5)*0.05))
FROM sor.substations s, generate_series(1, 10) AS f;

-- 5 devices along each feeder
INSERT INTO sor.devices (device_id, feeder_id, device_type, geom)
SELECT
    f.feeder_id || '-D' || k,
    f.feeder_id,
    (ARRAY['transformer','transformer','transformer','switch','fuse'])[1 + floor(random()*5)::int],
    ST_LineInterpolatePoint(f.geom, k / 6.0)
FROM sor.feeders f, generate_series(1, 5) AS k;

-- 3 service points per device (fake customer PII)
INSERT INTO sor.service_points (service_point_id, device_id, account_number, customer_name, geom)
SELECT
    d.device_id || '-S' || j,
    d.device_id,
    'ACCT-' || lpad((row_number() OVER ())::text, 7, '0'),
    'REDACTED CUSTOMER',
    ST_Translate(d.geom, (random()-0.5)*0.002, (random()-0.5)*0.002)
FROM sor.devices d, generate_series(1, 3) AS j;

-- 120 outages at random devices across the metroplex
INSERT INTO sor.outages (outage_id, feeder_id, status, cause_category, crew_notes,
                         started_at, est_restoration, customers_affected, geom)
SELECT
    'OUT' || lpad((row_number() OVER ())::text, 5, '0'),
    d.feeder_id,
    CASE WHEN random() < 0.75 THEN 'active' ELSE 'restored' END,
    (ARRAY['equipment','weather','vegetation','vehicle','planned'])[1 + floor(random()*5)::int],
    'internal crew notes - not public',
    now() - (random() * interval '12 hours'),
    now() + (random() * interval '8 hours'),
    (10 + floor(random()*800))::int,
    d.geom
FROM (SELECT * FROM sor.devices ORDER BY random() LIMIT 120) d;
