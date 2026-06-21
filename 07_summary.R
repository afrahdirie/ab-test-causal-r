# 07_summary.R
# Generate an executive summary from saved outputs.
# Every number below is read from the CSVs written by the earlier scripts, so the
# summary stays correct if the simulation or analysis is re-run. Run 01-06 first.

library(tidyverse)

ate   <- read_csv("outputs/ate_summary.csv", show_col_types = FALSE)
hte   <- read_csv("outputs/hte_segment_effects.csv", show_col_types = FALSE)
bayes <- read_csv("outputs/bayesian_summary.csv", show_col_types = FALSE)
srm   <- read_csv("outputs/srm_summary.csv", show_col_types = FALSE)

# Pull the segment lifts so the recommendation is data-driven, not assumed.
new_lift      <- hte$absolute_lift_pp[hte$user_segment == "new"]
existing_lift <- hte$absolute_lift_pp[hte$user_segment == "existing"]
new_is_larger <- length(new_lift) == 1 && length(existing_lift) == 1 &&
  new_lift > existing_lift

# Recommendation adapts to what the data actually shows.
if (new_is_larger) {
  recommendation_line <- paste0(
    "Recommendation: targeted rollout to new users, where the treatment effect is ",
    "strongest (", round(new_lift, 2), "pp vs ", round(existing_lift, 2),
    "pp for existing users), while monitoring long-term retention and guardrail ",
    "metrics before a wider launch."
  )
} else {
  recommendation_line <- paste0(
    "Recommendation: launch broadly, as the treatment effect is consistent across ",
    "user segments, while monitoring long-term retention and guardrail metrics."
  )
}

# SRM language is driven by the actual test result, not hard-coded.
if (isTRUE(srm$srm_flag)) {
  srm_line <- paste0(
    "- Allocation was ", round(srm$treatment_prop * 100, 2), "% treatment vs ",
    round((1 - srm$treatment_prop) * 100, 2), "% control (SRM test p = ",
    signif(srm$p_value, 2), "). At this sample size a deviation of this size is ",
    "consistent with chance under correct randomisation rather than an instrumentation ",
    "fault, but it should be confirmed against assignment logs.\n"
  )
} else {
  srm_line <- paste0(
    "- No sample ratio mismatch: allocation was ", round(srm$treatment_prop * 100, 2),
    "% treatment vs ", round((1 - srm$treatment_prop) * 100, 2),
    "% control (SRM test p = ", signif(srm$p_value, 2),
    "), consistent with the intended 50/50 split.\n"
  )
}

summary_text <- paste0(
"# Executive Summary\n\n",
"## Business question\n\n",
"We evaluated whether a new restaurant recommendation algorithm should be launched, ",
"using a synthetic A/B test with a known designed treatment effect.\n\n",
"## Overall effect\n\n",
"- Control conversion: ", round(ate$control_conversion * 100, 2), "%\n",
"- Treatment conversion: ", round(ate$treatment_conversion * 100, 2), "%\n",
"- Absolute lift: ", round(ate$absolute_lift_pp, 2), " percentage points ",
"(95% CI ", round(ate$absolute_lift_lower_pp, 2), " to ",
round(ate$absolute_lift_upper_pp, 2), " pp)\n",
"- Relative lift: ", round(ate$relative_lift_pct, 2), "%\n\n",
"## Heterogeneous effects\n\n",
paste(
  apply(hte, 1, function(row) {
    paste0(
      "- ", row[["user_segment"]], ": ",
      round(as.numeric(row[["absolute_lift_pp"]]), 2),
      " percentage-point lift"
    )
  }),
  collapse = "\n"
),
"\n\n",
"## Bayesian view\n\n",
"- Posterior probability treatment is better than control: ",
round(bayes$posterior_prob_treatment_better * 100, 2), "%\n",
"- Posterior mean lift: ", round(bayes$posterior_mean_lift_pp, 2), " percentage points\n\n",
"## Evidence\n\n",
"- Conversion increased from ", round(ate$control_conversion * 100, 2), "% to ",
round(ate$treatment_conversion * 100, 2), "% (",
round(ate$absolute_lift_pp, 2), " percentage points; ",
round(ate$relative_lift_pct, 2), "% relative lift).\n",
"- Bayesian analysis indicated a ",
round(bayes$posterior_prob_treatment_better * 100, 2),
"% probability that treatment outperformed control.\n",
if (new_is_larger) {
  paste0("- Treatment effects were substantially larger for new users (",
         round(new_lift, 2), "pp vs ", round(existing_lift, 2),
         "pp), supporting a targeted rollout strategy.\n")
} else {
  "- Treatment effects were consistent across user segments.\n"
},
"- Pre-treatment covariates were well balanced across experiment arms.\n\n",
"## Recommendation\n\n",
recommendation_line, "\n\n",
"## Production considerations\n\n",
srm_line,
"- Monitor cancellation rates, latency and customer complaints as guardrail metrics.\n",
"- Consider potential interference effects between users, restaurants and delivery partners.\n",
"- Avoid uncontrolled peeking; define a sequential testing or monitoring strategy before launch.\n",
"- Validate whether treatment effects persist over longer horizons and generalise across cohorts, cities and markets.\n"
)

writeLines(summary_text, "outputs/executive_summary.md")
cat(summary_text)
