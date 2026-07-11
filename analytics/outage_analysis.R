#!/usr/bin/env Rscript
# Analyst-persona consumer of the platform.
# The architecture serves four personas: public viewers (MapLibre), editors
# (ArcGIS Pro), agencies (OGC services), and analysts -- this script.
# It connects to the SAME PostGIS the tile servers use, as a read-only client.
#
# Setup: install.packages(c("DBI", "RPostgres", "sf", "dplyr", "ggplot2"))
# Run:   Rscript outage_analysis.R

library(DBI)
library(RPostgres)
library(sf)
library(dplyr)
library(ggplot2)

con <- dbConnect(
  Postgres(),
  host = "localhost", port = 5432, dbname = "public_gis",
  user = "gis", password = "gis_dev_password"
)

# --- Pull spatial layers straight from PostGIS (sf reads WKB natively) ------
outages <- st_read(con, query = "
  SELECT o.outage_id, o.status, o.cause_category, o.customers_affected,
         o.started_at, f.voltage_class, o.geom
  FROM sor.outages o
  JOIN sor.feeders f USING (feeder_id)")

feeders <- st_read(con, query = "
  SELECT feeder_id, voltage_class, customers_served, geom FROM sor.feeders")

# --- 1. Tabular: what is causing outages, and how big are they? -------------
cause_summary <- outages |>
  st_drop_geometry() |>
  filter(status == "active") |>
  group_by(cause_category) |>
  summarise(
    n              = n(),
    customers      = sum(customers_affected, na.rm = TRUE),
    mean_customers = round(mean(customers_affected, na.rm = TRUE)),
    n_missing      = sum(is.na(customers_affected))   # surface data quality, don't hide it
  ) |>
  arrange(desc(customers))

print(cause_summary)
write.csv(cause_summary, "cause_summary.csv", row.names = FALSE)

# --- 2. Reliability proxy: customer-weighted outage exposure by voltage -----
exposure <- outages |>
  st_drop_geometry() |>
  filter(status == "active") |>
  group_by(voltage_class) |>
  summarise(active_outages = n(), customers_out = sum(customers_affected, na.rm = TRUE))

print(exposure)

# --- 3. Map: outage locations over the feeder network -----------------------
p <- ggplot() +
  geom_sf(data = feeders, aes(color = voltage_class), linewidth = 0.3, alpha = 0.6) +
  geom_sf(data = filter(outages, status == "active"),
          aes(size = customers_affected), color = "#d7301f", alpha = 0.7) +
  scale_size_continuous(name = "Customers affected", range = c(1, 6)) +
  labs(
    title    = "Active outages across the DFW synthetic network",
    subtitle = "Analyst view: reads the same PostGIS the public tile tier serves",
    color    = "Voltage class"
  ) +
  theme_minimal()

ggsave("outage_map.png", p, width = 10, height = 8, dpi = 150)
cat("wrote cause_summary.csv and outage_map.png\n")

# --- Alternative access path: pure OGC, no database credentials at all ------
# Once GeoServer publishes the public views as WFS (GUIDE Phase 5), an
# external analyst needs NO database access -- the standards bridge serves R:
#   outages <- st_read(paste0("WFS:http://localhost:8080/geoserver/ows?",
#                             "service=WFS&request=GetFeature&",
#                             "typeName=public:outages_public"))
# Same data, boundary enforced, zero credentials shared. That contrast --
# internal analyst on the DB vs external analyst on OGC -- is an ADR-005
# talking point.

dbDisconnect(con)
