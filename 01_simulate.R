# 01_simulate.R
# Simulate a marketplace A/B test for a new restaurant recommendation algorithm.
# The data is synthetic and includes a known treatment effect.
# Ground truth: treatment improves conversion, with a larger effect for new users.
#
# Design targets (verified by tuning):
#   - Baseline (control) conversion ~ 20%
#   - Overall lift ~ 2 percentage points (matches the power analysis in 02_power.R)
#   - New users get a materially larger lift (~5pp) than existing users (~1pp)
#   - New users are a realistic share of the base (~20%), not a tiny sliver

library(tidyverse)

set.seed(123)

n <- 100000

# Tenure is right-skewed: many recent joiners, a long tail of long-standing users.
# A geometric distribution captures this far better than a symmetric Poisson and
# yields a realistic new-user share (~20%) under a "joined in the last 6 months" rule.
# historical_orders grows with tenure, and historical_spend grows with orders, so the
# pre-treatment covariates are correlated the way a real user base would be.
df <- tibble(
  user_id = 1:n,
  tenure_months = pmin(rgeom(n, prob = 0.04), 60),
  city = sample(c("London", "Manchester", "Birmingham"), n, replace = TRUE),
  treatment = rbinom(n, 1, 0.5)
)

df <- df %>%
  mutate(
    historical_orders = rpois(n, lambda = pmax(3 + 0.6 * tenure_months, 1)),
    historical_spend = round(pmax(rnorm(n, 60 + 6 * historical_orders, 40), 0), 2),
    is_new = tenure_months < 6,
    user_segment = if_else(is_new, "new", "existing")
  )

# Conversion is generated on the logit scale.
# Intercept is tuned to give baseline (control) conversion close to 20%.
# Because conversion rises with order history, new (low-tenure) users start a little
# below 20% and existing users a little above - this is realistic and intentional.
# Treatment effect is deliberately larger for new users.
# True designed treatment effect on the logit scale:
#   - New users:      0.31  (~5pp lift at this baseline)
#   - Existing users: 0.07  (~1pp lift at this baseline)
df <- df %>%
  mutate(
    base_logit = -1.388 +
      0.02 * (historical_orders - mean(historical_orders)) +
      0.0008 * (historical_spend - mean(historical_spend)),
    treat_effect = if_else(is_new, 0.31, 0.07) * treatment,
    logit_conversion = base_logit + treat_effect,
    p_conversion = plogis(logit_conversion),
    conversion = rbinom(n, 1, p_conversion)
  )

# Secondary metric: basket value, modelled per user (i.e. revenue per user, including
# non-converters as 0-ish low spenders). Modelling value per user rather than average
# order value among converters avoids conditioning on a post-treatment outcome, which
# would bias the comparison. Treatment lifts value slightly, more so for new users.
df <- df %>%
  mutate(
    basket_value = round(pmax(
      rnorm(
        n,
        mean = 25 +
          0.10 * historical_orders +
          1.50 * treatment +
          if_else(is_new, 0.75 * treatment, 0),
        sd = 8
      ),
      0
    ), 2)
  )

# Secondary metric: 30-day retention generated on the logit scale.
df <- df %>%
  mutate(
    retention_logit = -0.85 +
      0.015 * (historical_orders - mean(historical_orders)) +
      0.0005 * (historical_spend - mean(historical_spend)) +
      0.12 * treatment,
    p_retained_30d = plogis(retention_logit),
    retained_30d = rbinom(n, 1, p_retained_30d)
  )

# Quick checks for tuning.
overall_rates <- df %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    conversion_rate = mean(conversion),
    basket_value = mean(basket_value),
    retained_30d = mean(retained_30d),
    .groups = "drop"
  ) %>%
  mutate(conversion_rate = round(conversion_rate, 4))

segment_rates <- df %>%
  group_by(user_segment, treatment) %>%
  summarise(
    n = n(),
    conversion_rate = mean(conversion),
    .groups = "drop"
  ) %>%
  mutate(conversion_rate = round(conversion_rate, 4))

cat("New-user share:", round(mean(df$is_new), 4),
    "| mean tenure:", round(mean(df$tenure_months), 1), "months\n\n")
print(overall_rates)
print(segment_rates)

# Ensure the output directory exists before writing.
dir.create("outputs", showWarnings = FALSE)

saveRDS(df, "outputs/experiment_data.rds")
write_csv(df, "outputs/experiment_data.csv")

cat("Synthetic experiment data saved to outputs/experiment_data.rds and outputs/experiment_data.csv\n")
