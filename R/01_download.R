# 01_download.R
# Pull daily lightstation SST and salinity from CIOOS Pacific ERDDAP.
# Run from the repo root:  Rscript R/01_download.R
#
# ERDDAP notes for newcomers:
# - ERDDAP is a data server. "tabledap" serves tables (station time series,
#   profiles); "griddap" serves gridded data (satellite, models).
# - Every request is just a URL. rerddap builds it for you, but you can paste
#   the same request into a browser, which is great for reproducibility.
# - In BCSOP_daily the station name lives in a variable called `profile`
#   (it carries cf_role = "timeseries_id"). We rename it to `station`.

library(rerddap)
library(dplyr)
source("R/config.R")

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

# 1. Inspect the dataset metadata first (good habit, and you will reuse it)
info_obj <- info(DATASET_ID, url = ERDDAP_URL)
print(info_obj)
saveRDS(info_obj, "data/raw/BCSOP_daily_info.rds")

# 2. Request the data. Constraints are passed as strings.
raw <- tabledap(
  info_obj,
  fields = c("profile", "latitude", "longitude", "time", "TEMPTC01", "PSALPR01"),
  paste0("time>=", START_DATE),
  url = ERDDAP_URL
)

raw <- as_tibble(raw) |>
  transmute(
    station   = profile,
    latitude  = as.numeric(latitude),
    longitude = as.numeric(longitude),
    date      = as.Date(substr(time, 1, 10)),
    sst       = as.numeric(TEMPTC01),
    salinity  = as.numeric(PSALPR01)
  )

# 3. Save the untouched pull with a timestamp. Never edit raw data.
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
readr::write_csv(raw, sprintf("data/raw/BCSOP_daily_%s.csv", stamp))
readr::write_csv(raw, "data/raw/BCSOP_daily_latest.csv")

# Record exactly what was requested (provenance for the metadata `history`)
writeLines(c(
  paste("retrieved_utc:", stamp),
  paste("erddap:", ERDDAP_URL),
  paste("dataset_id:", DATASET_ID),
  paste("constraint: time>=", START_DATE),
  paste("rows:", nrow(raw))
), "data/raw/RETRIEVAL_LOG.txt")

cat("Rows:", nrow(raw), " Stations:", n_distinct(raw$station), "\n")
