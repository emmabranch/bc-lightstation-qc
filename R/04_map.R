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
source("R/theme_eb.R")   # shared chart style from the brand kit
eb_use("bc-lightstation-qc")

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

# Readable labels for figures. Source IDs are kept unchanged in the data;
# "mcinees" in the source is labelled McInnes Island here (see README).
station_labels <- c(
  langara_island_lightstation   = "Langara Island",
  bonilla_island_lightstation   = "Bonilla Island",
  mcinees_island_lightstation   = "McInnes Island",
  egg_island_lightstation       = "Egg Island",
  pine_island_lightstation      = "Pine Island",
  kains_island_lightstation     = "Kains Island",
  nootka_point_lightstation     = "Nootka Point",
  chrome_island_lightstation    = "Chrome Island",
  entrance_island_lightstation  = "Entrance Island",
  `departure_bay_(pbs)`         = "Departure Bay (PBS)",
  amphitrite_point_lightstation = "Amphitrite Point",
  race_rocks_lightstation       = "Race Rocks"
)
anom <- anom |>
  mutate(station_label = coalesce(unname(station_labels[station]), station))
readr::write_csv(anom, "data/output/monthly_sst_anomalies_2013_2017.csv")

# ---- Basemap ---------------------------------------------------------------
# bcmaps serves BC Government open data; layers download on first use.
# BC Albers (EPSG:3005) is the standard projection for BC-wide maps.
# Natural Earth coastline (public domain). Uses the high-resolution version
# if rnaturalearthhires is installed, otherwise medium resolution.
basemap <- rnaturalearth::ne_countries(
  scale = if (requireNamespace("rnaturalearthhires", quietly = TRUE)) "large" else "medium",
  country = c("Canada", "United States of America"),
  returnclass = "sf"
) |>
  st_transform(3005)
pts <- anom |> st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
  st_transform(3005)
bbox <- st_bbox(st_buffer(pts, 60000))

lim <- 3   # colour scale limits in degC, symmetric so 0 is the neutral colour

# The month for each frame, drawn as a label in the top-right corner of the map
month_lab <- anom |>
  distinct(month_date) |>
  mutate(label = format(month_date, "%B %Y"),
         x = bbox[["xmax"]] - 25000, y = bbox[["ymax"]] - 25000)

p_map <- ggplot() +
  geom_sf(data = basemap, fill = eb_col$paper, colour = eb_col$muted, linewidth = 0.2) +
  geom_sf(data = pts, aes(fill = anomaly), shape = 21, size = 5, colour = eb_col$ink) +
  geom_label(data = month_lab, aes(x, y, label = label), hjust = 1, vjust = 1,
             family = .eb$mono, fontface = "bold", size = 5.5, colour = eb_col$ink,
             fill = eb_col$white, label.r = unit(0, "pt"),
             label.padding = unit(0.4, "lines")) +
  scale_fill_eb_div(reverse = TRUE,   # blue cooler, red warmer, paper at 0
                       limits = c(-lim, lim), oob = scales::squish,
                       breaks = -3:3,
                       labels = c("\u2264 -3", "-2", "-1", "0", "1", "2", "\u2265 3"),
                       name = "SST anomaly\n(\u00b0C vs 1991-2020)",
                       guide = guide_colourbar(display = "gradient")) +
  coord_sf(xlim = bbox[c(1, 3)], ylim = bbox[c(2, 4)], crs = 3005) +
  labs(title = "BC lightstation sea surface temperature anomaly",
       caption = "Data: BCSOP daily lightstation SST via CIOOS Pacific ERDDAP (OGL-Canada).\nQARTOD-flagged values excluded. Basemap: Natural Earth.") +
  theme_void(base_size = 12, base_family = .eb$sans) +
  theme(plot.background = element_rect(fill = eb_col$paper, colour = NA),
        # Fixed space under the title: gganimate can lay out the title as if it had
        # no height, which lets the map run up underneath it
        plot.title = element_text(family = .eb$sans_heavy, size = 16, margin = margin(b = 26)),
        plot.margin = margin(14, 14, 10, 14),
        plot.caption = element_text(family = .eb$mono, colour = eb_col$muted, size = 7, hjust = 0),
        panel.background = element_rect(fill = "#e8f1f7", colour = NA),
        legend.ticks = element_line(colour = eb_col$ink),
        legend.position = "inside",
        legend.position.inside = c(0.15, 0.25),
        legend.background = element_rect(fill = eb_col$white, colour = eb_col$ink),
        legend.margin = margin(8, 10, 16, 8)) +
        transition_manual(month_date)

dir.create("figures", showWarnings = FALSE)
anim <- animate(p_map, nframes = n_distinct(anom$month_date), fps = 4,
                width = 800, height = 800, res = 110, device = "ragg_png", bg = eb_col$paper,
                renderer = gifski_renderer())
anim_save("figures/sst_anomaly_2013_2017.gif", anim)

# ---- Static heatmap: stations ordered north to south ------------------------
p_heat <- anom |>
  mutate(station_label = reorder(station_label, latitude)) |>
  ggplot(aes(month_date, station_label, fill = anomaly)) +
  geom_tile() +
  scale_fill_eb_div(reverse = TRUE,   # blue cooler, red warmer, paper at 0
                       limits = c(-lim, lim), oob = scales::squish,
                       name = "°C") +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0, 0)) +
  labs(title = "Monthly SST anomaly at BC lightstations, 2013 to 2017",
       subtitle = "Relative to each station's 1991–2020 monthly mean; north at top",
       x = NULL, y = NULL) +
  theme_eb(base_size = 11, grid = "none") +
  theme(axis.line.x = element_blank(), legend.position = "right")
ggsave("figures/sst_anomaly_heatmap.png", p_heat, width = 9, height = 4.5, dpi = 300,
       device = ragg::agg_png)
