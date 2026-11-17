# qartod.R
# Base-R implementations of four IOOS QARTOD tests, adapted for DAILY
# lightstation sea surface temperature (BCSOP_daily on CIOOS Pacific ERDDAP).
#
# QARTOD flag scheme (IOOS / UNESCO-IOC primary level flags):
#   1 = PASS            data passed the test
#   2 = NOT_EVALUATED   test could not be run (e.g., neighbours missing)
#   3 = SUSPECT         questionable, keep but review
#   4 = FAIL            data judged bad
#   9 = MISSING         no observation
#
# Important caveat: the QARTOD manuals were written mainly for real-time,
# high-frequency sensor data. Applying them to daily bucket samples is an
# adaptation, so every threshold below is a documented, tunable choice.
#
# All functions expect ONE station's data, sorted by date, with one row per
# day at most. Gaps are allowed: tests that need neighbours check that the
# neighbours are exactly one day away and otherwise return 2.

QC_PASS <- 1L; QC_NOT_EVAL <- 2L; QC_SUSPECT <- 3L; QC_FAIL <- 4L; QC_MISSING <- 9L

QC_FLAG_VALUES   <- c(1L, 2L, 3L, 4L, 9L)
QC_FLAG_MEANINGS <- "PASS NOT_EVALUATED SUSPECT FAIL MISSING"

# ---------------------------------------------------------------------------
# 1. Gross range test
#    FAIL    if outside the sensor / physical span
#    SUSPECT if outside the operator-defined (user) span
# ---------------------------------------------------------------------------
qc_gross_range <- function(x, fail_span, suspect_span) {
  flag <- rep(QC_PASS, length(x))
  flag[x < suspect_span[1] | x > suspect_span[2]] <- QC_SUSPECT
  flag[x < fail_span[1]    | x > fail_span[2]]    <- QC_FAIL
  flag[is.na(x)] <- QC_MISSING
  flag
}

# ---------------------------------------------------------------------------
# 2. Spike test
#    reference = mean of the previous and next values
#    spike     = |x[n] - reference|
#    SUSPECT if spike > suspect_threshold, FAIL if spike > fail_threshold
#    NOT_EVALUATED if either neighbour is missing or not exactly 1 day away
# ---------------------------------------------------------------------------
qc_spike <- function(x, date, suspect_threshold, fail_threshold) {
  n <- length(x)
  flag <- rep(QC_NOT_EVAL, n)
  if (n >= 3) {
    i <- 2:(n - 1)
    prev_ok <- as.numeric(date[i] - date[i - 1]) == 1
    next_ok <- as.numeric(date[i + 1] - date[i]) == 1
    ref   <- (x[i - 1] + x[i + 1]) / 2
    spike <- abs(x[i] - ref)
    ok <- prev_ok & next_ok & !is.na(spike)
    f <- rep(QC_NOT_EVAL, length(i))
    f[ok] <- QC_PASS
    f[ok & spike > suspect_threshold] <- QC_SUSPECT
    f[ok & spike > fail_threshold]    <- QC_FAIL
    flag[i] <- f
  }
  flag[is.na(x)] <- QC_MISSING
  flag
}

# ---------------------------------------------------------------------------
# 3. Rate of change test (SUSPECT only, as in the QARTOD manuals)
#    SUSPECT if |x[n] - x[n-1]| > n_dev * SD of the trailing window
#    The trailing window is the previous `window_days` calendar days.
#    NOT_EVALUATED if the previous day is missing or the window has fewer
#    than `min_obs` observations.
# ---------------------------------------------------------------------------
qc_rate_of_change <- function(x, date, n_dev = 3, window_days = 30, min_obs = 10) {
  n <- length(x)
  flag <- rep(QC_NOT_EVAL, n)
  d <- as.numeric(date)
  for (k in seq_len(n)[-1]) {
    if (is.na(x[k]) || is.na(x[k - 1]) || (d[k] - d[k - 1]) != 1) next
    in_win <- d >= d[k] - window_days & d < d[k] & !is.na(x)
    if (sum(in_win) < min_obs) next
    s <- stats::sd(x[in_win])
    flag[k] <- if (abs(x[k] - x[k - 1]) > n_dev * s) QC_SUSPECT else QC_PASS
  }
  flag[is.na(x)] <- QC_MISSING
  flag
}

# ---------------------------------------------------------------------------
# 4. Flat line test
#    Counts how many consecutive daily values (ending at n) are identical
#    within `tolerance`. SUSPECT if run >= suspect_n, FAIL if run >= fail_n.
#    A gap in dates or a missing value resets the run.
#    Note: lightstation values are recorded to 0.1 degC, so short runs of
#    identical values are expected, especially in winter.
# ---------------------------------------------------------------------------
qc_flat_line <- function(x, date, suspect_n = 5, fail_n = 10, tolerance = 1e-6) {
  n <- length(x)
  run <- integer(n)
  d <- as.numeric(date)
  for (k in seq_len(n)) {
    if (is.na(x[k])) { run[k] <- 0L; next }
    if (k > 1 && !is.na(x[k - 1]) && (d[k] - d[k - 1]) == 1 &&
        abs(x[k] - x[k - 1]) <= tolerance) {
      run[k] <- run[k - 1] + 1L
    } else {
      run[k] <- 1L
    }
  }
  flag <- rep(QC_PASS, n)
  flag[run >= suspect_n] <- QC_SUSPECT
  flag[run >= fail_n]    <- QC_FAIL
  flag[is.na(x)] <- QC_MISSING
  flag
}

# ---------------------------------------------------------------------------
# Aggregate (primary) flag: the worst result across tests.
#   any FAIL -> 4; else any SUSPECT -> 3; else any PASS -> 1; else 2.
#   Missing observations are 9 regardless.
# ---------------------------------------------------------------------------
qc_aggregate <- function(..., x) {
  m <- cbind(...)
  agg <- apply(m, 1, function(r) {
    if (any(r == QC_FAIL))    return(QC_FAIL)
    if (any(r == QC_SUSPECT)) return(QC_SUSPECT)
    if (any(r == QC_PASS))    return(QC_PASS)
    QC_NOT_EVAL
  })
  agg[is.na(x)] <- QC_MISSING
  as.integer(agg)
}

# ---------------------------------------------------------------------------
# Run all tests for one station. `cfg` is the list defined in R/config.R.
# ---------------------------------------------------------------------------
qc_station <- function(df, value_col, cfg) {
  df <- df[order(df$date), ]
  x <- df[[value_col]]
  df$qc_gross_range <- qc_gross_range(x, cfg$gross_range$fail_span, cfg$gross_range$suspect_span)
  df$qc_spike       <- qc_spike(x, df$date, cfg$spike$suspect, cfg$spike$fail)
  df$qc_rate_of_change <- qc_rate_of_change(x, df$date, cfg$rate_of_change$n_dev,
                                            cfg$rate_of_change$window_days,
                                            cfg$rate_of_change$min_obs)
  df$qc_flat_line   <- qc_flat_line(x, df$date, cfg$flat_line$suspect_n, cfg$flat_line$fail_n)
  df$qc_aggregate   <- qc_aggregate(df$qc_gross_range, df$qc_spike,
                                    df$qc_rate_of_change, df$qc_flat_line, x = x)
  df
}
