# 04_diagnostics.R
# Experiment diagnostics: sample ratio mismatch and covariate balance.

library(tidyverse)

df <- readRDS("outputs/experiment_data.rds")

# Sample ratio mismatch test.
obs <- table(df$treatment)
print(obs)

srm_test <- binom.test(obs[["1"]], sum(obs), p = 0.5)
print(srm_test)

# Save the SRM result so the executive summary reads the real number rather than
# hard-coding it. Note: assignment here is an independent 50/50 coin flip, so the
# realised split wanders slightly. A test that crosses p < 0.05 at this sample size
# is an expected ~1-in-20 chance fluctuation under correct randomisation, NOT
# evidence of a bug. In a live system you would still confirm against assignment logs.
srm_summary <- tibble(
  treatment_n = obs[["1"]],
  control_n = obs[["0"]],
  treatment_prop = obs[["1"]] / sum(obs),
  p_value = srm_test$p.value,
  srm_flag = srm_test$p.value < 0.05
)
write_csv(srm_summary, "outputs/srm_summary.csv")

cat("\nSRM interpretation:\n")
if (srm_test$p.value < 0.05) {
  cat("Allocation deviates from 50/50 at the 5% level. At this sample size a deviation",
      "of this size is consistent with chance under correct randomisation; confirm",
      "against assignment logs before treating it as an instrumentation fault.\n")
} else {
  cat("No sample ratio mismatch detected at the 5% level.\n")
}

# Covariate balance: pre-treatment features should be similar across arms.
balance <- df %>%
  group_by(treatment) %>%
  summarise(
    n = n(),
    avg_orders = mean(historical_orders),
    avg_spend = mean(historical_spend),
    avg_tenure = mean(tenure_months),
    pct_new = mean(is_new),
    .groups = "drop"
  )

print(balance)

write_csv(balance, "outputs/covariate_balance.csv")

cat("\nProduction considerations:\n")
cat("- Check instrumentation errors and missing events.\n")
cat("- Check contamination or interference between users, restaurants and riders.\n")
cat("- Monitor guardrails such as cancellation rate, latency and complaint rate.\n")
cat("- Avoid peeking or define a sequential testing plan up front.\n")
