# write_netcdf.R
# Write flagged daily SST to a CF-1.8 / ACDD-1.3 NetCDF file using the
# "orthogonal multidimensional array" layout for timeSeries features
# (CF Conventions, Chapter 9 and Appendix H.2.1): every station shares one
# time axis, so data variables have dimensions (station, time).
#
# Why NetCDF? It is the standard self-describing format in oceanography.
# Metadata travels inside the file, and ERDDAP, THREDDS, and the IOOS
# Compliance Checker all understand it.

library(ncdf4)

write_sst_netcdf <- function(flagged, path, global_atts) {
  stations <- unique(flagged[, c("station", "latitude", "longitude")])
  stations <- stations[order(stations$station), ]
  dates <- seq(min(flagged$date), max(flagged$date), by = "day")
  n_st <- nrow(stations); n_t <- length(dates)

  # Build station x time matrices
  to_matrix <- function(col, fill) {
    # R writes dimensions in reverse order, so an R matrix of [time, station]
    # is stored as (station, time) on disk, which is what CF expects.
    m <- matrix(fill, nrow = n_t, ncol = n_st)
    i <- match(flagged$date, dates)
    j <- match(flagged$station, stations$station)
    m[cbind(i, j)] <- flagged[[col]]
    m
  }

  strlen <- max(nchar(stations$station))
  dim_name <- ncdim_def("name_strlen", "", seq_len(strlen), create_dimvar = FALSE)
  dim_st   <- ncdim_def("station", "", seq_len(n_st), create_dimvar = FALSE)
  dim_t    <- ncdim_def("time", "days since 1970-01-01 00:00:00",
                        as.numeric(dates), unlim = FALSE, calendar = "standard")

  v_name <- ncvar_def("station_name", "", list(dim_name, dim_st), prec = "char")
  v_lat  <- ncvar_def("latitude",  "degrees_north", dim_st, missval = NULL, prec = "double")
  v_lon  <- ncvar_def("longitude", "degrees_east",  dim_st, missval = NULL, prec = "double")
  v_sst  <- ncvar_def("sea_water_temperature", "degree_C", list(dim_t, dim_st),
                      missval = -999, prec = "float")

  flag_vars <- c(qc_gross_range = "gross_range_test_quality_flag",
                 qc_spike = "spike_test_quality_flag",
                 qc_rate_of_change = "rate_of_change_test_quality_flag",
                 qc_flat_line = "flat_line_test_quality_flag",
                 qc_aggregate = "aggregate_quality_flag")
  flag_long <- c(qc_gross_range = "QARTOD gross range test flag",
                 qc_spike = "QARTOD spike test flag",
                 qc_rate_of_change = "QARTOD rate of change test flag",
                 qc_flat_line = "QARTOD flat line test flag",
                 qc_aggregate = "QARTOD aggregate (primary) flag")
  v_flags <- lapply(names(flag_vars), function(nm)
    ncvar_def(paste0("sea_water_temperature_", nm), "", list(dim_t, dim_st),
              missval = NULL, prec = "byte"))

  nc <- nc_create(path, c(list(v_name, v_lat, v_lon, v_sst), v_flags), force_v4 = TRUE)
  on.exit(nc_close(nc))

  ncvar_put(nc, v_name, stations$station)
  ncvar_put(nc, v_lat, stations$latitude)
  ncvar_put(nc, v_lon, stations$longitude)
  ncvar_put(nc, v_sst, to_matrix("sst", NA_real_))

  # Coordinate and variable attributes (CF)
  ncatt_put(nc, "time", "standard_name", "time")
  ncatt_put(nc, "time", "long_name", "Sampling date")
  ncatt_put(nc, "time", "axis", "T")
  ncatt_put(nc, "time", "comment",
            "Daily samples are taken near daytime high tide; time is the sampling date, not the exact sample time.")
  ncatt_put(nc, "station_name", "cf_role", "timeseries_id")
  ncatt_put(nc, "station_name", "long_name", "Lightstation name")
  ncatt_put(nc, "latitude", "standard_name", "latitude")
  ncatt_put(nc, "latitude", "long_name", "Station latitude")
  ncatt_put(nc, "latitude", "axis", "Y")
  ncatt_put(nc, "longitude", "standard_name", "longitude")
  ncatt_put(nc, "longitude", "long_name", "Station longitude")
  ncatt_put(nc, "longitude", "axis", "X")

  ncatt_put(nc, "sea_water_temperature", "standard_name", "sea_water_temperature")
  ncatt_put(nc, "sea_water_temperature", "long_name", "Sea surface water temperature (bucket sample)")
  ncatt_put(nc, "sea_water_temperature", "coordinates", "time latitude longitude station_name")
  ncatt_put(nc, "sea_water_temperature", "ancillary_variables",
            paste(paste0("sea_water_temperature_", names(flag_vars)), collapse = " "))
  ncatt_put(nc, "sea_water_temperature", "coverage_content_type", "physicalMeasurement")
  ncatt_put(nc, "sea_water_temperature", "source_variable", "TEMPTC01 (BCSOP_daily)")

  for (k in seq_along(flag_vars)) {
    nm <- names(flag_vars)[k]
    vn <- paste0("sea_water_temperature_", nm)
    ncvar_put(nc, v_flags[[k]], to_matrix(nm, 9L))
    ncatt_put(nc, vn, "standard_name", unname(flag_vars[k]))
    ncatt_put(nc, vn, "long_name", unname(flag_long[nm]))
    ncatt_put(nc, vn, "flag_values", as.integer(QC_FLAG_VALUES), prec = "byte")
    ncatt_put(nc, vn, "flag_meanings", QC_FLAG_MEANINGS)
    ncatt_put(nc, vn, "valid_min", 1L, prec = "byte")
    ncatt_put(nc, vn, "valid_max", 9L, prec = "byte")
    ncatt_put(nc, vn, "coordinates", "time latitude longitude station_name")
    ncatt_put(nc, vn, "references", "https://ioos.noaa.gov/project/qartod/")
    ncatt_put(nc, vn, "coverage_content_type", "qualityInformation")
  }

  # Global attributes (ACDD-1.3 plus CF featureType)
  auto <- list(
    featureType = "timeSeries",
    cdm_data_type = "TimeSeries",
    geospatial_lat_min = min(stations$latitude),
    geospatial_lat_max = max(stations$latitude),
    geospatial_lon_min = min(stations$longitude),
    geospatial_lon_max = max(stations$longitude),
    geospatial_lat_units = "degrees_north",
    geospatial_lon_units = "degrees_east",
    time_coverage_start = format(min(dates)),
    time_coverage_end = format(max(dates)),
    time_coverage_duration = sprintf("P%dD", n_t - 1),
    time_coverage_resolution = "P1D",
    date_created = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  for (a in names(c(global_atts, auto))) ncatt_put(nc, 0, a, c(global_atts, auto)[[a]])
  invisible(path)
}
