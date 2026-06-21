# 05_hte.R
# Heterogeneous treatment effect analysis.

library(tidyverse)
library(broom)
library(ggplot2)

df <- readRDS("outputs/experiment_data.rds")

df <- df %>%
  mutate(user_segment = if_else(tenure_months < 6, "new", "existing"))

# Logistic interaction model.
hte_model <- glm(
  conversion ~ treatment * user_segment,
  family = binomial(),
  data = df
)

print(summary(hte_model))

hte_tidy <- tidy(hte_model, conf.int = TRUE, exponentiate = TRUE)
print(hte_tidy)

# Simple segment-level lifts for business interpretation.
segment_effects <- df %>%
  group_by(user_segment, treatment) %>%
  summarise(
    n = n(),
    conversion_rate = mean(conversion),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = treatment,
    values_from = c(n, conversion_rate),
    names_prefix = "treatment_"
  ) %>%
  mutate(
    absolute_lift_pp = (conversion_rate_treatment_1 - conversion_rate_treatment_0) * 100,
    relative_lift_pct = (
      conversion_rate_treatment_1 - conversion_rate_treatment_0
    ) / conversion_rate_treatment_0 * 100
  )

print(segment_effects)

write_csv(segment_effects, "outputs/hte_segment_effects.csv")
write_csv(hte_tidy, "outputs/hte_logistic_model.csv")

# City-level effects. No city heterogeneity is intentionally baked in.
city_effects <- df %>%
  group_by(city, treatment) %>%
  summarise(
    n = n(),
    conversion_rate = mean(conversion),
    .groups = "drop"
  ) %>%
  pivot_wider(
    names_from = treatment,
    values_from = c(n, conversion_rate),
    names_prefix = "treatment_"
  ) %>%
  mutate(
    absolute_lift_pp = (conversion_rate_treatment_1 - conversion_rate_treatment_0) * 100
  )

print(city_effects)

write_csv(city_effects, "outputs/city_effects.csv")

# Plot: conversion by segment and treatment.
plot_df <- df %>%
  group_by(user_segment, treatment) %>%
  summarise(
    conversion_rate = mean(conversion),
    n = n(),
    se = sqrt(conversion_rate * (1 - conversion_rate) / n),
    lower = conversion_rate - 1.96 * se,
    upper = conversion_rate + 1.96 * se,
    .groups = "drop"
  ) %>%
  mutate(treatment_label = if_else(treatment == 1, "Treatment", "Control"))

p <- ggplot(plot_df, aes(x = user_segment, y = conversion_rate, fill = treatment_label)) +
  geom_col(position = position_dodge(width = 0.8)) +
  geom_errorbar(
    aes(ymin = lower, ymax = upper),
    position = position_dodge(width = 0.8),
    width = 0.2
  ) +
  labs(
    title = "Conversion rate by user segment and treatment arm",
    x = "User segment",
    y = "Conversion rate",
    fill = "Experiment arm"
  ) +
  scale_y_continuous(labels = scales::percent) +
  theme_bw()

ggsave("outputs/conversion_by_segment.png", p, width = 8, height = 5)

cat("\nInterpretation template:\n")
cat("Update README with the segment-level lifts from outputs/hte_segment_effects.csv.\n")
cat("The new-user effect should be larger because this was designed into the simulation.\n")
