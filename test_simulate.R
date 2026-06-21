# test_simulate.R
# Simple checks for the synthetic data generation.
# Run after source("R/01_simulate.R").

library(tidyverse)

df <- readRDS("outputs/experiment_data.rds")

control_rate <- df %>%
  filter(treatment == 0) %>%
  summarise(rate = mean(conversion)) %>%
  pull(rate)

segment_lifts <- df %>%
  group_by(user_segment, treatment) %>%
  summarise(rate = mean(conversion), .groups = "drop") %>%
  pivot_wider(names_from = treatment, values_from = rate, names_prefix = "treatment_") %>%
  mutate(lift = treatment_1 - treatment_0)

new_lift <- segment_lifts %>%
  filter(user_segment == "new") %>%
  pull(lift)

existing_lift <- segment_lifts %>%
  filter(user_segment == "existing") %>%
  pull(lift)

stopifnot(control_rate > 0.18, control_rate < 0.22)
stopifnot(new_lift > existing_lift)

cat("Simulation tests passed:\n")
cat("- Control conversion is close to 20%.\n")
cat("- New-user lift is greater than existing-user lift.\n")
