# =====================================================================
# 01_load_clean.R
# Reads the four raw datasets, checks them, cleans them, and saves tidy
# versions in data/processed/. Every later script reads ONLY from
# data/processed/, so this is the single place where cleaning happens.
# =====================================================================

source("R/00_setup.R")


# =====================================================================
# 1. Daily rainfall (CHIRPS)
# =====================================================================
rain_raw <- read_csv(data_file("chirps_daily_bo_sle.csv"), show_col_types = FALSE)

rain <- rain_raw %>%
  mutate(date = as.Date(date), rain_mm = as.numeric(rain_mm)) %>%
  filter(year(date) >= FIRST_YEAR, year(date) <= LAST_YEAR) %>%
  arrange(region, date)

# --- Checks ------------------------------------------------------------
# (a) Are there any duplicated days?
n_duplicates <- sum(duplicated(rain[, c("region", "date")]))
message("Duplicated region-days: ", n_duplicates)
rain <- distinct(rain, region, date, .keep_all = TRUE)

# (b) Are any days missing? Build the full calendar and compare.
full_calendar <- expand_grid(
  region = unique(rain$region),
  date   = seq(as.Date(paste0(FIRST_YEAR, "-01-01")),
               as.Date(paste0(LAST_YEAR, "-12-31")), by = "day")
)
rain <- full_calendar %>% left_join(rain, by = c("region", "date"))
message("Missing days: ", sum(is.na(rain$rain_mm)))

# (c) Negative rainfall is impossible -> treat as missing.
rain$rain_mm[rain$rain_mm < 0] <- NA

# CHIRPS has essentially no gaps. If a few days are missing, we fill them
# with 0 and say so; if many are missing, stop and investigate.
if (mean(is.na(rain$rain_mm)) > 0.01) {
  stop("More than 1% of rainfall days are missing - check the CHIRPS export.")
}
rain$rain_mm[is.na(rain$rain_mm)] <- 0

write_csv(rain, "data/processed/rain_daily.csv")


# =====================================================================
# 2. Vegetation index (MODIS NDVI / EVI over farmland in Bo)
# =====================================================================
ndvi_raw <- read_csv(data_file("modis_ndvi_bo_cropland.csv"), show_col_types = FALSE)

ndvi <- ndvi_raw %>%
  mutate(
    date          = as.Date(date),
    year          = year(date),
    doy           = yday(date),
    # What share of farmland pixels were cloud-free in this 16-day image?
    share_clear   = n_good_pixels / n_farm_pixels,
    # We only trust an image if at least 30% of farmland was clear.
    usable        = !is.na(ndvi) & share_clear >= 0.30
  ) %>%
  arrange(date)

message("MODIS images: ", nrow(ndvi), " | usable (>=30% clear): ", sum(ndvi$usable))
write_csv(ndvi, "data/processed/ndvi_16day.csv")


# =====================================================================
# 3. National rice yield (FAOSTAT)
# =====================================================================
yield_raw <- read_csv(data_file("faostat_rice_yield_sle.csv"), show_col_types = FALSE)

yield <- yield_raw %>%
  filter(Element == "Yield", str_detect(Item, regex("rice", ignore_case = TRUE))) %>%
  mutate(
    # FAOSTAT has reported yield in hg/ha (older files) or kg/ha (newer).
    # We convert both to tonnes per hectare.
    yield_t_ha = case_when(
      Unit == "kg/ha" ~ Value / 1000,
      Unit == "hg/ha" ~ Value / 10000,
      Unit == "t/ha"  ~ Value
    ),
    official = is.na(Flag) | Flag %in% c("A", "")   # A or blank = official figure
  ) %>%
  select(year = Year, yield_t_ha, flag = Flag, flag_description = `Flag Description`, official) %>%
  filter(!is.na(yield_t_ha)) %>%
  arrange(year)

message("Yield years: ", min(yield$year), "-", max(yield$year),
        " | official figures: ", sum(yield$official), " of ", nrow(yield))
write_csv(yield, "data/processed/yield_national.csv")


# =====================================================================
# 4. Rice prices (WFP market monitoring, from HDX)
# =====================================================================
MARKET <- "Bo"   # change if you want another market

prices_raw <- read_csv(data_file("wfp_food_prices_sle.csv"),
                       col_types = cols(.default = col_character()))

# The HDX file has an extra row of "#tags" under the header. Remove it.
prices_raw <- filter(prices_raw, !str_starts(date, "#"))

message("Markets available: ", paste(sort(unique(prices_raw$market)), collapse = ", "))
message("Rice items available: ",
        paste(unique(prices_raw$commodity[str_detect(prices_raw$commodity,
                                                     regex("rice", ignore_case = TRUE))]),
              collapse = ", "))

prices <- prices_raw %>%
  filter(market == MARKET,
         str_detect(commodity, regex("rice", ignore_case = TRUE)),
         pricetype == "Retail",
         str_to_upper(unit) == "KG") %>%
  mutate(
    date  = as.Date(date),
    price = as.numeric(price),
    # 2022 re-denomination: 1 new Leone (SLE) = 1000 old Leones (SLL).
    # Put everything in new Leones so the series is continuous.
    price_sle = if_else(currency == "SLL", price / 1000, price),
    month_start = floor_date(date, "month")
  ) %>%
  group_by(commodity, month_start) %>%                # one value per month
  summarise(price_sle = mean(price_sle, na.rm = TRUE), .groups = "drop") %>%
  rename(date = month_start) %>%
  arrange(commodity, date)

if (nrow(prices) == 0) stop("No rice prices found for market '", MARKET, "'.")
message("Price series: ", paste(unique(prices$commodity), collapse = ", "),
        " | months: ", n_distinct(prices$date))
write_csv(prices, "data/processed/prices_monthly.csv")

message("Done: cleaned data saved in data/processed/")
