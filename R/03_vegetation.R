# =====================================================================
# 03_vegetation.R  -  PART B
# Question: Do rainfall problems show up in how green Bo's farmland is?
#
# NDVI (Normalised Difference Vegetation Index) measures greenness from
# space: about 0.2 for bare soil, 0.8+ for dense healthy vegetation.
#
# Steps:
#   1. Show the typical greenness cycle over the year, and how clouds
#      hide the land in the wet season.
#   2. Work out late-season greenness (Oct-Dec, around rice harvest)
#      for every year 2000-2025.
#   3. Check whether low-greenness years follow bad rainfall years.
#   4. Map greenness across the district.
# =====================================================================

source("R/00_setup.R")

ndvi    <- read_csv("data/processed/ndvi_16day.csv", show_col_types = FALSE)
indices <- read_csv("output/tables/rainfall_indices_by_year.csv", show_col_types = FALSE)

month_breaks <- yday(as.Date(paste0("2001-", 1:12, "-01")))


# ---------------------------------------------------------------------
# 1. FIGURE B1: the greenness cycle, and the cloud problem
# ---------------------------------------------------------------------
cycle <- ndvi %>%
  group_by(doy) %>%
  summarise(
    median_ndvi = median(ndvi[usable], na.rm = TRUE),
    low_ndvi    = quantile(ndvi[usable], 0.25, na.rm = TRUE),
    high_ndvi   = quantile(ndvi[usable], 0.75, na.rm = TRUE),
    share_usable = mean(usable),
    .groups = "drop"
  )

fig_b1_top <- ggplot(cycle, aes(doy)) +
  geom_ribbon(aes(ymin = low_ndvi, ymax = high_ndvi), fill = COL_AQUA, alpha = 0.25,
              na.rm = TRUE) +
  geom_line(aes(y = median_ndvi), colour = COL_AQUA, linewidth = 0.9, na.rm = TRUE) +
  scale_x_continuous(breaks = month_breaks, labels = month.abb) +
  labs(title = "Farmland greenness through the year, Bo District (2000-2025)",
       subtitle = "Median NDVI (line) and middle 50% of years (band), cloud-free images only",
       x = NULL, y = "NDVI") +
  theme_project()

fig_b1_bottom <- ggplot(cycle, aes(doy, share_usable * 100)) +
  geom_col(fill = COL_GREY, width = 12) +
  scale_x_continuous(breaks = month_breaks, labels = month.abb) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(subtitle = "% of years in which the image was usable (at least 30% of farmland cloud-free)",
       x = NULL, y = "% usable",
       caption = "Source: MODIS MOD13Q1 (250 m, 16-day), farmland mask from ESA WorldCover 2021.") +
  theme_project()

fig_b1 <- fig_b1_top / fig_b1_bottom + plot_layout(heights = c(2, 1))
save_figure(fig_b1, "B1_greenness_cycle.png", width = 8, height = 6)


# ---------------------------------------------------------------------
# 2. Late-season greenness for each year
# ---------------------------------------------------------------------
late_season <- ndvi %>%
  filter(usable, month(date) %in% 10:12) %>%
  group_by(year) %>%
  summarise(late_ndvi = mean(ndvi), late_evi = mean(evi),
            n_images = n(), .groups = "drop") %>%
  filter(n_images >= 2) %>%                 # need at least 2 clear images
  mutate(ndvi_anomaly = late_ndvi - mean(late_ndvi))

write_csv(late_season, "output/tables/late_season_ndvi.csv")


# ---------------------------------------------------------------------
# 3. Does greenness follow rainfall?
# ---------------------------------------------------------------------
veg_rain <- late_season %>%
  inner_join(filter(indices, region == "Bo"), by = "year")

rain_vars <- c(
  season_total    = "May-Oct rainfall (mm)",
  onset_doy       = "Onset date (day of year)",
  early_dry_spell = "Longest dry spell after onset (days)",
  rx5day          = "Wettest 5 days (mm)"
)

