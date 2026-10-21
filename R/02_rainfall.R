# =====================================================================
# 02_rainfall.R  -  PART A
# Question: Has the rainy season in Bo District changed since 1981, in
# the ways farmers describe (later/false starts, longer dry spells,
# heavier rain and flooding)?
#
# Steps:
#   1. Turn 45 years of daily rain into yearly "rainfall indices".
#   2. Test each index for a trend (Mann-Kendall + Sen's slope).
#   3. Compare the last 10 years with the 1991-2020 normal.
#   4. Put that next to what farmers said in the 2026 survey.
# =====================================================================

source("R/00_setup.R")

rain <- read_csv("data/processed/rain_daily.csv", show_col_types = FALSE)


# ---------------------------------------------------------------------
# 1. Yearly rainfall indices for Bo and for Sierra Leone
# ---------------------------------------------------------------------
# "Very heavy rain" threshold: the 95th percentile of rainy days (>= 1 mm)
# in the baseline period, worked out separately for each region.
heavy_thresholds <- rain %>%
  filter(year(date) %in% BASELINE_YEARS, rain_mm >= 1) %>%
  group_by(region) %>%
  summarise(threshold = quantile(rain_mm, 0.95))
print(heavy_thresholds)

indices <- list()
for (reg in unique(rain$region)) {
  daily_reg <- filter(rain, region == reg)
  thr       <- heavy_thresholds$threshold[heavy_thresholds$region == reg]
  indices[[reg]] <- rainfall_indices(daily_reg, FIRST_YEAR:LAST_YEAR, thr) %>%
    mutate(region = reg, .before = 1)
}
indices <- bind_rows(indices)

# SPI for the May-October season (one value per year)
indices <- indices %>%
  group_by(region) %>%
  mutate(spi_season = spi_from_totals(season_total, year %in% BASELINE_YEARS)) %>%
  ungroup()

write_csv(indices, "output/tables/rainfall_indices_by_year.csv")
message("Years with no onset found: ",
        sum(is.na(indices$onset_doy[indices$region == "Bo"])), " (Bo)")


# ---------------------------------------------------------------------
# 2. Trend tests for Bo
# ---------------------------------------------------------------------
# A plain-language label for each index (used in tables and graphs)
index_labels <- c(
  onset_doy        = "Onset date (day of year)",
  cessation_doy    = "End of season (day of year)",
  season_length    = "Season length (days)",
  early_dry_spell  = "Longest dry spell after onset (days)",
  season_total     = "May-Oct rainfall (mm)",
  annual_total     = "Annual rainfall (mm)",
  rx5day           = "Wettest 5 days (mm)",
  heavy_days       = "Very heavy rain days (count)",
  heavy_rain_total = "Rain from very heavy days (mm)",
  spi_season       = "Seasonal SPI"
)

bo <- filter(indices, region == "Bo")

trend_results <- list()
for (index_name in names(index_labels)) {
  values <- bo[[index_name]]
  mk     <- mann_kendall(values)
  trend_results[[index_name]] <- tibble(
    index            = index_name,
    label            = index_labels[[index_name]],
    n_years          = mk$n,
    sen_slope_decade = sens_slope(values, bo$year) * 10,
    mk_z             = mk$z,
    p_value          = mk$p_value,
    baseline_mean    = mean(values[bo$year %in% BASELINE_YEARS], na.rm = TRUE),
    recent_mean      = mean(values[bo$year %in% RECENT_YEARS], na.rm = TRUE)
  )
}
trend_results <- bind_rows(trend_results) %>%
  mutate(
    recent_minus_baseline = recent_mean - baseline_mean,
    significant = p_value < 0.05
  )

print(trend_results, width = Inf)
write_csv(trend_results, "output/tables/rainfall_trends_bo.csv")


# ---------------------------------------------------------------------
# 3. FIGURE A1: the shape of the rainy season, then vs now
# ---------------------------------------------------------------------
climatology <- rain %>%
  filter(region == "Bo") %>%
  mutate(period = case_when(
    year(date) %in% BASELINE_YEARS ~ paste0("1991-2020 normal"),
    year(date) %in% RECENT_YEARS   ~ paste0("2016-2025"),
  )) %>%
  filter(!is.na(period), yday(date) <= 365) %>%
  group_by(period, doy = yday(date)) %>%
  summarise(mean_rain = mean(rain_mm), .groups = "drop") %>%
  group_by(period) %>%
  # smooth day-to-day noise with a 15-day moving average
  mutate(smooth_rain = zoo::rollmean(mean_rain, k = 15, fill = NA)) %>%
  ungroup()

month_breaks <- yday(as.Date(paste0("2001-", 1:12, "-01")))

