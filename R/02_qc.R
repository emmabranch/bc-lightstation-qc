# 02_qc.R
# Select well-covered stations, regularise to one row per station-day,
# run the QARTOD tests, and save flagged data plus diagnostic plots.

library(dplyr)
library(tidyr)
library(ggplot2)
source("R/config.R")
source("R/qartod.R")

raw <- readr::read_csv("data/raw/BCSOP_daily_latest.csv", show_col_types = FALSE)

# 1. Duplicate check: there should be at most one sample per station-day
dups <- raw |> count(station, date) |> filter(n > 1)
if (nrow(dups) > 0) {
  warning(nrow(dups), " duplicate station-days; keeping the first. See data/qc/duplicates.csv")
  dir.create("data/qc", recursive = TRUE, showWarnings = FALSE)
  readr::write_csv(dups, "data/qc/duplicates.csv")
}
raw <- raw |> distinct(station, date, .keep_all = TRUE)

# 2. Keep stations with good coverage of the 1991-2020 baseline
n_days_base <- as.numeric(as.Date(sprintf("%d-12-31", CLIM_END)) -
                          as.Date(sprintf("%d-01-01", CLIM_START))) + 1
coverage <- raw |>
  filter(as.integer(format(date, "%Y")) >= CLIM_START,
         as.integer(format(date, "%Y")) <= CLIM_END, !is.na(sst)) |>
  count(station, name = "n_obs") |>
  mutate(coverage = n_obs / n_days_base) |>
  arrange(desc(coverage))
print(coverage, n = Inf)
keep <- coverage |> filter(coverage >= MIN_CLIM_COVERAGE) |> pull(station)

# Station positions can differ slightly between rows; take one per station
stations <- raw |> filter(station %in% keep) |>
  group_by(station) |>
  summarise(latitude = median(latitude), longitude = median(longitude), .groups = "drop")

# 3. Complete daily grid so missing days become explicit (flag 9)
daily <- raw |>
  filter(station %in% keep) |>
  select(station, date, sst) |>
  group_by(station) |>
  complete(date = seq(min(date), max(date), by = "day")) |>
  ungroup()

# 4. Run QARTOD tests per station
flagged <- daily |>
  group_split(station) |>
  lapply(qc_station, value_col = "sst", cfg = QC_CONFIG) |>
  bind_rows() |>
  left_join(stations, by = "station")

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
saveRDS(flagged, "data/processed/flagged.rds")

# 5. Summaries for the README and tutorial
flag_labels <- c(`1` = "PASS", `2` = "NOT_EVALUATED", `3` = "SUSPECT", `4` = "FAIL", `9` = "MISSING")
summary_tbl <- flagged |>
  pivot_longer(starts_with("qc_"), names_to = "test", values_to = "flag") |>
  count(test, flag) |>
  mutate(flag = flag_labels[as.character(flag)]) |>
  pivot_wider(names_from = flag, values_from = n, values_fill = 0)
print(summary_tbl)
readr::write_csv(summary_tbl, "data/processed/qc_summary.csv")

# 6. Diagnostic plot: one station, coloured by aggregate flag.
#    Look at these before trusting the thresholds in config.R.
dir.create("figures", showWarnings = FALSE)
for (st in head(keep, 3)) {
  p <- flagged |>
    filter(station == st, date >= as.Date("2014-01-01"), date <= as.Date("2016-12-31")) |>
    mutate(flag = factor(flag_labels[as.character(qc_aggregate)],
                         levels = c("PASS", "NOT_EVALUATED", "SUSPECT", "FAIL", "MISSING"))) |>
    ggplot(aes(date, sst)) +
    geom_line(colour = "grey70", linewidth = 0.3) +
    geom_point(aes(colour = flag), size = 0.8) +
    scale_colour_manual(values = c(PASS = "#1b7837", NOT_EVALUATED = "grey50",
                                   SUSPECT = "#e08214", FAIL = "#b2182b", MISSING = "black"),
                        drop = FALSE) +
    labs(title = paste("QARTOD aggregate flags:", st),
         x = NULL, y = "Sea surface temperature (°C)", colour = "Flag") +
    theme_minimal()
  ggsave(sprintf("figures/qc_%s.png", gsub("[^A-Za-z0-9]", "_", st)), p,
         width = 8, height = 3.5, dpi = 150)
}
