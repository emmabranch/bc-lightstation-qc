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
    suspect_span = c(0, 22)      # outside what BC coastal surface water usually reaches
  ),
  spike = list(suspect = 2.5, fail = 5.0),   # degC departure from neighbour mean
  rate_of_change = list(n_dev = 3, window_days = 30, min_obs = 10),
  flat_line = list(suspect_n = 5, fail_n = 10)  # consecutive identical daily values
)
