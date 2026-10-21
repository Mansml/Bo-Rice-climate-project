# Are Bo District's rice seasons changing?

**Testing farmers' climate reports against 45 years of satellite rainfall, vegetation, yield and price data, in R.**

*Author: Mohamed Lamin Mansaray*

In a 2026 survey of 50 smallholder rice farmers in Bo District, Sierra Leone, 60% said they had noticed changes in the weather. This project checks those reports against satellite data and asks four questions:

| Part | Question | Data | Methods |
|---|---|---|---|
| **A** | Has the rainy season changed since 1981? | CHIRPS daily rainfall | Agronomic onset, dry spells, Rx5day, SPI; Mann–Kendall trend test, Sen's slope |
| **B** | Do poor rainfall seasons show up as lower farmland greenness? | MODIS NDVI/EVI, ESA WorldCover | Cloud screening, seasonal profiles, correlation, mapping |
| **C** | Can rainfall explain rice yield swings, and does ML beat regression? | FAOSTAT yield + national rainfall | LOESS detrending; linear regression vs random forest; leave-one-year-out cross-validation |
| **D** | How strong is the seasonal rice price cycle, and does rainfall affect it? | WFP market prices (HDX) | Seasonal index (2×12 moving average), lean-season premium, Spearman correlation |

## How to reproduce

1. **Get the satellite data.** Run `gee/01_export_data.js` in the [Google Earth Engine Code Editor](https://code.earthengine.google.com). Download the five exported files from Google Drive into `data/raw/`.
2. **Get the yield and price data** (see `data/raw/README.md`):
   - **FAOSTAT:** Sierra Leone, Rice, Yield → `faostat_rice_yield_sle.csv`
   - **HDX:** WFP food prices for Sierra Leone → `wfp_food_prices_sle.csv`
3. **Run everything.** Open `bo-rice-climate.Rproj` in RStudio and run:
   ```r
   source("R/run_all.R")
   ```
   This cleans the data, runs Parts A–D, saves the figures and tables in `output/`, and renders `report/report.html` and `report/report.docx`.

If a real data file is missing, the code uses a made-up example file from `data/example/` instead, so the pipeline can still be tested. The report then shows a clear warning. **Never report results from example data.**

## Project structure

```
bo-rice-climate/
├── bo-rice-climate.Rproj     open this in RStudio
├── gee/01_export_data.js     Google Earth Engine extraction script
├── R/
│   ├── 00_setup.R            packages, settings, graph style
│   ├── functions.R           rainfall indices, SPI, Mann-Kendall, Sen's slope
│   ├── make_example_data.R   creates made-up test data
│   ├── 01_load_clean.R       reads, checks and cleans all raw data
│   ├── 02_rainfall.R         Part A
│   ├── 03_vegetation.R       Part B
│   ├── 04_yield_models.R     Part C
│   ├── 05_prices.R           Part D
│   └── run_all.R             runs everything + renders the report
├── data/raw/                 real downloaded data (you add these)
├── data/example/             made-up test data
├── data/processed/           cleaned data (created by the code)
├── output/figures/           all figures (PNG, 300 dpi)
├── output/tables/            all result tables (CSV)
└── report/report.qmd         the write-up (Quarto)
```

## Data sources

- Funk et al. (2015) CHIRPS v2.0. https://www.chc.ucsb.edu/data/chirps
- Didan, K. (2021) MOD13Q1 MODIS/Terra Vegetation Indices 16-Day L3 Global 250m v061. NASA LP DAAC.
- Zanaga et al. (2022) ESA WorldCover 10 m 2021 v200.
- FAO (2015) Global Administrative Unit Layers (GAUL).
- FAOSTAT, Crops and livestock products (QCL). https://www.fao.org/faostat/
- WFP Market Monitoring, via the Humanitarian Data Exchange. https://data.humdata.org/dataset/wfp-food-prices-for-sierra-leone
