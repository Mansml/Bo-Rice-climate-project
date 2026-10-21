# =====================================================================
# make_example_data.R
# Creates MADE-UP data files with exactly the same layout as the real
# ones, saved in data/example/. They exist only so the code can be run
# and tested before the real data are downloaded.
#
#   !!! Never report results from these files. They are random numbers. !!!
# =====================================================================

library(dplyr)
library(readr)
library(lubridate)

set.seed(2026)
dir.create("data/example", recursive = TRUE, showWarnings = FALSE)

# ---- 1. Daily rainfall (like CHIRPS) --------------------------------
dates <- seq(as.Date("1981-01-01"), as.Date("2025-12-31"), by = "day")
doy   <- yday(dates)

make_rain <- function(scale_factor) {
  # chance of rain and typical amount follow a single wet season (peak ~Aug)
  wetness  <- pmax(0, cos(2 * pi * (doy - 225) / 365))
  p_rain   <- 0.05 + 0.85 * wetness
  amount   <- rgamma(length(dates), shape = 0.9, scale = 3 + 22 * wetness)
  rain     <- ifelse(runif(length(dates)) < p_rain, amount, 0)
  round(rain * scale_factor, 2)
}

rain <- bind_rows(
  tibble(date = format(dates), region = "Bo",           rain_mm = make_rain(1.00)),
  tibble(date = format(dates), region = "Sierra Leone", rain_mm = make_rain(1.05))
)
write_csv(rain, "data/example/chirps_daily_bo_sle.csv")

# ---- 2. Vegetation index (like MODIS MOD13Q1) -----------------------
modis_dates <- unlist(lapply(2000:2025, function(y) {
  format(as.Date(paste0(y, "-01-01")) + seq(0, 352, by = 16))
}))
modis_dates <- modis_dates[as.Date(modis_dates) >= as.Date("2000-02-18")]
m_doy   <- yday(as.Date(modis_dates))
season  <- cos(2 * pi * (m_doy - 290) / 365)          # greenest ~October
cloudy  <- pmax(0, cos(2 * pi * (m_doy - 215) / 365))  # cloudiest ~August
n_farm  <- 2400L

ndvi <- tibble(
  date          = modis_dates,
  ndvi          = round(0.62 + 0.12 * season + rnorm(length(m_doy), 0, 0.03), 4),
  evi           = round(0.38 + 0.08 * season + rnorm(length(m_doy), 0, 0.02), 4),
  n_good_pixels = as.integer(round(n_farm * pmin(1, pmax(0.02, 0.9 - 0.85 * cloudy +
                                               rnorm(length(m_doy), 0, 0.08))))),
  n_farm_pixels = n_farm
)
write_csv(ndvi, "data/example/modis_ndvi_bo_cropland.csv")

# ---- 3. National rice yield (like a FAOSTAT download) ---------------
years <- 1981:2023
trend <- 1.25 + 0.006 * (years - 1981) - 0.25 * (years %in% 1991:2002)
yield_t_ha <- trend + rnorm(length(years), 0, 0.08)
faostat <- tibble(
  `Domain Code` = "QCL", Domain = "Crops and livestock products",
  `Area Code (M49)` = "694", Area = "Sierra Leone",
  `Element Code` = "5412", Element = "Yield",
  `Item Code (CPC)` = "0113", Item = "Rice",
  `Year Code` = years, Year = years, Unit = "kg/ha",
  Value = round(yield_t_ha * 1000),
  Flag = ifelse(years %in% 1991:2002, "E", "A"),
  `Flag Description` = ifelse(years %in% 1991:2002, "Estimated value", "Official figure"),
  Note = ""
)
write_csv(faostat, "data/example/faostat_rice_yield_sle.csv")

# ---- 4. Market prices (like the WFP file on HDX) --------------------
months <- seq(as.Date("2008-01-15"), as.Date("2025-06-15"), by = "month")
inflation <- cumprod(rep(1.008, length(months)))           # ~10% a year
seasonal  <- 1 + 0.07 * cos(2 * pi * (month(months) - 8) / 12)  # peak ~Aug
make_price <- function(base) base * inflation * seasonal * exp(rnorm(length(months), 0, 0.04))

prices <- bind_rows(
  tibble(date = format(months), commodity = "Rice (local)",    price_sll = make_price(4500)),
  tibble(date = format(months), commodity = "Rice (imported)", price_sll = make_price(4000))
) %>%
  mutate(
    # Sierra Leone re-denominated in 2022: 1 new Leone (SLE) = 1000 old (SLL)
    currency = ifelse(as.Date(date) >= as.Date("2022-07-01"), "SLE", "SLL"),
    price    = round(ifelse(currency == "SLE", price_sll / 1000, price_sll), 2),
    admin1 = "Southern", admin2 = "Bo", market = "Bo", market_id = "1",
    latitude = "7.96", longitude = "-11.74", category = "cereals and tubers",
    commodity_id = "1", unit = "KG", priceflag = "actual", pricetype = "Retail",
    usdprice = round(price_sll / 9000, 2)
  ) %>%
  select(date, admin1, admin2, market, market_id, latitude, longitude, category,
         commodity, commodity_id, unit, priceflag, pricetype, currency, price, usdprice) %>%
  mutate(across(everything(), as.character))

# The real HDX file has a second header row of "HXL tags" starting with #
hxl_tags <- c("#date", "#adm1+name", "#adm2+name", "#loc+market+name",
  "#loc+market+code", "#geo+lat", "#geo+lon", "#item+type", "#item+name", "#item+code",
  "#item+unit", "#item+price+flag", "#item+price+type", "#currency", "#value",
  "#value+usd")
hxl_row <- as_tibble(as.list(setNames(hxl_tags, names(prices))))
write_csv(bind_rows(hxl_row, prices), "data/example/wfp_food_prices_sle.csv")

# ---- 5. Boundaries and a small raster (for the maps) ----------------
library(sf)
square <- function(xmin, xmax, ymin, ymax) {
  st_polygon(list(rbind(c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
                        c(xmin, ymax), c(xmin, ymin))))
}
districts <- st_sf(
  ADM1_NAME = c("Southern", "Example region", "Example region"),
  ADM2_NAME = c("Bo", "Example district A", "Example district B"),
  geometry  = st_sfc(square(-12.3, -11.4, 7.5, 8.3),
                     square(-13.3, -12.3, 7.0, 9.9),
                     square(-11.4, -10.3, 7.0, 9.9), crs = 4326)
)
st_write(districts, "data/example/districts_sle.geojson", delete_dsn = TRUE, quiet = TRUE)
st_write(districts[1, "ADM2_NAME"], "data/example/boundary_bo.geojson",
         delete_dsn = TRUE, quiet = TRUE)

r <- terra::rast(xmin = -12.3, xmax = -11.4, ymin = 7.5, ymax = 8.3,
                 resolution = 0.00225, crs = "EPSG:4326", nlyrs = 2)
xy <- terra::crds(r, na.rm = FALSE)
terra::values(r) <- cbind(
  0.6 + 0.15 * sin(xy[, 1] * 9) * cos(xy[, 2] * 7) + rnorm(nrow(xy), 0, 0.03),
  pmin(1, pmax(0, 0.4 + 0.4 * sin(xy[, 1] * 15) + rnorm(nrow(xy), 0, 0.1)))
)
names(r) <- c("ndvi", "farm_fraction")
terra::writeRaster(r, "data/example/ndvi_bo_lateseason.tif", overwrite = TRUE)

message("Example (made-up) data written to data/example/")