correlations <- list()
for (v in names(rain_vars)) {
  ok <- !is.na(veg_rain[[v]])
  pearson  <- cor.test(veg_rain$late_ndvi[ok], veg_rain[[v]][ok], method = "pearson")
  spearman <- cor.test(veg_rain$late_ndvi[ok], veg_rain[[v]][ok], method = "spearman",
                       exact = FALSE)
  correlations[[v]] <- tibble(
    rain_index = rain_vars[[v]],
    n_years    = sum(ok),
    pearson_r  = unname(pearson$estimate),
    pearson_p  = pearson$p.value,
    spearman_rho = unname(spearman$estimate),
    spearman_p   = spearman$p.value
  )
}
correlations <- bind_rows(correlations)
print(correlations, width = Inf)
write_csv(correlations, "output/tables/ndvi_rainfall_correlations.csv")

# FIGURE B2: scatter plots
scatter_data <- veg_rain %>%
  select(year, late_ndvi, all_of(names(rain_vars))) %>%
  pivot_longer(all_of(names(rain_vars)), names_to = "index", values_to = "value") %>%
  left_join(tibble(index = names(rain_vars), label = rain_vars), by = "index") %>%
  left_join(correlations, by = c("label" = "rain_index")) %>%
  mutate(label = factor(label, levels = rain_vars))

panel_notes <- scatter_data %>%
  distinct(label, spearman_rho, spearman_p) %>%
  mutate(note = sprintf("Spearman rho = %.2f, p = %.2f", spearman_rho, spearman_p))

fig_b2 <- ggplot(scatter_data, aes(value, late_ndvi)) +
  geom_smooth(method = "lm", formula = y ~ x, se = TRUE, colour = COL_ORANGE,
              fill = COL_ORANGE, alpha = 0.12, linewidth = 0.7, na.rm = TRUE) +
  geom_point(colour = COL_AQUA, size = 2, na.rm = TRUE) +
  geom_text(data = panel_notes, aes(x = -Inf, y = Inf, label = note),
            hjust = -0.05, vjust = 1.5, size = 3, colour = COL_INK2) +
  facet_wrap(~ label, scales = "free_x", ncol = 2) +
  scale_y_continuous(expand = expansion(mult = c(0.05, 0.2))) +
  labs(title = "Is late-season greenness linked to that year's rainfall?",
       subtitle = "Each point is one year (2000-2025). Mean NDVI of Bo farmland, Oct-Dec",
       x = NULL, y = "Late-season NDVI",
       caption = "Sources: MODIS MOD13Q1; CHIRPS v2.0.") +
  theme_project()
save_figure(fig_b2, "B2_greenness_vs_rainfall.png", width = 9, height = 6)


# ---------------------------------------------------------------------
# 4. FIGURE B3: maps
# ---------------------------------------------------------------------
districts <- st_read(data_file("districts_sle.geojson"), quiet = TRUE)
bo_shape  <- st_read(data_file("boundary_bo.geojson"), quiet = TRUE)
ndvi_map  <- terra::rast(data_file("ndvi_bo_lateseason.tif"))
names(ndvi_map) <- c("ndvi", "farm_fraction")

# Turn the raster into a table of pixels so ggplot can draw it
ndvi_pixels <- as.data.frame(ndvi_map, xy = TRUE, na.rm = TRUE)

map_location <- ggplot() +
  geom_sf(data = districts, fill = "#f1f0ec", colour = "white", linewidth = 0.3) +
  geom_sf(data = bo_shape, fill = COL_BLUE, colour = COL_BLUE) +
  labs(title = "Location", subtitle = "Bo District, Sierra Leone") +
  theme_void() +
  theme(plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(colour = COL_INK2))

map_ndvi <- ggplot() +
  geom_raster(data = ndvi_pixels, aes(x, y, fill = ndvi)) +
  geom_sf(data = bo_shape, fill = NA, colour = COL_INK, linewidth = 0.4) +
  scale_fill_gradient(low = "#f3ecd9", high = "#1f6b2a", name = "NDVI",
                      limits = c(0.3, 0.9), oob = scales::squish) +
  labs(title = "Late-season greenness",
       subtitle = "Median NDVI, Oct-Dec 2015-2025 (250 m)",
       caption = "Source: MODIS MOD13Q1 via Google Earth Engine; boundaries FAO GAUL.") +
  theme_void() +
  theme(plot.title = element_text(face = "bold"),
        plot.subtitle = element_text(colour = COL_INK2),
        plot.caption = element_text(colour = COL_INK2, size = 8, hjust = 0),
        legend.position = "right")

fig_b3 <- map_location + map_ndvi + plot_layout(widths = c(1, 1.6))
save_figure(fig_b3, "B3_maps.png", width = 10, height = 5)

message("Part B done.")
