# Put the real data files here

The file names must match exactly.

| File | Where it comes from |
|---|---|
| `chirps_daily_bo_sle.csv` | Google Earth Engine script (`gee/01_export_data.js`) |
| `modis_ndvi_bo_cropland.csv` | Google Earth Engine script |
| `ndvi_bo_lateseason.tif` | Google Earth Engine script |
| `districts_sle.geojson` | Google Earth Engine script |
| `boundary_bo.geojson` | Google Earth Engine script |
| `faostat_rice_yield_sle.csv` | FAOSTAT website (rename the downloaded file) |
| `wfp_food_prices_sle.csv` | HDX website (rename the downloaded file) |

## FAOSTAT download

1. Go to https://www.fao.org/faostat/en/#data/QCL
2. Make these selections:
   - **Countries:** Sierra Leone
   - **Elements:** Yield
   - **Items:** Rice
   - **Years:** select all
3. Click **Download data**. Choose **CSV**, keep **Show Flags** ticked, and download.
4. Rename the file to `faostat_rice_yield_sle.csv` and put it here.

## WFP prices download

1. Go to https://data.humdata.org/dataset/wfp-food-prices-for-sierra-leone
2. Download the CSV file named like `wfp_food_prices_sle.csv`.
3. Make sure it is named `wfp_food_prices_sle.csv` and put it here.
