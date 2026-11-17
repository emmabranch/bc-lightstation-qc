# Run from the repo root:  Rscript tests/test_qartod.R
source("R/qartod.R")

check <- function(desc, got, want) {
  ok <- identical(as.integer(got), as.integer(want))
  cat(sprintf("[%s] %s\n", if (ok) "PASS" else "FAIL", desc))
  if (!ok) { cat("  got: ", got, "\n  want:", want, "\n"); quit(status = 1) }
}

d <- as.Date("2015-01-01") + 0:6

check("gross range: pass, suspect, fail, missing",
      qc_gross_range(c(10, 23, 40, NA), c(-2.5, 35), c(0, 22)),
      c(1, 3, 4, 9))

check("spike: spike fails; its neighbours are pulled to suspect (expected QARTOD behaviour)",
      qc_spike(c(10, 10, 20, 10, 10, 10, 10), d, 2.5, 5),
      c(2, 3, 4, 3, 1, 1, 2))

check("spike: gap in dates means not evaluated",
      qc_spike(c(10, 10, 10), as.Date(c("2015-01-01", "2015-01-02", "2015-01-05")), 2.5, 5),
      c(2, 2, 2))

check("spike: good neighbour of a bad value is downgraded from FAIL to SUSPECT",
      qc_spike(c(18.6, 18.8, 8.1, 17.8, 17.8), as.Date("2024-07-12") + 0:4, 2.5, 5),
      c(2, 3, 4, 3, 2))

check("flat line: run of 5 identical -> suspect at 5th",
      qc_flat_line(c(8, 8, 8, 8, 8, 9, 9), d, suspect_n = 5, fail_n = 10),
      c(1, 1, 1, 1, 3, 1, 1))

set.seed(1)
dd <- as.Date("2015-01-01") + 0:39
xx <- 10 + rnorm(40, 0, 0.3); xx[40] <- xx[39] + 5
roc <- qc_rate_of_change(xx, dd, n_dev = 3, window_days = 30, min_obs = 10)
check("rate of change: early days not evaluated, jump flagged suspect",
      c(roc[1:10], roc[40]), c(rep(2, 10), 3))

check("aggregate: worst flag wins, missing stays 9",
      qc_aggregate(c(1, 1, 1, 9), c(2, 3, 1, 9), c(1, 1, 4, 9), x = c(1, 2, 3, NA)),
      c(1, 3, 4, 9))

cat("All QARTOD tests passed.\n")
