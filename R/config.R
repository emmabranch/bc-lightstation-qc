# config.R
# All tunable choices live here so they are visible, documented, and versioned.

ERDDAP_URL <- "https://data.cioospacific.ca/erddap/"
DATASET_ID <- "BCSOP_daily"

START_DATE <- "1991-01-01"   # gives a full 1991-2020 climatology baseline
CLIM_START <- 1991
CLIM_END   <- 2020
MIN_CLIM_COVERAGE <- 0.80    # keep stations with >= 80% of days in 1991-2020

MAP_START <- as.Date("2013-01-01")  # animation window around the 2014-2016
MAP_END   <- as.Date("2017-12-31")  # NE Pacific marine heatwave ("the Blob")

# QARTOD thresholds for daily lightstation SST (degC).
# These are STARTING values. Check them against the data (see 02_qc.R plots)
# and record any change and the reason in README.md.
QC_CONFIG <- list(
  gross_range = list(
    fail_span    = c(-2.5, 35),  # outside physically plausible seawater temps
    suspect_span = c(0, 22),     # outer coast default
    # Strait of Georgia stations: shallow, sheltered water that warms more in
    # summer. Observed multi-station warm events reach 25.4 degC.
    suspect_span_by_station = list(
      chrome_island_lightstation   = c(0, 26),
      `departure_bay_(pbs)`        = c(0, 26),
      entrance_island_lightstation = c(0, 26)
    )
  ),
  spike = list(suspect = 2.5, fail = 5.0),   # degC departure from neighbour mean
  rate_of_change = list(n_dev = 3, window_days = 30, min_obs = 10),
  flat_line = list(suspect_n = 5, fail_n = 10)  # consecutive identical daily values
)
