# 05_interactive_map.R
# Interactive leaflet map of annual mean SST anomalies at BC lightstations.
# - One layer per year (2013 to 2017), switched with the year buttons
# - Click a station for its name, the years of data used, its annual
#   anomaly, and a small chart of monthly anomalies with 2014 to 2016 shaded
# - Pure HTML/JavaScript, so it works on GitHub Pages with no Shiny server
#
# Used from index.qmd. Run 04_map.R first, because it writes the monthly
# anomaly CSV this script reads.

library(dplyr)
library(leaflet)
library(htmltools)

# Small inline SVG chart of monthly anomalies for one station.
# Built by hand so popups need no extra packages and stay lightweight.
sparkline_svg <- function(d, w = 230, h = 95, lim = 3.5) {
  d <- d[order(d$month_date), ]
  x0 <- as.numeric(as.Date("2013-01-01")); x1 <- as.numeric(as.Date("2017-12-31"))
  pad_l <- 26; pad_r <- 6; pad_t <- 6; pad_b <- 16
  sx <- function(x) pad_l + (as.numeric(x) - x0) / (x1 - x0) * (w - pad_l - pad_r)
  sy <- function(y) pad_t + (lim - pmax(pmin(y, lim), -lim)) / (2 * lim) * (h - pad_t - pad_b)
  band <- sprintf('<rect x="%.1f" y="%d" width="%.1f" height="%d" fill="#fde0d2"/>',
                  sx(as.Date("2014-01-01")), pad_t,
                  sx(as.Date("2017-01-01")) - sx(as.Date("2014-01-01")), h - pad_t - pad_b)
  zero <- sprintf('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="#888" stroke-width="0.8"/>',
                  pad_l, w - pad_r, sy(0), sy(0))
  # Break the line where months are missing
  ok <- !is.na(d$anomaly)
  seg <- cumsum(c(1, diff(as.numeric(d$month_date)) > 32 | diff(ok) != 0))
  lines <- vapply(split(seq_len(nrow(d))[ok], seg[ok]), function(i) {
    pts <- paste(sprintf("%.1f,%.1f", sx(d$month_date[i]), sy(d$anomaly[i])), collapse = " ")
    sprintf('<polyline points="%s" fill="none" stroke="#111111" stroke-width="1.4"/>', pts)
  }, character(1))
  ylab <- paste0(
    sprintf('<text x="%d" y="%.1f" font-size="9" text-anchor="end" fill="#5A544A">%s</text>',
            pad_l - 3, sy(c(3, 0, -3)) + 3, c("+3", "0", "-3")), collapse = "")
  xlab <- paste0(
    sprintf('<text x="%.1f" y="%d" font-size="9" text-anchor="middle" fill="#5A544A">%s</text>',
            sx(as.Date(sprintf("%d-07-01", 2013:2017))), h - 3, 2013:2017), collapse = "")
  sprintf('<svg width="%d" height="%d" viewBox="0 0 %d %d" role="img" aria-label="Monthly SST anomaly 2013 to 2017">%s%s%s%s%s</svg>',
          w, h, w, h, band, zero, paste(lines, collapse = ""), ylab, xlab)
}

