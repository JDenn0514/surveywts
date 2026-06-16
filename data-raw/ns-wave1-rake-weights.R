## data-raw/ns-wave1-rake-weights.R
##
## Attempt to replicate Nationscape's published survey weights using raking.
## Methodology: Tausanovitch & Warshaw (2021) / Nationscape Technical Report.
##   - Simple raking (IPF) to ACS 2017 targets
##   - 10 marginal dimensions (metro status excluded — not in public data)
##   - NR algorithm, trim at 5th/95th percentile
##
## Compare replicated weights against the published `weight` column.
##
## Run from the package root: source("data-raw/ns-wave1-rake-weights.R")

pkgload::load_all(quiet = TRUE)

load("data/ns_wave1.rda")

# ============================================================================
# Step 1: Recode weighting variables
# ============================================================================

df <- ns_wave1

# 1a. Census region (1 = NE, 2 = MW, 3 = South, 4 = West)
df$ns_region <- factor(
  df$census_region,
  levels = c(1L, 2L, 3L, 4L),
  labels = c("Northeast", "Midwest", "South", "West")
)

# 1b. Hispanic ethnicity (1 = Not Hispanic, 2 = Mexican, 3:15 = Other Hispanic)
df$ns_hispanic <- factor(
  ifelse(df$hispanic == 1L, "Not Hispanic",
  ifelse(df$hispanic == 2L, "Mexican",
                            "Other Hispanic")),
  levels = c("Not Hispanic", "Mexican", "Other Hispanic")
)

# 1c. Race — 4 Nationscape categories
#   1 = White, 2 = Black, 4:14 = Asian/Pacific, 3 + 15 = Other
df$ns_race <- factor(
  ifelse(df$race_ethnicity == 1L,            "White",
  ifelse(df$race_ethnicity == 2L,            "Black",
  ifelse(df$race_ethnicity %in% 4L:14L,      "Asian/Pacific",
  ifelse(df$race_ethnicity %in% c(3L, 15L),  "Other",
  NA_character_)))),
  levels = c("White", "Black", "Asian/Pacific", "Other")
)

# 1d. Age — 7 Nationscape groups
df$ns_age <- factor(
  ifelse(df$age %in% 18L:23L, "18-23",
  ifelse(df$age %in% 24L:29L, "24-29",
  ifelse(df$age %in% 30L:39L, "30-39",
  ifelse(df$age %in% 40L:49L, "40-49",
  ifelse(df$age %in% 50L:59L, "50-59",
  ifelse(df$age %in% 60L:69L, "60-69",
  ifelse(df$age >= 70L,        "70+",
  NA_character_))))))),
  levels = c("18-23", "24-29", "30-39", "40-49", "50-59", "60-69", "70+")
)

# 1e. Household language (1 = Spanish, 2 = Other non-English, 3 = English only)
df$ns_language <- factor(
  ifelse(df$language == 3L, "English only",
  ifelse(df$language == 1L, "Spanish",
                            "Other")),
  levels = c("English only", "Spanish", "Other")
)

# 1f. Country of birth (1 = United States, 2 = Other)
df$ns_foreign_born <- factor(
  ifelse(df$foreign_born == 1L, "United States", "Other"),
  levels = c("United States", "Other")
)

# 1g. Household income — 9 brackets + "No answer" for NAs
#   Raw codes 1-24 map to: 1-2 = <$20k, 3-5 = $20-35k, 6-8 = $35-50k,
#   9-11 = $50-65k, 12-14 = $65-80k, 15-18 = $80-100k, 19 = $100-125k,
#   20-22 = $125-200k, 23-24 = ≥$200k
df$ns_income <- factor(
  ifelse(is.na(df$household_income),             "No answer",
  ifelse(df$household_income %in% 1L:2L,         "<$20k",
  ifelse(df$household_income %in% 3L:5L,         "$20-35k",
  ifelse(df$household_income %in% 6L:8L,         "$35-50k",
  ifelse(df$household_income %in% 9L:11L,        "$50-65k",
  ifelse(df$household_income %in% 12L:14L,       "$65-80k",
  ifelse(df$household_income %in% 15L:18L,       "$80-100k",
  ifelse(df$household_income == 19L,             "$100-125k",
  ifelse(df$household_income %in% 20L:22L,       "$125-200k",
  ifelse(df$household_income %in% 23L:24L,       "≥$200k",
  NA_character_)))))))))),
  levels = c("<$20k", "$20-35k", "$35-50k", "$50-65k", "$65-80k",
             "$80-100k", "$100-125k", "$125-200k", "≥$200k", "No answer")
)

