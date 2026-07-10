-- 01_schema.sql
-- The "sor" schema mirrors public-delivery-relevant slices of the system of
-- record: an electric distribution utility network in ArcGIS Enterprise
-- (Utility Network). Nothing here is edited directly; it is populated by
-- sync/sync_from_sor.py.

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS sor;

CREATE TABLE sor.substations (
    substation_id text PRIMARY KEY,
    name          text,
    voltage_class text,                        -- e.g. '138kV/25kV'
    geom          geometry(Point, 4326) NOT NULL
);

CREATE TABLE sor.feeders (
    feeder_id        text PRIMARY KEY,
    substation_id    text REFERENCES sor.substations,
    voltage_class    text,
    phase            text,                     -- 'ABC', 'AB', 'A' ...
    customers_served integer,                  -- sensitive in precision
    last_edited      timestamptz NOT NULL DEFAULT now(),
    geom             geometry(LineString, 4326) NOT NULL
);

CREATE TABLE sor.devices (
    device_id   text PRIMARY KEY,
    feeder_id   text REFERENCES sor.feeders,
    device_type text,                          -- 'transformer','switch','fuse','recloser'
    -- exact device locations are CEII-adjacent: NEVER served publicly
    geom        geometry(Point, 4326) NOT NULL
);

CREATE TABLE sor.service_points (
    service_point_id text PRIMARY KEY,
    device_id        text REFERENCES sor.devices,
    account_number   text,                     -- customer PII: NEVER served publicly
    customer_name    text,                     -- customer PII: NEVER served publicly
    geom             geometry(Point, 4326) NOT NULL
);

CREATE TABLE sor.outages (
    outage_id          text PRIMARY KEY,
    feeder_id          text REFERENCES sor.feeders,
    status             text NOT NULL DEFAULT 'active',   -- 'active','restored'
    cause_category     text,                   -- 'equipment','weather','vegetation','vehicle','planned'
    crew_notes         text,                   -- internal only: NEVER served publicly
    started_at         timestamptz NOT NULL DEFAULT now(),
    est_restoration    timestamptz,
    restored_at        timestamptz,
    customers_affected integer,
    geom               geometry(Point, 4326) NOT NULL
);

CREATE INDEX feeders_geom_gix  ON sor.feeders  USING gist (geom);
CREATE INDEX devices_geom_gix  ON sor.devices  USING gist (geom);
CREATE INDEX svcpts_geom_gix   ON sor.service_points USING gist (geom);
CREATE INDEX outages_geom_gix  ON sor.outages  USING gist (geom);
CREATE INDEX outages_status_ix ON sor.outages (status);

-- Sync bookkeeping: every run recorded (audit trail).
CREATE TABLE sor.sync_log (
    run_id        bigserial PRIMARY KEY,
    started_at    timestamptz NOT NULL DEFAULT now(),
    finished_at   timestamptz,
    source        text NOT NULL,               -- 'simulate' | feature service URL
    rows_upserted integer,
    status        text NOT NULL DEFAULT 'running'
);
