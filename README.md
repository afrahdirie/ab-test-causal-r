A/B Testing & Causal Inference — Evaluating a Restaurant Recommendation Algorithm

End-to-end product experimentation workflow in R, built on synthetic data with a known designed effect. The project shows how a recommendation algorithm might be evaluated in a marketplace setting, and because the true treatment effect is baked into the simulation, it doubles as a check that the analysis pipeline actually recovers the effect it was designed to find.

The business questions:


Should we launch the new recommendation algorithm?
What is the true causal impact?
Which users benefit most?
Will the results generalise across segments?


Headline recommendation


The treatment improved conversion overall by 2.1 percentage points (from 20.1% in control to 22.2% in treatment, 95% CI on the lift roughly 1.6–2.6pp). The effect was materially larger for new users (~4.6pp lift) than existing users (~1.4pp). There was no evidence of sample ratio mismatch and pre-treatment covariates were balanced. Recommendation: targeted rollout to new users, while monitoring retention and guardrail metrics before a wider launch.



(Numbers are produced by the pipeline and written to outputs/executive_summary.md. Re-run the scripts to regenerate them.)

Why synthetic data?

The data is simulated so that the true treatment effect is known. This makes it possible to validate whether the analysis workflow recovers the effect that was intentionally designed into the data — the same instinct you would apply when sanity-checking an experimentation platform against ground truth before trusting it on real launches.

The simulated experiment includes:


100,000 users
50/50 random treatment assignment
Correlated pre-treatment user features (tenure, order history, spend)
Binary conversion outcome
Secondary metrics: per-user basket value and 30-day retention
A deliberately larger treatment effect for new users than existing users


Repository structure

textab-test-causal-r/
├── README.md
├── LICENSE
├── .gitignore
├── R/
│   ├── 01_simulate.R
│   ├── 02_power.R
│   ├── 03_analyse.R
│   ├── 04_diagnostics.R
│   ├── 05_hte.R
│   ├── 06_bayesian.R
│   └── 07_summary.R
├── outputs/
│   ├── executive_summary.md
│   └── conversion_by_segment.png
└── tests/
    └── test_simulate.R

How to run

From the project root, in order:

rsource("R/01_simulate.R")   # simulate the experiment
source("R/02_power.R")      # power analysis and minimum detectable effect
source("R/03_analyse.R")    # average treatment effect
source("R/04_diagnostics.R")# SRM and covariate balance
source("R/05_hte.R")        # heterogeneous treatment effects
source("R/06_bayesian.R")   # Bayesian Beta-Binomial view
source("R/07_summary.R")    # executive summary

Scripts 03–07 read the data and intermediate outputs from outputs/, so run 01 first.

Workflow and what to expect

1. Simulate the experiment

01_simulate.R creates correlated pre-treatment features (longer-tenured users have more order history and spend), randomly assigns treatment, and generates conversion from a logistic model. The true treatment effect is larger for new users (0.31 on the logit scale) than existing users (0.07).

After running, expect:


Baseline (control) conversion ≈ 20%
Overall lift ≈ 2 percentage points (matching the power-analysis target)
New users ≈ 22% of the base, with a visibly larger lift than existing users


2. Power analysis

02_power.R calculates the sample size needed to detect a 2pp lift (20% → 22%) at 80% power and 5% significance, and also reports the minimum detectable effect at the actual sample size, tying the power calculation to the experiment that was run.

3. Average treatment effect

03_analyse.R estimates the overall effect using a two-proportion test, logistic regression, the absolute percentage-point lift with a confidence interval, and the odds ratio.

4. Experiment diagnostics

04_diagnostics.R checks sample ratio mismatch and covariate balance, and writes the SRM result to disk. Note: because assignment is an independent 50/50 draw, the realised split varies slightly; a test crossing the 5% threshold at this sample size reflects expected sampling variation under correct randomisation, not an instrumentation fault. The script also lists marketplace-specific risks (contamination, interference, guardrails) to monitor in production.

5. Heterogeneous treatment effects

05_hte.R estimates effects for new vs existing users via a logistic interaction model, plus city-level segments. City is an intentional negative control — no city heterogeneity is built into the data — so similar lifts across cities is the expected, correct result.

6. Bayesian analysis

06_bayesian.R adds a Beta-Binomial view, reporting the posterior probability that treatment conversion exceeds control and the posterior distribution of the lift.

7. Executive summary

07_summary.R assembles the key outputs into outputs/executive_summary.md. Every number is read from the saved CSVs, so the summary stays consistent with the analysis if the simulation is re-run.

Production considerations

In a real marketplace experiment I would also weigh:


Sample ratio mismatch and instrumentation issues
Peeking and sequential testing
Interference between users, restaurants, and riders (SUTVA violations)
Short-term conversion versus long-term retention
Guardrail metrics such as cancellation rates and latency
Whether treatment effects generalise across markets and user cohorts


Notes


The data is synthetic. The known designed effect is what makes the pipeline self-validating: the estimated effects should recover the values baked into 01_simulate.R.
The simulated effect, the power-analysis target, and the estimated ATE are aligned at ~2pp by design.