# 1h. 2016 presidential vote
#   1 = Trump, 2 = Clinton, 3:5 = Other, 6 = No vote
#   7 (ineligible) and 8 (don't recall) -> "No vote"
df$ns_vote_2016 <- factor(
  ifelse(df$vote_2016 == 1L, "Trump",
  ifelse(df$vote_2016 == 2L, "Clinton",
  ifelse(df$vote_2016 %in% 3L:5L, "Other",
                                  "No vote"))),
  levels = c("Trump", "Clinton", "Other", "No vote")
)

# ============================================================================
# Step 2: Sanity checks on recodes
# ============================================================================

stopifnot(all(!is.na(df$ns_region)))
stopifnot(all(!is.na(df$ns_hispanic)))
stopifnot(all(!is.na(df$ns_race)))
stopifnot(all(!is.na(df$ns_age)))
stopifnot(all(!is.na(df$ns_language)))
stopifnot(all(!is.na(df$ns_foreign_born)))
stopifnot(all(!is.na(df$ns_income)))
stopifnot(all(!is.na(df$ns_vote_2016)))

cat("Recode checks passed.\n")
cat("ns_race NAs (original):", sum(is.na(df$race_ethnicity)), "\n")

# ============================================================================
# Step 3: Specify raking targets (ACS 2017 proportions from Nationscape Table 1)
# ============================================================================

# Income: NA respondents get target = observed NA rate; ACS proportions for
# the 9 brackets are scaled by (1 - NA rate) so the 10 targets sum to 1.0.
income_na_rate <- mean(is.na(ns_wave1$household_income))
income_scale   <- 1 - income_na_rate

targets <- list(
  gender = c(
    "Male"   = 0.483,
    "Female" = 0.517
  ),
  ns_region = c(
    "Northeast" = 0.176,
    "Midwest"   = 0.209,
    "South"     = 0.378,
    "West"      = 0.237
  ),
  ns_hispanic = c(
    "Not Hispanic"  = 0.839,
    "Mexican"       = 0.097,
    "Other Hispanic" = 0.064
  ),
  ns_race = c(
    "White"         = 0.742,
    "Black"         = 0.120,
    "Asian/Pacific" = 0.068,
    "Other"         = 0.070
  ),
  ns_age = c(
    "18-23" = 0.095,
    "24-29" = 0.109,
    "30-39" = 0.174,
    "40-49" = 0.164,
    "50-59" = 0.174,
    "60-69" = 0.150,
    "70+"   = 0.134   # 0.133 in table; +0.001 to correct rounding to 1.0
  ),
  ns_language = c(
    "English only" = 0.783,
    "Spanish"      = 0.129,
    "Other"        = 0.088
  ),
  ns_foreign_born = c(
    "United States" = 0.822,
    "Other"         = 0.178
  ),
  ns_income = c(
    "<$20k"      = 0.107 * income_scale,
    "$20-35k"    = 0.116 * income_scale,
    "$35-50k"    = 0.118 * income_scale,
    "$50-65k"    = 0.113 * income_scale,
    "$65-80k"    = 0.098 * income_scale,
    "$80-100k"   = 0.110 * income_scale,
    "$100-125k"  = 0.105 * income_scale,
    "$125-200k"  = 0.146 * income_scale,
    "≥$200k" = 0.087 * income_scale,
    "No answer"  = income_na_rate
  ),
  ns_vote_2016 = c(
    "Trump"   = 0.272,
    "Clinton" = 0.284,
    "Other"   = 0.033,
    "No vote" = 0.411   # 0.410 in table; +0.001 to correct rounding to 1.0
  )
)