build_interactive_map <- function(
    anom_csv = "data/output/monthly_sst_anomalies_2013_2017.csv",
    qc_csv   = "data/output/bc_lightstation_sst_qc.csv",
    default_year = 2015) {

  anom <- readr::read_csv(anom_csv, show_col_types = FALSE)
  if (!"station_label" %in% names(anom)) anom$station_label <- anom$station

  # Years of data used in this project, per station
  record <- readr::read_csv(qc_csv, show_col_types = FALSE,
                            col_select = c("station", "date", "sst")) |>
    filter(!is.na(sst)) |>
    group_by(station) |>
    summarise(first_year = min(as.integer(format(date, "%Y"))),
              last_year  = max(as.integer(format(date, "%Y"))), .groups = "drop")

  stations <- anom |>
    group_by(station, station_label) |>
    summarise(latitude = first(latitude), longitude = first(longitude), .groups = "drop") |>
    left_join(record, by = "station")

  # Annual mean anomaly; require at least 9 valid months in the year
  years <- 2013:2017
  annual <- anom |>
    group_by(station, year) |>
    summarise(n_months = n(), anomaly = mean(anomaly), .groups = "drop") |>
    mutate(anomaly = ifelse(n_months >= 9, anomaly, NA_real_)) |>
    right_join(tidyr::expand_grid(station = stations$station, year = years),
               by = c("station", "year")) |>
    left_join(stations, by = "station")

  # Binned diverging palette: easier to read than a continuous scale for
  # annual means, which are smaller than monthly anomalies
  bins   <- c(-Inf, -1.5, -1, -0.5, 0.5, 1, 1.5, Inf)
  # Brand diverging colours, blue cooler to red warmer, paper for near normal
  cols   <- c("#1F33B5", "#6678D8", "#ACB6E7", "#F3EEE3", "#E6AB95", "#CB6852", "#A3241A")
  labels <- c("below -1.5", "-1.5 to -1", "-1 to -0.5", "-0.5 to +0.5 (near normal)",
              "+0.5 to +1", "+1 to +1.5", "above +1.5")
  pal <- colorBin(cols, domain = c(-10, 10), bins = bins, na.color = "#bdbdbd")

  sparks <- lapply(split(anom, anom$station), sparkline_svg)

  popup_html <- function(r) {
    val <- if (is.na(r$anomaly)) "not enough data" else sprintf("%+.1f &deg;C", r$anomaly)
    paste0(
      "<div style='font-family:\"Bricolage Grotesque\",sans-serif;font-size:13px;max-width:240px'>",
      "<strong>", htmlEscape(r$station_label), "</strong><br>",
      r$year, " annual mean anomaly: <strong>", val, "</strong><br>",
      "<span style='color:#5A544A'>Data used: ", r$first_year, " to ", r$last_year, "</span>",
      "<div style='margin-top:6px'>", sparks[[r$station]], "</div>",
      "<span style='color:#5A544A;font-size:11px'>Monthly anomaly, &deg;C vs 1991-2020. ",
      "Shaded: 2014 to 2016.</span></div>")
  }

  m <- leaflet(height = 520, options = leafletOptions(minZoom = 4)) |>
    addProviderTiles(providers$Esri.WorldGrayCanvas) |>
    fitBounds(min(stations$longitude) - 0.5, min(stations$latitude) - 0.3,
              max(stations$longitude) + 0.5, max(stations$latitude) + 0.3)

  for (y in years) {
    d <- annual[annual$year == y, ]
    m <- m |>
      addCircleMarkers(
        data = d, lng = ~longitude, lat = ~latitude, group = as.character(y),
        radius = 9, color = "#111111", weight = 1, opacity = 1,
        fillColor = pal(d$anomaly), fillOpacity = 0.95,
        label = lapply(sprintf("%s: %s", htmlEscape(d$station_label),
                               ifelse(is.na(d$anomaly), "no data",
                                      sprintf("%+.1f &deg;C", d$anomaly))), HTML),
        popup = vapply(seq_len(nrow(d)), function(i) popup_html(d[i, ]), character(1)),
        popupOptions = popupOptions(maxWidth = 260))
  }

  # Hide the other years BEFORE adding the control: leaflet shows the first
  # visible base group, so this makes the default year the selected one.
  m |>
    hideGroup(setdiff(as.character(years), as.character(default_year))) |>
    addLayersControl(baseGroups = as.character(years),
                     options = layersControlOptions(collapsed = FALSE),
                     position = "topright") |>
    addLegend(position = "bottomleft", colors = c(cols, "#bdbdbd"),
              labels = c(labels, "not enough data"), opacity = 0.95,
              title = "Annual mean SST anomaly<br>(&deg;C vs 1991-2020)")
}
