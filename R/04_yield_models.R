# =====================================================================
# 04_yield_models.R  -  PART C
# Question: Can seasonal rainfall explain year-to-year ups and downs in
# Sierra Leone's rice yield? And does a machine-learning model (random
# forest) do better than a simple linear regression?
#
# Steps:
#   1. Remove the long-term trend from yields, so we model only the
#      year-to-year "anomalies" that weather could plausibly cause.
#   2. Join the national rainfall indices for the same year.
#   3. Compare three models with leave-one-year-out cross-validation:
#        - a "no-skill" baseline (always predicts the average)
#        - linear regression
#        - random forest
#   4. Repeat for 2003 onwards only (after the civil war), as a check.
# =====================================================================

source("R/00_setup.R")

yield   <- read_csv("data/processed/yield_national.csv", show_col_types = FALSE)
indices <- read_csv("output/tables/rainfall_indices_by_year.csv", show_col_types = FALSE)


# ---------------------------------------------------------------------
# 1. Remove the trend
# ---------------------------------------------------------------------
# Yields change slowly because of technology, policy and the 1991-2002
# civil war. A LOESS curve (a flexible smooth line) captures that slow
# change. What is left over - the anomaly - is what weather might explain.
trend_model <- loess(yield_t_ha ~ year, data = yield, span = 0.5)
yield <- yield %>%
  mutate(
    trend          = predict(trend_model),
    anomaly_pct    = 100 * (yield_t_ha - trend) / trend   # % above/below trend
  )
write_csv(yield, "output/tables/yield_with_trend.csv")

fig_c1 <- ggplot(yield, aes(year)) +
  annotate("rect", xmin = 1991, xmax = 2002, ymin = -Inf, ymax = Inf,
           fill = COL_GREY, alpha = 0.12) +
  annotate("text", x = 1996.5, y = Inf, label = "Civil war", vjust = 1.5,
           size = 3, colour = COL_INK2) +
  geom_line(aes(y = trend), colour = COL_ORANGE, linewidth = 0.9) +
  geom_line(aes(y = yield_t_ha), colour = COL_GREY, linewidth = 0.4) +
  geom_point(aes(y = yield_t_ha, shape = official), colour = COL_BLUE, size = 2) +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1),
                     labels = c(`TRUE` = "Official figure", `FALSE` = "Estimated / imputed")) +
  labs(title = "National rice yield in Sierra Leone",
       subtitle = "FAOSTAT yield (points) and long-term LOESS trend (orange line)",
       x = NULL, y = "Yield (t/ha)",
       caption = "Source: FAOSTAT (QCL). Hollow points are not official figures.") +
  theme_project()
save_figure(fig_c1, "C1_yield_trend.png", width = 8, height = 4)


# ---------------------------------------------------------------------
# 2. Join the national rainfall indices
# ---------------------------------------------------------------------
predictors <- c("onset_doy", "early_dry_spell", "season_total", "rx5day")

model_data <- yield %>%
  inner_join(filter(indices, region == "Sierra Leone"), by = "year") %>%
  select(year, anomaly_pct, official, all_of(predictors)) %>%
  filter(if_all(all_of(predictors), ~ !is.na(.x)))

message("Years available for modelling: ", nrow(model_data))

model_formula <- as.formula(paste("anomaly_pct ~", paste(predictors, collapse = " + ")))


# ---------------------------------------------------------------------
# 3. Leave-one-year-out cross-validation
# ---------------------------------------------------------------------
# For each year: hide it, train the models on all OTHER years, then
# predict the hidden year. Every prediction is therefore made on data
# the model has never seen - an honest test of how well it would
# forecast a new season.
loyo_cv <- function(data) {
  predictions <- list()
  for (i in seq_len(nrow(data))) {
    train <- data[-i, ]
    test  <- data[i, ]

    # (a) no-skill baseline: the average anomaly of the training years
    pred_null <- mean(train$anomaly_pct)

    # (b) linear regression
    lm_fit  <- lm(model_formula, data = train)
    pred_lm <- predict(lm_fit, newdata = test)

    # (c) random forest
    set.seed(42)   # random forests use randomness; fix it so results repeat
    rf_fit  <- randomForest::randomForest(model_formula, data = train,
                                          ntree = 500, nodesize = 3)
    pred_rf <- predict(rf_fit, newdata = test)

    predictions[[i]] <- tibble(
      year = test$year, observed = test$anomaly_pct,
      `No-skill baseline` = pred_null,
      `Linear regression` = unname(pred_lm),
      `Random forest`     = unname(pred_rf)
    )
  }
  bind_rows(predictions)
}

