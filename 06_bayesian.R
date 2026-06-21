# 06_bayesian.R
# Complementary Bayesian analysis using a Beta-Binomial model.

library(tidyverse)

df <- readRDS("outputs/experiment_data.rds")

# Observed counts.
c1 <- sum(df$conversion[df$treatment == 1])
n1 <- sum(df$treatment == 1)

c0 <- sum(df$conversion[df$treatment == 0])
n0 <- sum(df$treatment == 0)

# Beta(1,1) uniform priors.
set.seed(1)
post_t <- rbeta(100000, 1 + c1, 1 + n1 - c1)
post_c <- rbeta(100000, 1 + c0, 1 + n0 - c0)

posterior_lift <- post_t - post_c

bayes_summary <- tibble(
  posterior_prob_treatment_better = mean(post_t > post_c),
  posterior_mean_lift_pp = mean(posterior_lift) * 100,
  posterior_lift_lower_95_pp = quantile(posterior_lift, 0.025) * 100,
  posterior_lift_upper_95_pp = quantile(posterior_lift, 0.975) * 100
)

print(bayes_summary)

write_csv(bayes_summary, "outputs/bayesian_summary.csv")

cat("\nBayesian interpretation template:\n")
cat("Using Beta(1,1) priors, the posterior probability that treatment converts better than control is",
    round(bayes_summary$posterior_prob_treatment_better * 100, 2), "%.\n")
cat("Frame this as complementary and stakeholder-friendly, not as automatically superior.\n")
