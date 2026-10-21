# =====================================================================
# 05_prices.R  -  PART D
# Question: How strongly do rice prices in Bo market rise and fall with
# the farming calendar, and are lean-season prices higher after a poor
# rainy season?
#
# Background (from the thesis): many farmers sell paddy straight after
# harvest, when prices are lowest, and buy rice back in the lean season,
# when prices are highest ("distress sales").
#
# Steps:
#   1. Remove inflation and long-term change with a 12-month moving
#      average, leaving the SEASONAL pattern.
#   2. Average the seasonal pattern by calendar month.
#   3. Compare each year's lean-season price rise with the previous
#      rainy season's rainfall.
# =====================================================================

source("R/00_setup.R")

prices  <- read_csv("data/processed/prices_monthly.csv", show_col_types = FALSE)
indices <- read_csv("output/tables/rainfall_indices_by_year.csv", show_col_types = FALSE)


# ---------------------------------------------------------------------
# 1. Seasonal index = price / centred 12-month moving average
# ---------------------------------------------------------------------
# Sierra Leone has had high inflation, so raw prices mostly go up.
# Dividing by a 12-month average around each month removes that.
# A value of 1.10 means "10% above the price level of that year".
prices <- prices %>%
  group_by(commodity) %>%
  # make sure every month exists, so the moving average lines up
  complete(date = seq(min(date), max(date), by = "month")) %>%
  arrange(date, .by_group = TRUE) %>%
  mutate(
    # centred "2 x 12" moving average: the standard way to centre a
    # 12-month window on a month
    ma12  = zoo::rollmean(price_sle, k = 12, fill = NA, align = "center"),
    ma2x12 = zoo::rollmean(ma12, k = 2, fill = NA, align = "right"),
    seasonal_index = price_sle / ma2x12
  ) %>%
  ungroup() %>%
  mutate(month = month(date), year = year(date))

write_csv(prices, "output/tables/prices_with_seasonal_index.csv")


# ---------------------------------------------------------------------
# 2. FIGURE D1: price series and the seasonal cycle
# ---------------------------------------------------------------------
commodity_colours <- setNames(c(COL_BLUE, COL_ORANGE, COL_AQUA)[seq_along(unique(prices$commodity))],
                              sort(unique(prices$commodity)))

fig_d1_top <- ggplot(filter(prices, !is.na(price_sle)), aes(date, price_sle, colour = commodity)) +
  geom_line(linewidth = 0.6) +
  scale_colour_manual(values = commodity_colours) +
  scale_y_log10(labels = scales::label_number(accuracy = 0.1)) +
  labs(title = "Retail rice prices in Bo market",
       subtitle = "New Leones (SLE) per kg, log scale (pre-2022 prices converted from old Leones)",
       x = NULL, y = "SLE per kg (log scale)") +
  theme_project()

monthly_pattern <- prices %>%
  filter(!is.na(seasonal_index)) %>%
  group_by(commodity, month) %>%
  summarise(
    mean_index = mean(seasonal_index),
    se         = sd(seasonal_index) / sqrt(n()),
    n_years    = n(),
    .groups = "drop"
  )
write_csv(monthly_pattern, "output/tables/price_seasonal_pattern.csv")

fig_d1_bottom <- ggplot(monthly_pattern, aes(month, (mean_index - 1) * 100, colour = commodity)) +
  annotate("rect", xmin = 6.5, xmax = 9.5, ymin = -Inf, ymax = Inf, fill = COL_ORANGE, alpha = 0.08) +
  annotate("rect", xmin = 9.5, xmax = 12.5, ymin = -Inf, ymax = Inf, fill = COL_AQUA, alpha = 0.08) +
  annotate("text", x = 8, y = Inf, label = "Lean season", vjust = 1.5, size = 3, colour = COL_INK2) +
  annotate("text", x = 11, y = Inf, label = "Harvest", vjust = 1.5, size = 3, colour = COL_INK2) +
  geom_hline(yintercept = 0, colour = COL_INK2, linewidth = 0.3) +
  geom_errorbar(aes(ymin = (mean_index - 1.96 * se - 1) * 100,
                    ymax = (mean_index + 1.96 * se - 1) * 100),
                width = 0.2, linewidth = 0.4, position = position_dodge(width = 0.4)) +
  geom_line(linewidth = 0.8, position = position_dodge(width = 0.4)) +
  geom_point(size = 2, position = position_dodge(width = 0.4)) +
  scale_colour_manual(values = commodity_colours) +
  scale_x_continuous(breaks = 1:12, labels = month.abb) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.25))) +
  labs(subtitle = "Typical seasonal pattern: % above or below the 12-month average (with 95% interval)",
       x = NULL, y = "% vs 12-month average",
       caption = "Source: WFP Market Monitoring via the Humanitarian Data Exchange (HDX).") +
  theme_project()