score_models <- function(predictions) {
  predictions %>%
    pivot_longer(-c(year, observed), names_to = "model", values_to = "predicted") %>%
    group_by(model) %>%
    summarise(
      RMSE = sqrt(mean((observed - predicted)^2)),     # typical error, % points
      MAE  = mean(abs(observed - predicted)),
      # (correlation is meaningless for the constant baseline, so we leave it blank)
      correlation = if (first(model) == "No-skill baseline") NA_real_ else
        cor(observed, predicted),
      .groups = "drop"
    ) %>%
    mutate(skill_vs_baseline = 1 - RMSE / RMSE[model == "No-skill baseline"])
}

cv_all  <- loyo_cv(model_data)
scores_all <- score_models(cv_all) %>% mutate(period = "All years")

# ---------------------------------------------------------------------
# 4. Robustness check: post-war years only
# ---------------------------------------------------------------------
cv_postwar <- loyo_cv(filter(model_data, year >= 2003))
scores_postwar <- score_models(cv_postwar) %>% mutate(period = "2003 onwards")

scores <- bind_rows(scores_all, scores_postwar)
print(scores, width = Inf)
write_csv(cv_all, "output/tables/cv_predictions.csv")
write_csv(scores, "output/tables/model_scores.csv")


# ---------------------------------------------------------------------
# 5. What do the models "use"? (fitted on all years)
# ---------------------------------------------------------------------
# Linear regression: standardised coefficients (effect of a one-SD change)
lm_std <- lm(model_formula, data = mutate(model_data, across(all_of(predictors), ~ as.numeric(scale(.x)))))
lm_table <- tibble(
  predictor = names(coef(lm_std))[-1],
  estimate  = coef(lm_std)[-1],
  std_error = summary(lm_std)$coefficients[-1, 2],
  p_value   = summary(lm_std)$coefficients[-1, 4]
)
write_csv(lm_table, "output/tables/regression_coefficients.csv")
print(summary(lm_std))

# Random forest: permutation importance (how much worse the model gets
# when one variable is shuffled)
set.seed(42)
rf_full <- randomForest::randomForest(model_formula, data = model_data,
                                      ntree = 500, nodesize = 3, importance = TRUE)
importance_table <- tibble(
  predictor  = rownames(randomForest::importance(rf_full)),
  pct_inc_mse = randomForest::importance(rf_full)[, "%IncMSE"]
)
write_csv(importance_table, "output/tables/rf_importance.csv")


# ---------------------------------------------------------------------
# 6. FIGURES C2 and C3
# ---------------------------------------------------------------------
pretty_names <- c(onset_doy = "Onset date", early_dry_spell = "Dry spell after onset",
                  season_total = "May-Oct rainfall", rx5day = "Wettest 5 days")

model_colours <- c("No-skill baseline" = COL_GREY, "Linear regression" = COL_BLUE,
                   "Random forest" = COL_ORANGE)

cv_long <- cv_all %>%
  pivot_longer(-c(year, observed), names_to = "model", values_to = "predicted") %>%
  filter(model != "No-skill baseline")

fig_c2 <- ggplot(cv_all, aes(year)) +
  geom_hline(yintercept = 0, colour = COL_INK2, linewidth = 0.3) +
  geom_line(aes(y = observed), colour = COL_INK, linewidth = 0.5) +
  geom_point(aes(y = observed), colour = COL_INK, size = 1.3) +
  geom_line(data = cv_long, aes(y = predicted, colour = model), linewidth = 0.8) +
  scale_colour_manual(values = model_colours) +
  labs(title = "Predicting each year's yield without having seen it",
       subtitle = "Observed yield anomaly (black) vs leave-one-year-out predictions",
       x = NULL, y = "Yield anomaly (% from trend)") +
  theme_project()

fig_c3_left <- scores_all %>%
  mutate(model = factor(model, levels = names(model_colours))) %>%
  ggplot(aes(RMSE, model, fill = model)) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f", RMSE)), hjust = -0.2, size = 3.2, colour = COL_INK) +
  scale_fill_manual(values = model_colours) +
  scale_x_continuous(expand = expansion(mult = c(0, 0.2))) +
  labs(title = "Prediction error on unseen years",
       subtitle = "RMSE, % points (lower is better)", x = NULL, y = NULL) +
  theme_project()

fig_c3_right <- importance_table %>%
  mutate(predictor = reorder(pretty_names[predictor], pct_inc_mse)) %>%
  ggplot(aes(pct_inc_mse, predictor)) +
  geom_col(fill = COL_ORANGE, width = 0.6) +
  geom_vline(xintercept = 0, colour = COL_INK2, linewidth = 0.3) +
  labs(title = "Random forest: variable importance",
       subtitle = "% increase in error when the variable is shuffled",
       x = NULL, y = NULL) +
  theme_project()

fig_c23 <- fig_c2 / (fig_c3_left + fig_c3_right) + plot_layout(heights = c(1.2, 1))
save_figure(fig_c23, "C2_model_comparison.png", width = 10, height = 7.5)

message("Part C done.")
