# 03_analyse.R
# Estimate the average treatment effect.

library(tidyverse)
library(broom)

df <- readRDS("outputs/experiment_data.rds")

# Two-proportion test for conversion.
x_t <- sum(df$conversion[df$treatment == 1])
x_c <- sum(df$conversion[df$treatment == 0])
n_t <- sum(df$treatment == 1)
n_c <- sum(df$treatment == 0)

prop_test <- prop.test(
  x = c(x_t, x_c),
  n = c(n_t, n_c)
)

print(prop_test)

# Logistic regression.
ate_model <- glm(conversion ~ treatment, family = binomial(), data = df)

print(summary(ate_model))

ate_tidy <- tidy(ate_model, conf.int = TRUE, exponentiate = TRUE)
print(ate_tidy)

# Absolute percentage-point lift.
rates <- df %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    conversion_rate = mean(conversion),
    basket_value = mean(basket_value),
    retained_30d = mean(retained_30d),
    .groups = "drop"
  )

control_rate <- rates$conversion_rate[rates$treatment == 0]
treatment_rate <- rates$conversion_rate[rates$treatment == 1]
absolute_lift <- treatment_rate - control_rate
relative_lift <- absolute_lift / control_rate

# Confidence interval on the percentage-point lift comes directly from prop.test.
# (prop.test returns the difference treatment - control because of the c(t, c) order.)
lift_ci <- prop_test$conf.int

summary_ate <- tibble(
  control_conversion = control_rate,
  treatment_conversion = treatment_rate,
  absolute_lift_pp = absolute_lift * 100,
  absolute_lift_lower_pp = lift_ci[1] * 100,
  absolute_lift_upper_pp = lift_ci[2] * 100,
  relative_lift_pct = relative_lift * 100,
  treatment_n = n_t,
  control_n = n_c
)

print(summary_ate)

write_csv(summary_ate, "outputs/ate_summary.csv")
write_csv(ate_tidy, "outputs/ate_logistic_model.csv")

cat("\nBusiness interpretation template:\n")
cat("Treatment conversion was", round(treatment_rate * 100, 2), "% versus",
    round(control_rate * 100, 2), "% in control, an absolute lift of",
    round(absolute_lift * 100, 2), "percentage points (95% CI",
    round(lift_ci[1] * 100, 2), "to", round(lift_ci[2] * 100, 2), "pp).\n")
cat("Update README: compare this estimate with the known effect baked into the simulation.\n")
