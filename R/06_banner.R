# 06_banner.R
# Builds the "data as hero" banner for the project site: one stripe per
# month, coloured by the coast-wide mean SST anomaly (12 lightstations,
# 1991 onward, vs each station's 1991-2020 monthly mean).
# Run from the repo root after 03_write_outputs.R:  Rscript R/06_banner.R

library(dplyr)
library(ggplot2)

qc <- readr::read_csv("data/output/bc_lightstation_sst_qc.csv", show_col_types = FALSE,
                      col_select = c("station", "date", "sst", "qc_aggregate"))

monthly <- qc |>
  filter(qc_aggregate %in% c(1, 2), !is.na(sst)) |>
  mutate(year = as.integer(format(date, "%Y")), month = as.integer(format(date, "%m"))) |>
  group_by(station, year, month) |>
  summarise(sst = mean(sst), n_days = n(), .groups = "drop") |>
  filter(n_days >= 15)

clim <- monthly |>
  filter(year >= 1991, year <= 2020) |>
  group_by(station, month) |>
  summarise(clim = mean(sst), n_years = n(), .groups = "drop") |>
  filter(n_years >= 20)

coast <- monthly |>
  inner_join(clim, by = c("station", "month")) |>
  mutate(anomaly = sst - clim) |>
  group_by(year, month) |>
  summarise(anomaly = mean(anomaly), n_stations = n(), .groups = "drop") |>
  filter(n_stations >= 6) |>
  mutate(month_date = as.Date(sprintf("%d-%02d-01", year, month)))

p <- ggplot(coast, aes(month_date, 1, fill = anomaly)) +
  geom_tile(width = 31) +
  scale_fill_gradient2(low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
                       limits = c(-2, 2), oob = scales::squish) +
  scale_x_date(expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  theme_void() +
  theme(legend.position = "none", plot.margin = margin(0, 0, 0, 0))

dir.create("figures", showWarnings = FALSE)
ggsave("figures/banner_stripes.png", p, width = 16, height = 4, dpi = 120)

cat("Banner covers", format(min(coast$month_date), "%B %Y"), "to",
    format(max(coast$month_date), "%B %Y"), "\n")
