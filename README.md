# BC lightstation SST: QARTOD-style quality control in R

<!-- After the Zenodo release, paste the DOI badge here -->

Daily sea surface temperature (SST) from British Columbia lightstations, pulled from the [CIOOS Pacific ERDDAP](https://data.cioospacific.ca/erddap/tabledap/BCSOP_daily.html) server, annotated with automated quality control flags adapted from the IOOS [QARTOD](https://ioos.noaa.gov/project/qartod/) manuals, and published as a CF/ACDD-compliant NetCDF file, a tidy CSV, and a data dictionary.

Tutorial: https://emmabranch.github.io/bc-lightstation-qc/

Companion project: [BC Salmon Explorer](https://emmabranch.shinyapps.io/bc-salmon-explorer) ([repo](https://github.com/emmabranch/bc-salmon-explorer)), which shows salmon data for the same coast and years.

![SST anomaly heatmap](figures/sst_anomaly_heatmap.png)

## What this project does

- Retrieves BCSOP daily lightstation data from 1991 onward with `rerddap`, logging the exact request.
- Keeps stations with at least 80% daily coverage over the 1991 to 2020 climate normal period.
- Applies four QARTOD tests (gross range, spike, rate of change, flat line) plus an aggregate flag, using the standard flag scheme: 1 PASS, 2 NOT_EVALUATED, 3 SUSPECT, 4 FAIL, 9 MISSING.
- Never alters source values. Flags sit alongside the data, linked in the NetCDF with `ancillary_variables` and CF quality-flag standard names.
- Writes CF-1.8 and ACDD-1.3 metadata, checked with the IOOS Compliance Checker (report in `docs/`).
- Maps monthly SST anomalies across the 2014 to 2016 northeast Pacific marine heatwave.

## Important limitations

- QARTOD tests were designed mainly for real-time, high-frequency sensor data. These are daily bucket samples taken near daytime high tide, so thresholds were adapted and are documented below.
- Daily values contain a 14-day tidal-cycle sampling artifact (noted by the data provider). This affects the spike and rate of change tests.
- This is an independent portfolio product, not an official DFO or CIOOS dataset. For authoritative data, use the source.

## QC decisions

| Test | Setting | Rationale | Changed after review? |
|---|---|---|---|
| Gross range | FAIL outside -2.5 to 35 degC; SUSPECT outside 0 to 22 degC | TODO | TODO |
| Spike | SUSPECT > 2.5 degC, FAIL > 5 degC from neighbour mean | TODO | TODO |
| Rate of change | SUSPECT if day-to-day change > 3 SD of previous 30 days (min 10 obs) | TODO | TODO |
| Flat line | SUSPECT at 5, FAIL at 10 identical consecutive daily values | TODO | TODO |

## Outputs (`data/output/`)

| File | Contents |
|---|---|
| `bc_lightstation_sst_qc.nc` | NetCDF, CF timeSeries (orthogonal station x time), SST plus five flag variables |
| `bc_lightstation_sst_qc.csv` | Same data in long format, one row per station-day |
| `data_dictionary.csv` | Variable definitions, units, CF standard names, allowed values |
| `monthly_sst_anomalies_2013_2017.csv` | Monthly anomalies used in the map |

## Reproduce

```bash
Rscript tests/test_qartod.R
Rscript R/01_download.R
Rscript R/02_qc.R
Rscript R/03_write_outputs.R
Rscript R/04_map.R
compliance-checker --test=cf:1.8 --test=acdd:1.3 data/output/bc_lightstation_sst_qc.nc
quarto render
```

## Data source and licence

Source: British Columbia Shore Station Oceanographic Program (BCSOP), Institute of Ocean Sciences, Fisheries and Oceans Canada, distributed by CIOOS Pacific. Contains information licensed under the [Open Government Licence - Canada](https://open.canada.ca/en/open-government-licence-canada).

Code: MIT licence. Derived data: CC-BY-4.0, with attribution to the source above.