# Verify all target vectors sum to 1.0 (within floating-point tolerance)
for (nm in names(targets)) {
  s <- sum(targets[[nm]])
  if (abs(s - 1) > 1e-6) {
    warning(sprintf("Target '%s' sums to %.6f, not 1.0", nm, s))
  }
}

# ============================================================================
# Step 4: Rake
# ============================================================================

cat("Running NR raking...\n")
raked <- calibrate_rake(
  df,
  targets   = targets,
  weights   = weight,
  wt_name   = "rake_wt",
  type      = "prop",
  algorithm = "nr"
)

# ============================================================================
# Step 5: Trim at 5th / 95th percentile
# ============================================================================

raked <- trim_weights(
  raked,
  weights = rake_wt,
  lower   = 0.05,
  upper   = 0.95,
  type    = "percentile",
  wt_name = "rake_wt"
)

# ============================================================================
# Step 6: Compare with published Nationscape weights
# ============================================================================

pub_wt  <- df$weight
rake_wt <- raked$rake_wt

cat("\n--- Weight distribution comparison ---\n")
cat(sprintf("%-20s %8s %8s\n", "Statistic", "Published", "Replicated"))
cat(strrep("-", 40), "\n")
cat(sprintf("%-20s %8.4f %8.4f\n", "Min",    min(pub_wt),    min(rake_wt)))
cat(sprintf("%-20s %8.4f %8.4f\n", "P05",    quantile(pub_wt, .05), quantile(rake_wt, .05)))
cat(sprintf("%-20s %8.4f %8.4f\n", "Median", median(pub_wt), median(rake_wt)))
cat(sprintf("%-20s %8.4f %8.4f\n", "Mean",   mean(pub_wt),   mean(rake_wt)))
cat(sprintf("%-20s %8.4f %8.4f\n", "P95",    quantile(pub_wt, .95), quantile(rake_wt, .95)))
cat(sprintf("%-20s %8.4f %8.4f\n", "Max",    max(pub_wt),    max(rake_wt)))
cat(sprintf("%-20s %8.4f %8.4f\n", "SD",     sd(pub_wt),     sd(rake_wt)))
cat(sprintf("%-20s %8.4f %8.4f\n", "CV",     sd(pub_wt)/mean(pub_wt), sd(rake_wt)/mean(rake_wt)))

# Effective sample sizes
ess <- function(w) sum(w)^2 / sum(w^2)
cat(sprintf("%-20s %8.1f %8.1f\n", "ESS", ess(pub_wt), ess(rake_wt)))

# Correlation between weight vectors
cat(sprintf("\nCorrelation (pub vs replicated): %.4f\n", cor(pub_wt, rake_wt)))
cat(sprintf("Rank correlation:                %.4f\n", cor(pub_wt, rake_wt, method = "spearman")))

# Weighted margin checks: compare calibrated margins against targets
cat("\n--- Weighted margin check (replicated weights) ---\n")
check_margin <- function(var, var_label) {
  tab <- prop.table(tapply(rake_wt, df[[var]], sum))
  cat(sprintf("\n%s:\n", var_label))
  cat(sprintf("  %-20s %8s\n", "Level", "Prop"))
  for (lv in names(tab)) {
    cat(sprintf("  %-20s %8.4f\n", lv, tab[[lv]]))
  }
}

check_margin("gender",          "Gender")
check_margin("ns_region",       "Census region")
check_margin("ns_hispanic",     "Hispanic ethnicity")
check_margin("ns_race",         "Race")
check_margin("ns_age",          "Age")
check_margin("ns_language",     "Household language")
check_margin("ns_foreign_born", "Country of birth")
check_margin("ns_income",       "Household income")
check_margin("ns_vote_2016",    "2016 vote")
