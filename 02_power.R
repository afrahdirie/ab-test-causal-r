# 02_power.R
# Power analysis for detecting a conversion lift.

library(pwr)

baseline_conversion <- 0.20
target_conversion <- 0.22

# 1) Sample size needed to detect the planned 2pp lift (20% -> 22%).
power_result <- pwr.2p.test(
  h = ES.h(baseline_conversion, target_conversion),
  power = 0.80,
  sig.level = 0.05
)

print(power_result)

cat("\nInterpretation:\n")
cat("To detect a lift from", baseline_conversion, "to", target_conversion,
    "at 80% power and 5% significance, we need approximately",
    ceiling(power_result$n), "users per arm.\n")
cat("The simulated experiment contains around 50,000 users per arm, so it is well-powered.\n")

# 2) Minimum detectable effect (MDE) at the ACTUAL sample size.
# This ties the power analysis to the experiment we actually ran, rather than
# leaving it as a standalone calculation. We invert the power test to find the
# smallest lift detectable at 80% power with 50,000 users per arm.
n_per_arm <- nrow(df)/2
mde_h <- pwr.2p.test(n = n_per_arm, power = 0.80, sig.level = 0.05)$h

# Convert the detectable effect-size h back to a conversion rate above 20%.
detectable_rate <- sin(asin(sqrt(baseline_conversion)) + mde_h / 2)^2
mde_pp <- (detectable_rate - baseline_conversion) * 100

cat("\nMinimum detectable effect at", n_per_arm, "users per arm:\n")
cat("We can detect a lift as small as", round(mde_pp, 3),
    "percentage points at 80% power.\n")
cat("The designed 2pp effect is comfortably above this threshold.\n")
