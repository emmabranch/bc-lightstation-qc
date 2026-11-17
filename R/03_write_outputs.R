# 03_write_outputs.R
# Write the analysis-ready outputs: tidy CSV, CF/ACDD NetCDF, and the
# data dictionary. Edit the creator_* fields before running.

library(dplyr)
source("R/config.R")
source("R/qartod.R")
source("R/write_netcdf.R")

flagged <- readRDS("data/processed/flagged.rds")
dir.create("data/output", recursive = TRUE, showWarnings = FALSE)

version <- "1.0.0"
retrieval <- readLines("data/raw/RETRIEVAL_LOG.txt")

global_atts <- list(
  Conventions = "CF-1.8, ACDD-1.3",
  title = "Quality-controlled daily sea surface temperature at BC lightstations, 1991 to present",
  summary = paste(
    "Daily sea surface temperature from the British Columbia Shore Station Oceanographic",
    "Program (BCSOP), retrieved from CIOOS Pacific ERDDAP (dataset BCSOP_daily),",
    "restricted to stations with at least 80% coverage of 1991-2020, and annotated with",
    "automated quality control flags adapted from IOOS QARTOD (gross range, spike,",
    "rate of change, flat line). Original values are unchanged; flags are added alongside.",
    "Thresholds are documented in R/config.R. This is an independent portfolio product,",
    "not an official DFO or CIOOS release."
  ),
  keywords = "sea surface temperature, lightstation, British Columbia, quality control, QARTOD, marine heatwave",
  keywords_vocabulary = "none",
  id = "bc-lightstation-qc",
  naming_authority = "io.github.emmabranch",
  product_version = version,
  processing_level = "Source data with added automated QARTOD-style quality flags; no values altered",
  source = "CIOOS Pacific ERDDAP, dataset BCSOP_daily (Institute of Ocean Sciences, Fisheries and Oceans Canada)",
  history = paste(paste(retrieval, collapse = "; "),
                  "; QC flags added with R scripts in https://github.com/emmabranch/bc-lightstation-qc"),
  references = "https://data.cioospacific.ca/erddap/tabledap/BCSOP_daily.html; https://ioos.noaa.gov/project/qartod/",
  acknowledgement = paste(
    "Contains information licensed under the Open Government Licence - Canada.",
    "Data collected by BC lightstation keepers and the BCSOP, Institute of Ocean Sciences, DFO."
  ),
  license = "Derived product: CC-BY-4.0. Source data: Open Government Licence - Canada.",
  creator_name = "Emma Branch",
  creator_type = "person",
  creator_email = "emma.branch@gmail.com",
  creator_url = "https://github.com/emmabranch",
  publisher_name = "Emma Branch",
  publisher_type = "person",
  publisher_email = "emma.branch@gmail.com",
  publisher_url = "https://github.com/emmabranch",
  institution = "Independent (portfolio project)",
  comment = "Values are surface bucket samples. A 14-day tidal-cycle artifact is present in daily data (see source summary).",
  date_issued = format(Sys.Date()),
  date_modified = format(Sys.Date()),
  project = "Portfolio: quality-controlling CIOOS ocean data in R",
  standard_name_vocabulary = "CF Standard Name Table v84"
)

# 1. NetCDF
write_sst_netcdf(flagged, "data/output/bc_lightstation_sst_qc.nc", global_atts)

# 2. CSV (long format, one row per station-day, for spreadsheet users)
flagged |>
  select(station, latitude, longitude, date, sst, starts_with("qc_")) |>
  arrange(station, date) |>
  readr::write_csv("data/output/bc_lightstation_sst_qc.csv", na = "")

# 3. Data dictionary
dict <- tibble::tribble(
  ~variable, ~type, ~units, ~cf_standard_name, ~description, ~allowed_values,
  "station", "string", "", "", "Lightstation name (source variable `profile`, the timeseries_id)", "",
  "latitude", "float", "degrees_north", "latitude", "Station latitude (median of source rows)", "48 to 55",
  "longitude", "float", "degrees_east", "longitude", "Station longitude (median of source rows)", "-134 to -122",
  "date", "date", "", "time", "Sampling date (samples taken near daytime high tide)", "YYYY-MM-DD",
  "sst", "float", "degree_C", "sea_water_temperature", "Bucket sea surface temperature, unaltered from source TEMPTC01", "blank = missing",
  "qc_gross_range", "integer", "", "gross_range_test_quality_flag", "QARTOD gross range test", "1,2,3,4,9",
  "qc_spike", "integer", "", "spike_test_quality_flag", "QARTOD spike test", "1,2,3,4,9",
  "qc_rate_of_change", "integer", "", "rate_of_change_test_quality_flag", "QARTOD rate of change test (suspect only)", "1,2,3,9",
  "qc_flat_line", "integer", "", "flat_line_test_quality_flag", "QARTOD flat line test", "1,3,4,9",
  "qc_aggregate", "integer", "", "aggregate_quality_flag", "Worst flag across the four tests", "1,2,3,4,9"
)
readr::write_csv(dict, "data/output/data_dictionary.csv")

cat("Wrote NetCDF, CSV, and data dictionary to data/output/\n")
cat("Next: run the IOOS Compliance Checker (see README).\n")
