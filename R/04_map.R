# 04_map.R
# Monthly SST anomalies (vs 1991-2020) at BC lightstations, 2013-2017:
#   1. an animated map (GIF) for the tutorial and README
#   2. a static station-by-month heatmap, which is easier to read in detail
#
# Oceanography conventions used here:
# - An "anomaly" is the departure from a climatological mean for that place
#   and calendar month. Anomalies remove the seasonal cycle so that unusual
#   warmth stands out.
# - 1991-2020 is the current WMO standard climate normal period.
# - Only flag 1 (PASS) and 2 (NOT_EVALUATED) values are used. SUSPECT and
#   FAIL values are excluded, which is how QC flags are meant to be consumed.

library(dplyr)
library(ggplot2)
library(sf)
library(gganimate)
source("R/config.R")

flagged <- readRDS("data/processed/flagged.rds")

monthly <- flagged |>
  filter(qc_aggregate %in% c(1, 2), !is.na(sst)) |>
  mutate(year = as.integer(format(date, "%Y")), month = as.integer(format(date, "%m"))) |>
  group_by(station, latitude, longitude, year, month) |>
  summarise(sst = mean(sst), n_days = n(), .groups = "drop") |>
  filter(n_days >= 15)                         # require a reasonably complete month

clim <- monthly |>
  filter(year >= CLIM_START, year <= CLIM_END) |>
  group_by(station, month) |>
  summarise(clim = mean(sst), n_years = n(), .groups = "drop") |>
  filter(n_years >= 20)

anom <- monthly |>
  inner_join(clim, by = c("station", "month")) |>
  mutate(anomaly = sst - clim,
         month_date = as.Date(sprintf("%d-%02d-01", year, month))) |>
  filter(month_date >= MAP_START, month_date <= MAP_END)

readr::write_csv(anom, "data/output/monthly_sst_anomalies_2013_2017.csv")

# ---- Basemap ---------------------------------------------------------------
# bcmaps serves BC Government open data; layers download on first use.
# BC Albers (EPSG:3005) is the standard projection for BC-wide maps.
basemap <- bcmaps::bc_bound_hres()
pts <- anom |> st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  st_transform(3005)
bbox <- st_bbox(st_buffer(pts, 60000))

lim <- 3   # colour scale limits in degC, symmetric so 0 is the neutral colour

p_map <- ggplot() +
  geom_sf(data = basemap, fill = "grey92", colour = "grey60", linewidth = 0.2) +
  geom_sf(data = pts, aes(fill = anomaly), shape = 21, size = 5, colour = "grey20") +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b",
                       limits = c(-lim, lim), oob = scales::squish,
                       name = "SST anomaly\n(°C vs 1991–2020)") +
  coord_sf(xlim = bbox[c(1, 3)], ylim = bbox[c(2, 4)], crs = 3005) +
  labs(title = "BC lightstation sea surface temperature anomaly",
       subtitle = "{format(as.Date(current_frame), '%B %Y')}",
       caption = "Data: BCSOP daily lightstation SST via CIOOS Pacific ERDDAP (OGL-Canada). QARTOD-flagged values excluded.") +
  theme_void(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        plot.caption = element_text(size = 7, hjust = 0)) +
  transition_manual(month_date)

dir.create("figures", showWarnings = FALSE)
anim <- animate(p_map, nframes = n_distinct(anom$month_date), fps = 4,
                width = 800, height = 800, res = 110,
                renderer = gifski_renderer())
anim_save("figures/sst_anomaly_2013_2017.gif", anim)

# ---- Static heatmap: stations ordered north to south ------------------------
p_heat <- anom |>
  mutate(station = reorder(station, latitude)) |>
  ggplot(aes(month_date, station, fill = anomaly)) +
  geom_tile() +
  scale_fill_gradient2(low = "#2166ac", mid = "white", high = "#b2182b",
                       limits = c(-lim, lim), oob = scales::squish,
                       name = "°C") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0, 0)) +
  labs(title = "Monthly SST anomaly at BC lightstations, 2013 to 2017",
       subtitle = "Relative to each station's 1991–2020 monthly mean; north at top",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(panel.grid = element_blank())
ggsave("figures/sst_anomaly_heatmap.png", p_heat, width = 9, height = 4.5, dpi = 150)
