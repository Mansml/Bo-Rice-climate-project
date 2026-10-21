# =====================================================================
# functions.R
# Small home-made functions used by the analysis scripts.
# Each one does ONE job and is explained in plain words.
# =====================================================================


# ---------------------------------------------------------------------
# longest_dry_spell()
# The longest run of consecutive "dry" days in a vector of daily rain.
# A day is dry if rain is below 1 mm (a common convention).
# Example: c(0, 0, 5, 0, 0, 0, 2) -> 3
# ---------------------------------------------------------------------
longest_dry_spell <- function(rain, dry_threshold = 1) {
  is_dry <- rain < dry_threshold
  if (!any(is_dry, na.rm = TRUE)) return(0)
  runs <- rle(is_dry)                   # rle = "run length encoding"
  max(runs$lengths[runs$values], na.rm = TRUE)
}


# ---------------------------------------------------------------------
# find_onset()
# Agronomic onset of the rainy season (a widely used West African rule,
# after Sivakumar 1988). Searching from 1 April, onset is the FIRST day
# where:
#   (a) the next 3 days bring at least 20 mm, on at least 2 rainy days, and
#   (b) no dry spell of 7+ days follows in the next 30 days
#       (otherwise a farmer who planted would lose the seedlings:
#        a "false start").
# Returns the position (row number) of the onset day, or NA.
# ---------------------------------------------------------------------
find_onset <- function(rain, dates, year) {
  start <- which(dates == as.Date(paste0(year, "-04-01")))
  end   <- which(dates == as.Date(paste0(year, "-08-31")))
  if (length(start) == 0 || length(end) == 0) return(NA)

  for (i in start:end) {
    next_3_days <- rain[i:(i + 2)]
    if (sum(next_3_days) >= 20 && sum(next_3_days >= 1) >= 2) {
      next_30_days <- rain[(i + 3):(i + 32)]
      if (longest_dry_spell(next_30_days) < 7) {
        return(i)
      }
    }
  }
  NA
}


# ---------------------------------------------------------------------
# find_cessation()
# End of the rainy season. Searching from 1 September, cessation is the
# first day after which the next 20 days bring less than 10 mm in total.
# Returns the position (row number) of the cessation day, or NA.
# ---------------------------------------------------------------------
find_cessation <- function(rain, dates, year) {
  start <- which(dates == as.Date(paste0(year, "-09-01")))
  end   <- which(dates == as.Date(paste0(year, "-12-31")))
  if (length(start) == 0 || length(end) == 0) return(NA)

  for (i in start:end) {
    if (i + 19 > length(rain)) return(NA)   # ran out of data
    if (sum(rain[i:(i + 19)]) < 10) {
      return(i)
    }
  }
  NA
}


# ---------------------------------------------------------------------
# rainfall_indices()
# Takes daily rain for ONE region (columns: date, rain_mm) and returns a
# table with one row per year and one column per rainfall index.
# heavy_threshold = the rain amount (mm/day) that counts as "very heavy";
# we set it as the 95th percentile of rainy days in the baseline period.
# ---------------------------------------------------------------------
rainfall_indices <- function(daily, years, heavy_threshold) {
  daily <- arrange(daily, date)
  rain  <- daily$rain_mm
  dates <- daily$date

  results <- list()
  for (yr in years) {
    in_year   <- year(dates) == yr
    in_season <- in_year & month(dates) %in% 5:10       # May-October

    onset_i     <- find_onset(rain, dates, yr)
    cessation_i <- find_cessation(rain, dates, yr)

    # Longest dry spell in the 40 days after onset: the crop
    # establishment period, when seedlings are most vulnerable.
    early_dry <- if (is.na(onset_i)) NA else
      longest_dry_spell(rain[onset_i:(onset_i + 39)])

    # Rx5day: the wettest 5-day period of the year (a flood indicator)
    rain_year <- rain[in_year]
    rx5day    <- max(zoo::rollsum(rain_year, k = 5), na.rm = TRUE)

    results[[as.character(yr)]] <- tibble(
      year            = yr,
      annual_total    = sum(rain_year),
      season_total    = sum(rain[in_season]),
      onset_doy       = if (is.na(onset_i)) NA else yday(dates[onset_i]),
      cessation_doy   = if (is.na(cessation_i)) NA else yday(dates[cessation_i]),
      early_dry_spell = early_dry,
      rx5day          = rx5day,
      heavy_days      = sum(rain_year > heavy_threshold),
      heavy_rain_total = sum(rain_year[rain_year > heavy_threshold])
    )
  }
  out <- bind_rows(results)
  out$season_length <- out$cessation_doy - out$onset_doy
  out
}


# ---------------------------------------------------------------------
# spi_from_totals()
# Standardised Precipitation Index (McKee et al. 1993) for seasonal totals.
# Idea: fit a gamma distribution to the baseline years, then ask "how
# unusual is each year?" and express the answer on a standard normal scale.
#   SPI around 0  = normal season
#   SPI <= -1     = moderately dry,  SPI <= -1.5 = severely dry
#   SPI >= +1     = moderately wet
# The gamma parameters use Thom's (1958) approximation, the standard
# method in SPI software.
# ---------------------------------------------------------------------
spi_from_totals <- function(totals, is_baseline) {
  base <- totals[is_baseline & !is.na(totals) & totals > 0]
  A     <- log(mean(base)) - mean(log(base))
  shape <- (1 + sqrt(1 + 4 * A / 3)) / (4 * A)
  scale <- mean(base) / shape
  qnorm(pgamma(totals, shape = shape, scale = scale))
}


# ---------------------------------------------------------------------
# mann_kendall()
# Mann-Kendall trend test: is there a steady upward or downward trend?
# It compares every pair of years and counts how often the later value
# is higher (+1) or lower (-1). It makes no assumption about the shape
# of the data, which suits rainfall. Returns S, z and a two-sided p-value.
# (Gives the same result as trend::mk.test().)
# ---------------------------------------------------------------------
mann_kendall <- function(x) {
  x <- x[!is.na(x)]
  n <- length(x)
  differences <- outer(x, x, "-")              # every x[j] - x[i]
  S <- sum(sign(differences[lower.tri(differences)]))

  tie_sizes <- as.numeric(table(x))
  var_S <- (n * (n - 1) * (2 * n + 5) -
            sum(tie_sizes * (tie_sizes - 1) * (2 * tie_sizes + 5))) / 18

  z <- if (S > 0) (S - 1) / sqrt(var_S) else if (S < 0) (S + 1) / sqrt(var_S) else 0
  p <- 2 * (1 - pnorm(abs(z)))
  list(S = S, z = z, p_value = p, n = n)
}


# ---------------------------------------------------------------------
# sens_slope()
# Sen's slope: the typical change per year. It is the MEDIAN of the
# slopes between every pair of years, so one extreme year cannot drag
# it around (unlike an ordinary regression line).
# (Gives the same result as trend::sens.slope().)
# ---------------------------------------------------------------------
sens_slope <- function(y, t) {
  keep <- !is.na(y) & !is.na(t)
  y <- y[keep]
  t <- t[keep]
  dy <- outer(y, y, "-")
  dt <- outer(t, t, "-")
  slopes <- dy[lower.tri(dy)] / dt[lower.tri(dt)]
  median(slopes)
}