fig_a1 <- ggplot(climatology, aes(doy, smooth_rain, colour = period)) +
  geom_line(linewidth = 0.8, na.rm = TRUE) +
  scale_colour_manual(values = c("1991-2020 normal" = COL_GREY, "2016-2025" = COL_BLUE)) +
  scale_x_continuous(breaks = month_breaks, labels = month.abb) +
  labs(
    title    = "The rainy season in Bo District",
    subtitle = "Average daily rainfall (15-day moving average), CHIRPS",
    x = NULL, y = "Rainfall (mm/day)",
    caption  = "Source: CHIRPS v2.0 daily, averaged over Bo District."
  ) +
  theme_project()
save_figure(fig_a1, "A1_season_shape.png", width = 8, height = 4)


# ---------------------------------------------------------------------
# 4. FIGURE A2: four key indices over time, with Sen's slope lines
# ---------------------------------------------------------------------
key_indices <- c("onset_doy", "early_dry_spell", "season_total", "rx5day")

plot_data <- bo %>%
  select(year, all_of(key_indices)) %>%
  pivot_longer(-year, names_to = "index", values_to = "value") %>%
  mutate(label = factor(index_labels[index], levels = index_labels[key_indices]))

# Sen's slope line for each panel: passes through the median point
slope_lines <- plot_data %>%
  group_by(index, label) %>%
  summarise(
    slope     = sens_slope(value, year),
    intercept = median(value, na.rm = TRUE) - slope * median(year[!is.na(value)]),
    .groups = "drop"
  ) %>%
  left_join(select(trend_results, index, p_value), by = "index") %>%
  mutate(note = paste0("Sen's slope: ", sprintf("%+.1f", slope * 10), " per decade",
                       "   p = ", sprintf("%.2f", p_value)))

fig_a2 <- ggplot(plot_data, aes(year, value)) +
  geom_line(colour = COL_GREY, linewidth = 0.4, na.rm = TRUE) +
  geom_point(colour = COL_BLUE, size = 1.4, na.rm = TRUE) +
  geom_abline(data = slope_lines, aes(slope = slope, intercept = intercept),
              colour = COL_ORANGE, linewidth = 0.8) +
  geom_text(data = slope_lines, aes(x = -Inf, y = Inf, label = note),
            hjust = -0.03, vjust = 1.4, size = 3, colour = COL_INK2) +
  facet_wrap(~ label, scales = "free_y", ncol = 2) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.25))) +
  labs(
    title    = "Has the rainy season in Bo changed since 1981?",
    subtitle = "Yearly rainfall indices (blue) with Sen's slope trend line (orange)",
    x = NULL, y = NULL,
    caption  = "Trend significance from the Mann-Kendall test. Source: CHIRPS v2.0."
  ) +
  theme_project()
save_figure(fig_a2, "A2_rainfall_trends.png", width = 9, height = 6)


# ---------------------------------------------------------------------
# 5. FIGURE A3: what farmers said vs what the satellite record shows
# ---------------------------------------------------------------------
# Survey results from the 2026 field survey (N = 50), Table 4 of the thesis.
survey <- tibble(
  answer = c("Yes, big changes\n(floods, longer dry season)", "Yes, some small changes",
             "No changes noticed", "Not sure"),
  percent = c(12, 48, 20, 20)
) %>% mutate(answer = factor(answer, levels = rev(answer)))

fig_a3_left <- ggplot(survey, aes(percent, answer)) +
  geom_col(fill = COL_BLUE, width = 0.6) +
  geom_text(aes(label = paste0(percent, "%")), hjust = -0.2, size = 3.3, colour = COL_INK) +
  scale_x_continuous(limits = c(0, 60), expand = c(0, 0)) +
  labs(title = "Farmers: noticed climate changes?",
       subtitle = "Field survey, Bo District, 2026 (N = 50)", x = "% of farmers", y = NULL) +
  theme_project()

# Recent decade vs the normal, in standard-deviation units so that all
# indices sit on one scale. (+1 = one "typical year-to-year swing" higher)
anomalies <- trend_results %>%
  filter(index %in% c(key_indices, "heavy_days", "season_length")) %>%
  rowwise() %>%
  mutate(sd_baseline = sd(bo[[index]][bo$year %in% BASELINE_YEARS], na.rm = TRUE),
         std_change  = recent_minus_baseline / sd_baseline) %>%
  ungroup() %>%
  mutate(direction = ifelse(std_change >= 0, "Higher / later", "Lower / earlier"),
         label = reorder(label, std_change))

fig_a3_right <- ggplot(anomalies, aes(std_change, label, fill = direction)) +
  geom_col(width = 0.6) +
  geom_vline(xintercept = 0, colour = COL_INK2, linewidth = 0.4) +
  scale_fill_manual(values = c("Higher / later" = COL_BLUE, "Lower / earlier" = COL_ORANGE)) +
  labs(title = "Satellite record: 2016-2025 vs 1991-2020",
       subtitle = "Change, in standard deviations",
       x = "Standardised change", y = NULL) +
  theme_project()

fig_a3 <- fig_a3_left + fig_a3_right + plot_layout(widths = c(1, 1.3))
save_figure(fig_a3, "A3_farmers_vs_satellite.png", width = 11, height = 4.2)

message("Part A done.")
