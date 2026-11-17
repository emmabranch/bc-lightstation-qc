# Build plan (about 7 hours)

Deadline: CIOOS Data Manager application closes 22 November 2026. Aim to finish by the evening of 20 November so you have a buffer.

## Step 0. Setup (30 min)

- Create a public GitHub repo `bc-lightstation-qc`, clone it, and copy these files in.
- Open it as an RStudio project. Install packages:

```r
install.packages(c("rerddap", "dplyr", "tidyr", "readr", "ggplot2", "sf",
                   "gganimate", "gifski", "ncdf4", "bcmaps", "scales", "tibble"))
```

- Install the IOOS Compliance Checker (Python, one-off):

```bash
pip install compliance-checker
```

- Run the unit tests: `Rscript tests/test_qartod.R`. All six should pass before you touch real data.
- Commit: "Initial scaffold".

## Step 1. Download (30 min)

- Open https://data.cioospacific.ca/erddap/tabledap/BCSOP_daily.html in a browser first. Look at the variable list and the "Data Access Form". This is what `rerddap` is calling under the hood.
- Run `Rscript R/01_download.R`.
- Check the printed row and station counts. Open `data/raw/RETRIEVAL_LOG.txt`.
- If `tabledap()` errors on the time constraint, try `"time>=1991-01-01T00:00:00Z"`.
- Commit.

## Step 2. QC (1.5 to 2 hours, the core of the project)

- Run `Rscript R/02_qc.R`. Read the station coverage table it prints and note which stations survive the 80% rule.
- Open the PNGs in `figures/`. For each threshold in `R/config.R`, ask: are the SUSPECT and FAIL points ones a human would also question?
  - Gross range: look at `summary(raw$sst)` and the extremes by station. Warm shallow stations (for example in the Strait of Georgia) may legitimately exceed 22 degC in summer; if so, consider station-specific suspect spans.
  - Spike and rate of change: the 14-day tidal artifact in daily data means some day-to-day jumps are real sampling effects, not errors. If too many PASS-worthy points are SUSPECT, loosen the thresholds.
  - Flat line: values are recorded to 0.1 degC, so short repeats are normal.
- Write down every change and why in the "QC decisions" table in README.md. This log is the thing a data manager reviewer will look for.
- Commit.

## Step 3. Outputs and metadata (1 hour)

- Put your contact email in `R/03_write_outputs.R` (both `creator_email` and `publisher_email`).
- Run `Rscript R/03_write_outputs.R`.
- Run the compliance checker and save the report:

```bash
compliance-checker --test=cf:1.8 --test=acdd:1.3 \
  data/output/bc_lightstation_sst_qc.nc > docs/compliance_report.txt
```

- CF should pass. ACDD will list a few "Recommended" items (for example `geospatial_bounds`). Fix any you can, and mention the rest honestly in the README rather than hiding them.
- Commit.

## Step 4. Map (1 hour)

- Run `Rscript R/04_map.R`. The first `bcmaps` call downloads the BC boundary layer and may ask to create a cache folder; say yes.
- Check the GIF and the heatmap. The heatmap is often the better figure for the README; the GIF is the eye-catcher for the tutorial.
- Commit.

## Step 5. Quarto tutorial and GitHub Pages (1.5 hours)

- Edit `index.qmd`. Replace every `TODO` with your own numbers and observations from Steps 2 to 4.
- Preview: `quarto preview`.
- Publish: `quarto publish gh-pages`. Site will be at https://emmabranch.github.io/bc-lightstation-qc/.
- Add the site link to the repo "About" box and the README.
- Commit.

## Step 6. Zenodo DOI (30 min)

Order matters here:

1. Log in to https://zenodo.org with your GitHub account.
2. In Zenodo, go to your account menu, then GitHub, and flip the switch ON for `bc-lightstation-qc`. Do this BEFORE making a release.
3. Edit `.zenodo.json` if needed (it controls the Zenodo title, authors, licence, and keywords).
4. On GitHub, create a release: tag `v1.0.0`, title "v1.0.0: initial QC'd release".
5. Within a few minutes Zenodo archives the snapshot and mints a DOI. Copy the DOI badge into the README and the DOI into `CITATION.cff`, then commit.

## Step 7. Final polish (30 min)

- Link this repo from bc-salmon-explorer's README, and vice versa.
- Pin the repo on your GitHub profile.
- Re-read README top to bottom as if you were the hiring manager.

## If you run short of time, cut in this order

1. The GIF (keep the static heatmap).
2. The salinity column (already out of scope).
3. Zenodo (but it is quick and very on-brand for a CIOOS data role, so try to keep it).