# Same colours in both panels, so one legend (on the top panel) is enough
fig_d1 <- fig_d1_top / (fig_d1_bottom + theme(legend.position = "none"))
save_figure(fig_d1, "D1_rice_prices.png", width = 9, height = 7)


# ---------------------------------------------------------------------
# 3. Lean-season price rise vs the previous season's rainfall
# ---------------------------------------------------------------------
# Lean-season premium for year Y = average seasonal index in Jul-Sep of
# year Y, minus the average in the harvest months (Oct-Dec) just before.
# The harvest that fed that lean season came from the rains of year Y-1.
# We use locally grown rice, because imported rice prices follow world
# markets more than Sierra Leone's own harvest.
local_rice <- filter(prices, str_detect(commodity, regex("local", ignore_case = TRUE)))
if (nrow(local_rice) == 0) {
  message("No 'local' rice series found - using the first rice series instead.")
  local_rice <- filter(prices, commodity == sort(unique(prices$commodity))[1])
}

premium <- local_rice %>%
  filter(!is.na(seasonal_index)) %>%
  mutate(
    # Oct-Dec of year Y-1 is the harvest that comes before lean season Y
    lean_year = ifelse(month %in% 10:12, year + 1, year),
    phase = case_when(month %in% 10:12 ~ "harvest",
                      month %in% 7:9   ~ "lean")
  ) %>%
  filter(!is.na(phase)) %>%
  group_by(lean_year, phase) %>%
  summarise(index = mean(seasonal_index), .groups = "drop") %>%
  pivot_wider(names_from = phase, values_from = index) %>%
  filter(!is.na(harvest), !is.na(lean)) %>%
  mutate(premium_pct = 100 * (lean - harvest),
         rain_year = lean_year - 1)

premium_rain <- premium %>%
  inner_join(filter(indices, region == "Bo"), by = c("rain_year" = "year"))

write_csv(premium_rain, "output/tables/lean_season_premium.csv")

if (nrow(premium_rain) >= 5) {
  test_total <- cor.test(premium_rain$premium_pct, premium_rain$season_total,
                         method = "spearman", exact = FALSE)
  test_dry   <- cor.test(premium_rain$premium_pct, premium_rain$early_dry_spell,
                         method = "spearman", exact = FALSE)
  price_tests <- tibble(
    rain_index   = c("May-Oct rainfall (previous year)", "Dry spell after onset (previous year)"),
    n_years      = nrow(premium_rain),
    spearman_rho = c(test_total$estimate, test_dry$estimate),
    p_value      = c(test_total$p.value, test_dry$p.value)
  )
  print(price_tests)
  write_csv(price_tests, "output/tables/price_rainfall_tests.csv")

  fig_d2 <- ggplot(premium_rain, aes(season_total, premium_pct)) +
    geom_hline(yintercept = 0, colour = COL_INK2, linewidth = 0.3) +
    geom_smooth(method = "lm", formula = y ~ x, colour = COL_ORANGE, fill = COL_ORANGE,
                alpha = 0.12, linewidth = 0.7) +
    geom_point(colour = COL_BLUE, size = 2.2) +
    geom_text(aes(label = lean_year), vjust = -0.9, size = 2.7, colour = COL_INK2) +
    labs(title = "Do poor rainy seasons lead to a bigger lean-season price rise?",
         subtitle = sprintf("Local rice, Bo market. Spearman rho = %.2f, p = %.2f, n = %d years",
                            test_total$estimate, test_total$p.value, nrow(premium_rain)),
         x = "May-Oct rainfall in Bo the year before (mm)",
         y = "Lean-season rise vs harvest (% points)",
         caption = "Sources: WFP / HDX prices; CHIRPS v2.0 rainfall.") +
    theme_project()
  save_figure(fig_d2, "D2_price_vs_rainfall.png", width = 8, height = 5)
} else {
  message("Fewer than 5 years with both harvest and lean-season prices - skipping the test.")
}

message("Part D done.")
