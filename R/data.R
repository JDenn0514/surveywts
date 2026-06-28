# R/data.R
#
# Roxygen2 documentation for all bundled datasets.
# Each paired tibble + survey object shares one man page via @rdname.

# ============================================================================
# gss_2024 + gss_2024_svy
# ============================================================================

#' GSS 2024 sample data with harmonized demographic columns
#'
#' @description
#' The 2024 General Social Survey (GSS), obtained from
#' `surveycore::gss_2024`. All 3,309 respondents are retained, including those
#' with `NA` in `sex` or `age`. The raw integer `sex` column is overwritten
#' in-place with a factor. Five derived columns are added: `age_f3` (factor
#' from `age`), `race_f4` (factor from `race` and `hispanic`), `pid_f3`
#' (factor from `partyid`), `edu_f3` (factor from `degree`), and `wt_pop`
#' (population-scaled weight for IPW use).
#'
#' To construct a survey design for standard estimation, use:
#' ```r
#' data(gss_2024)
#' gss_design <- surveycore::as_survey(
#'   gss_2024, weights = wtssps, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' ```
#' For IPW workflows, use the `wt_pop` column instead of `wtssps`:
#' ```r
#' ref <- surveycore::as_survey(
#'   gss_2024, weights = wt_pop, strata = vstrat, ids = vpsu, nest = TRUE
#' )
#' ipw(ns_wave1, ref, selection = ~sex + age_f3)
#' ```
#'
#' @format
#' ## `gss_2024`
#' A data frame with 3,309 rows and 32 columns. All 27 original columns from
#' `surveycore::gss_2024` are retained. The `sex` column is overwritten in-place
#' as a factor; five new derived columns are added:
#' \describe{
#'   \item{vpsu}{Numeric. Primary sampling unit identifier for variance estimation.}
#'   \item{vstrat}{Numeric. Stratum identifier for variance estimation.}
#'   \item{wtssps}{Numeric. GSS normalized weight (mean approximately 1).
#'     Use for standard survey estimation. For IPW use `wt_pop` instead.}
#'   \item{wtssnrps}{Numeric. Alternative GSS weight (non-response adjusted).}
#'   \item{ballot}{Numeric. GSS ballot form assigned to the respondent.}
#'   \item{year}{Numeric. Survey year (2024).}
#'   \item{id}{Numeric. Respondent identifier.}
#'   \item{age}{Numeric. Age in years. Some respondents have `NA`.}
#'   \item{sex}{Factor. Derived from the original integer `sex` column:
#'     `1` = `"Male"`, `2` = `"Female"`, `NA` for other values. Levels:
#'     `c("Male", "Female")`.}
#'   \item{race}{Numeric. Race: `1` = White, `2` = Black, `3` = Other.}
#'   \item{hispanic}{Numeric. Hispanic origin indicator.}
#'   \item{educ}{Numeric. Years of education.}
#'   \item{degree}{Numeric. Highest degree: `0` = Less than HS, `1` = HS,
#'     `2` = Some college, `3` = College, `4` = Graduate.}
#'   \item{income16}{Numeric. Total family income (categorical).}
#'   \item{marital}{Numeric. Marital status.}
#'   \item{wrkstat}{Numeric. Labor force status.}
#'   \item{hrs1}{Numeric. Hours worked per week in primary job.}
#'   \item{adults}{Numeric. Number of adults in household.}
#'   \item{partyid}{Numeric. Party identification (7-point scale).}
#'   \item{polviews}{Numeric. Political views (7-point scale).}
#'   \item{happy}{Numeric. General happiness.}
#'   \item{health}{Numeric. Self-rated health.}
#'   \item{trust}{Numeric. Social trust.}
#'   \item{natfare}{Numeric. Opinion on welfare spending.}
#'   \item{abany}{Numeric. Abortion opinion (any reason).}
#'   \item{attend}{Numeric. Religious service attendance frequency.}
#'   \item{relig}{Numeric. Religion.}
#'   \item{age_f3}{Factor. Derived from `age` using
#'     `cut(age, breaks = c(18, 35, 55, Inf), right = FALSE)`. Levels:
#'     `c("18-34", "35-54", "55+")`. `NA` for age < 18 or missing age.}
#'   \item{race_f4}{Factor. Derived from `race` and `hispanic`: Hispanic
#'     origin takes precedence (`hispanic > 1` = `"Hispanic"`); `race == 1`
#'     = `"White"`, `race == 2` = `"Black"`, else `"Other"`. Levels:
#'     `c("White", "Black", "Hispanic", "Other")`.}
#'   \item{pid_f3}{Factor. Derived from `partyid`: `0:2` = `"Democrat"`,
#'     `3` = `"Independent"`, `4:6` = `"Republican"`, `7` = `NA`. Levels:
#'     `c("Republican", "Independent", "Democrat")`.}
#'   \item{edu_f3}{Factor. Derived from `degree`: `0` = `"Less than HS"`,
#'     `1:2` = `"HS/Some college"`, `3:4` = `"College+"`. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`.}
#'   \item{wt_pop}{Numeric. Population-scaled weight: `wtssps * (260000000 /
#'     nrow(gss_2024))`. Use for IPW reference design construction (sums to
#'     approximately 260 million, the 2024 US adult population estimate).}
#' }
#'
#' @source Derived from `surveycore::gss_2024`.
#'   See `data-raw/gss-2024.R` for the construction script.
#' @seealso [ns_wave1]
#' @keywords datasets
"gss_2024"

# ============================================================================
# npors_2025 + npors_2025_svy
# ============================================================================

#' Pew NPORS 2025 probability sample with harmonized demographic columns
#'
#' @description
#' The 2025 Pew National Public Opinion Reference Survey (NPORS), obtained from
#' `surveycore::pew_npors_2025`. All 5,022 respondents are retained.
#' The original `gender` column is kept as-is (numeric). Six derived columns
#' are added: `sex` (factor from `gender`), `age_f3`, `race_f4`, `edu_f3`,
#' `pid_f3`, and `wt_pop`.
#'
#' NPORS is a national address-based probability sample with stratified random
#' sampling and differential probabilities of selection across strata. Always
#' include `strata = stratum` when constructing a survey design from this data.
#' To construct a survey design for standard estimation:
#' ```r
#' data(npors_2025_clean)
#' npors_design <- surveycore::as_survey(
#'   npors_2025_clean, weights = weight, strata = stratum
#' )
#' ```
#' For IPW use, construct a reference design using `wt_pop`:
#' ```r
#' ref <- surveycore::as_survey(
#'   npors_2025_clean, weights = wt_pop, strata = stratum
#' )
#' ipw(ns_wave1, ref,
#'     selection = ~sex + age_f3 + race_f4 + edu_f3,
#'     missing_method = "omit")
#' ```
#' Approximately 0.5% of rows have `NA` in each derived column (from `99` /
#' "Refused" codes). Use [npors_2025_clean] to avoid listwise-deletion
#' warnings when passing to `ipw()`.
#'
#' @format
#' ## `npors_2025`
#' A data frame with 5,022 rows and 71 columns. All 65 original columns from
#' `surveycore::pew_npors_2025` are retained, including `gender` as numeric.
#' Six new derived columns are added (`sex`, `age_f3`, `race_f4`, `edu_f3`,
#' `pid_f3`, `wt_pop`):
#' \describe{
#'   \item{respid}{Character. Respondent identifier.}
#'   \item{mode}{Numeric. Interview mode.}
#'   \item{language}{Numeric. Interview language.}
#'   \item{languageinitial}{Numeric. Language at initial contact.}
#'   \item{stratum}{Numeric. Sampling stratum.}
#'   \item{interview_start}{Character. Interview start date/time.}
#'   \item{interview_end}{Character. Interview end date/time.}
#'   \item{econ1mod}{Numeric. Economic conditions assessment.}
#'   \item{econ1bmod}{Numeric. Economic conditions (follow-up).}
#'   \item{comtype2}{Numeric. Community type.}
#'   \item{unity}{Numeric. National unity opinion.}
#'   \item{crimesafe}{Numeric. Crime and safety opinion.}
#'   \item{govprotct}{Numeric. Government protection opinion.}
#'   \item{moregunimpact}{Numeric. Opinion on gun impact.}
#'   \item{fin_sit}{Numeric. Financial situation.}
#'   \item{vet1}{Numeric. Veteran status.}
#'   \item{vol12_cps}{Numeric. Volunteered in last 12 months.}
#'   \item{eminuse}{Numeric. Email use.}
#'   \item{intmob}{Numeric. Internet mobile use.}
#'   \item{intfreq}{Numeric. Internet frequency.}
#'   \item{intfreq_collapsed}{Numeric. Internet frequency (collapsed).}
#'   \item{home4nw2}{Numeric. Home internet access.}
#'   \item{bbhome}{Numeric. Broadband at home.}
#'   \item{smuse_fb}{Numeric. Uses Facebook.}
#'   \item{smuse_yt}{Numeric. Uses YouTube.}
#'   \item{smuse_x}{Numeric. Uses X (formerly Twitter).}
#'   \item{smuse_ig}{Numeric. Uses Instagram.}
#'   \item{smuse_sc}{Numeric. Uses Snapchat.}
#'   \item{smuse_wa}{Numeric. Uses WhatsApp.}
#'   \item{smuse_tt}{Numeric. Uses TikTok.}
#'   \item{smuse_rd}{Numeric. Uses Reddit.}
#'   \item{smuse_bsk}{Numeric. Uses Bluesky.}
#'   \item{smuse_th}{Numeric. Uses Threads.}
#'   \item{smuse_ts}{Numeric. Uses Tumblr.}
#'   \item{radio}{Numeric. Listens to radio.}
#'   \item{device1a}{Numeric. Device ownership.}
#'   \item{smart2}{Numeric. Smartphone ownership.}
#'   \item{nhisll}{Numeric. Health insurance.}
#'   \item{relig}{Numeric. Religion.}
#'   \item{religcat1}{Numeric. Religion category.}
#'   \item{born}{Numeric. Born-again Christian.}
#'   \item{attendper}{Numeric. Religious attendance (in-person).}
#'   \item{attendonline2}{Numeric. Religious attendance (online).}
#'   \item{relimp}{Numeric. Importance of religion.}
#'   \item{pray}{Numeric. Prayer frequency.}
#'   \item{educcat}{Numeric. Education category (raw): `1` = College+,
#'     `2` = HS/Some college, `3` = Less than HS, `99` = Refused.}
#'   \item{registration}{Numeric. Voter registration status.}
#'   \item{party}{Numeric. Political party identification.}
#'   \item{partyln}{Numeric. Party leaning (for independents).}
#'   \item{partysum}{Numeric. Party summary.}
#'   \item{hisp}{Numeric. Hispanic origin: `1` = Yes, `2` = No.}
#'   \item{racecmb}{Numeric. Race (combined).}
#'   \item{racethn}{Numeric. Race/ethnicity (raw): `1` = White, `2` = Black,
#'     `3` = Hispanic, `4` = Other, `5` = Asian, `99` = Refused.}
#'   \item{agegrp}{Numeric. Age group (raw): `1`-`13` = fine-grained age
#'     categories, `99` = Refused.}
#'   \item{agecat}{Numeric. Age category (alternative grouping).}
#'   \item{birthplace}{Numeric. Born in the United States.}
#'   \item{gender}{Numeric. Interview gender: `1` = Male, `2` = Female,
#'     `3` = Non-binary, `99` = Refused.}
#'   \item{adults}{Numeric. Number of adults in household.}
#'   \item{voted2024}{Numeric. Voted in 2024.}
#'   \item{votegen_post}{Numeric. 2024 vote choice.}
#'   \item{inc_sdt1}{Numeric. Income.}
#'   \item{cregion}{Numeric. Census region.}
#'   \item{metro}{Numeric. Metropolitan area.}
#'   \item{basewt}{Numeric. Base weight before calibration.}
#'   \item{weight}{Numeric. Final normalized survey weight (mean approximately
#'     1). Use for standard estimation. For IPW use `wt_pop` instead.}
#'   \item{sex}{Factor. Derived from `gender`: `1` = `"Male"`, `2` =
#'     `"Female"`, `3` (Non-binary) and `99` (Refused) recoded to `NA`.
#'     Levels: `c("Male", "Female")`. Approximately 0.5% `NA`.}
#'   \item{age_f3}{Factor. Derived from `agegrp`: `1:3` = `"18-34"`,
#'     `4:7` = `"35-54"`, `8:13` = `"55+"`, `99` = `NA`. Levels:
#'     `c("18-34", "35-54", "55+")`. Approximately 0.5% `NA`.}
#'   \item{race_f4}{Factor. Derived from `racethn`: `1` = `"White"`,
#'     `2` = `"Black"`, `3` = `"Hispanic"`, `4`/`5` = `"Other"` (Asian
#'     collapsed), `99` = `NA`. Levels: `c("White", "Black", "Hispanic",
#'     "Other")`. Approximately 0.5% `NA`.}
#'   \item{edu_f3}{Factor. Derived from `educcat`: `3` = `"Less than HS"`,
#'     `2` = `"HS/Some college"`, `1` = `"College+"`, `99` = `NA`. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`. Approximately
#'     0.5% `NA`.}
#'   \item{pid_f3}{Factor. Derived from `partysum`: `1` = `"Republican"`,
#'     `2` = `"Democrat"`, `9` = `"Independent"`, other = `NA`. Levels:
#'     `c("Republican", "Independent", "Democrat")`. Approximately 0.5%
#'     `NA`.}
#'   \item{wt_pop}{Numeric. Population-scaled weight: `weight * (260000000 /
#'     nrow(npors_2025))`. Use for IPW reference design construction (sums to
#'     approximately 260 million, the 2024 US adult population estimate).}
#' }
#'
#' @source Derived from `surveycore::pew_npors_2025`.
#'   See `data-raw/npors-2025.R` for the construction script.
#' @seealso [npors_2025_clean], [ns_wave1]
#' @keywords datasets
"npors_2025"

# ============================================================================
# npors_2025_clean + npors_2025_clean_svy
# ============================================================================

#' Pew NPORS 2025 complete cases only
#'
#' @description
#' A filtered version of [npors_2025] with rows removed where any of
#' `sex`, `age_f3`, `race_f4`, `edu_f3`, or `pid_f3` is `NA`. Approximately
#' 4,814 rows are retained (5,022 minus approximately 208 rows with at least
#' one `NA` in the five derived columns). Weights are not re-normalized after
#' row removal.
#'
#' NPORS is a national address-based probability sample with stratified random
#' sampling and differential probabilities of selection across strata. Always
#' include `strata = stratum` when constructing a survey design from this data.
#' To construct a survey design for standard estimation:
#' ```r
#' data(npors_2025_clean)
#' npors_design <- surveycore::as_survey(
#'   npors_2025_clean, weights = weight, strata = stratum
#' )
#' ```
#' For IPW use, construct a reference design using `wt_pop`:
#' ```r
#' ref <- surveycore::as_survey(
#'   npors_2025_clean, weights = wt_pop, strata = stratum
#' )
#' ipw(ns_wave1, ref,
#'     selection = ~sex + age_f3 + race_f4 + edu_f3,
#'     missing_method = "omit")
#' ```
#'
#' Use this object when passing to `ipw()` to avoid the
#' `surveywts_warning_ipw_reference_na_omitted` warning. Use [npors_2025]
#' when downstream code handles missingness itself.
#'
#' @format
#' ## `npors_2025_clean`
#' A data frame with approximately 4,814 rows and 71 columns (same column
#' structure as [npors_2025]). No `NA` values in `sex`, `age_f3`, `race_f4`,
#' `edu_f3`, or `pid_f3`.
#' \describe{
#'   \item{respid}{Character. Respondent identifier.}
#'   \item{mode}{Numeric. Interview mode.}
#'   \item{language}{Numeric. Interview language.}
#'   \item{languageinitial}{Numeric. Language at initial contact.}
#'   \item{stratum}{Numeric. Sampling stratum.}
#'   \item{interview_start}{Character. Interview start date/time.}
#'   \item{interview_end}{Character. Interview end date/time.}
#'   \item{econ1mod}{Numeric. Economic conditions assessment.}
#'   \item{econ1bmod}{Numeric. Economic conditions (follow-up).}
#'   \item{comtype2}{Numeric. Community type.}
#'   \item{unity}{Numeric. National unity opinion.}
#'   \item{crimesafe}{Numeric. Crime and safety opinion.}
#'   \item{govprotct}{Numeric. Government protection opinion.}
#'   \item{moregunimpact}{Numeric. Opinion on gun impact.}
#'   \item{fin_sit}{Numeric. Financial situation.}
#'   \item{vet1}{Numeric. Veteran status.}
#'   \item{vol12_cps}{Numeric. Volunteered in last 12 months.}
#'   \item{eminuse}{Numeric. Email use.}
#'   \item{intmob}{Numeric. Internet mobile use.}
#'   \item{intfreq}{Numeric. Internet frequency.}
#'   \item{intfreq_collapsed}{Numeric. Internet frequency (collapsed).}
#'   \item{home4nw2}{Numeric. Home internet access.}
#'   \item{bbhome}{Numeric. Broadband at home.}
#'   \item{smuse_fb}{Numeric. Uses Facebook.}
#'   \item{smuse_yt}{Numeric. Uses YouTube.}
#'   \item{smuse_x}{Numeric. Uses X (formerly Twitter).}
#'   \item{smuse_ig}{Numeric. Uses Instagram.}
#'   \item{smuse_sc}{Numeric. Uses Snapchat.}
#'   \item{smuse_wa}{Numeric. Uses WhatsApp.}
#'   \item{smuse_tt}{Numeric. Uses TikTok.}
#'   \item{smuse_rd}{Numeric. Uses Reddit.}
#'   \item{smuse_bsk}{Numeric. Uses Bluesky.}
#'   \item{smuse_th}{Numeric. Uses Threads.}
#'   \item{smuse_ts}{Numeric. Uses Tumblr.}
#'   \item{radio}{Numeric. Listens to radio.}
#'   \item{device1a}{Numeric. Device ownership.}
#'   \item{smart2}{Numeric. Smartphone ownership.}
#'   \item{nhisll}{Numeric. Health insurance.}
#'   \item{relig}{Numeric. Religion.}
#'   \item{religcat1}{Numeric. Religion category.}
#'   \item{born}{Numeric. Born-again Christian.}
#'   \item{attendper}{Numeric. Religious attendance (in-person).}
#'   \item{attendonline2}{Numeric. Religious attendance (online).}
#'   \item{relimp}{Numeric. Importance of religion.}
#'   \item{pray}{Numeric. Prayer frequency.}
#'   \item{educcat}{Numeric. Education category (raw): `1` = College+,
#'     `2` = HS/Some college, `3` = Less than HS.}
#'   \item{registration}{Numeric. Voter registration status.}
#'   \item{party}{Numeric. Political party identification.}
#'   \item{partyln}{Numeric. Party leaning (for independents).}
#'   \item{partysum}{Numeric. Party summary.}
#'   \item{hisp}{Numeric. Hispanic origin: `1` = Yes, `2` = No.}
#'   \item{racecmb}{Numeric. Race (combined).}
#'   \item{racethn}{Numeric. Race/ethnicity (raw).}
#'   \item{agegrp}{Numeric. Age group (raw).}
#'   \item{agecat}{Numeric. Age category (alternative grouping).}
#'   \item{birthplace}{Numeric. Born in the United States.}
#'   \item{gender}{Numeric. Interview gender: `1` = Male, `2` = Female,
#'     `3` = Non-binary, `99` = Refused.}
#'   \item{adults}{Numeric. Number of adults in household.}
#'   \item{voted2024}{Numeric. Voted in 2024.}
#'   \item{votegen_post}{Numeric. 2024 vote choice.}
#'   \item{inc_sdt1}{Numeric. Income.}
#'   \item{cregion}{Numeric. Census region.}
#'   \item{metro}{Numeric. Metropolitan area.}
#'   \item{basewt}{Numeric. Base weight before calibration.}
#'   \item{weight}{Numeric. Final normalized survey weight. Use for standard
#'     estimation. For IPW use `wt_pop` instead.}
#'   \item{sex}{Factor. `"Male"` or `"Female"`. No `NA` values. Levels:
#'     `c("Male", "Female")`.}
#'   \item{age_f3}{Factor. `"18-34"`, `"35-54"`, or `"55+"`. No `NA`
#'     values. Levels: `c("18-34", "35-54", "55+")`.}
#'   \item{race_f4}{Factor. Race/ethnicity (4-level). No `NA` values. Levels:
#'     `c("White", "Black", "Hispanic", "Other")`.}
#'   \item{edu_f3}{Factor. Education level. No `NA` values. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`.}
#'   \item{pid_f3}{Factor. Party identification. No `NA` values. Levels:
#'     `c("Republican", "Independent", "Democrat")`.}
#'   \item{wt_pop}{Numeric. Population-scaled weight: `weight * (260000000 /
#'     5022)`. Weights are not re-normalized after row removal.}
#' }
#'
#' @source Derived from [npors_2025].
#'   See `data-raw/npors-2025.R` for the construction script.
#' @seealso [npors_2025], [ns_wave1]
#' @keywords datasets
"npors_2025_clean"


# ============================================================================
# pew_2016_optin + pew_2016_optin_svy
# ============================================================================

#' Pew 2016 ATP opt-in sample
#'
#' @title Pew 2016 ATP opt-in sample
#' @description A 2,000-respondent random sample drawn from a 2016 Pew Research
#'   Center study fielded simultaneously on three opt-in (non-probability) online
#'   vendor panels alongside the probability-based American Trends Panel (ATP).
#'   The original study (31,863 respondents) is used in Mercer, Lau and Kennedy
#'   (2018) "For Weighting Online Opt-In Samples, What Matters Most?" and
#'   provides 13 benchmark variables (shared with [pew_2016_synth_pop]) that can
#'   be validated against population truth estimates. `pew_2016_optin` contains
#'   a random sample of 2,000 complete-case respondents drawn after removing rows
#'   with `NA` in any of the 7 calibration variables (seed 42).
#'
#'   Value labels are preserved as named numeric attributes on each column
#'   (accessible via `attr(pew_2016_optin$gender, "labels")`). Variable labels
#'   are stored in the `"label"` attribute of each column.
#'
#'   To construct a `survey_nonprob` for analysis, use the promoted `weight`
#'   column directly from the tibble:
#'   ```r
#'   data(pew_2016_optin)
#'   pew_design <- surveycore::survey_nonprob(
#'     pew_2016_optin,
#'     weights = "weight",
#'     repwts = contains("repwt_")
#'   )
#'   ```
#'
#' @format A data frame with 2,000 rows and 305 columns:
#' \describe{
#'   \item{rid}{Character. Respondent ID with vendor prefix (e.g., `"V1_7"`).}
#'   \item{vendor}{Numeric. Opt-in panel vendor: `1` = Vendor 1, `2` = Vendor 2,
#'     `3` = Vendor 3.}
#'   \item{enddate}{Date. Date respondent completed the survey.}
#'   \item{age}{Numeric (continuous). Age in years (range 18-110; values above
#'     ~95 are likely data entry artefacts or sentinel codes).}
#'   \item{presapp}{Numeric. Presidential approval (Obama): `1` = Approve,
#'     `2` = Disapprove, `9` = Refused.}
#'   \item{happy}{Numeric. General happiness: `1` = Very happy, `2` = Pretty
#'     happy, `3` = Not too happy, `9` = Refused.}
#'   \item{folgov}{Numeric. Follows government/public affairs (ordinal):
#'     `1` = Most of the time, `2` = Some of the time, `3` = Only now and
#'     then, `4` = Hardly at all, `5` = Refused.}
#'   \item{votegen}{Numeric. 2016 presidential vote intention (first choice).}
#'   \item{votegen2}{Numeric. 2016 presidential vote intention (follow-up).}
#'   \item{votegen3}{Numeric. Forced-choice vote preference (Trump vs Clinton).}
#'   \item{talk_cps}{Numeric. Frequency of talking with neighbors (ordinal):
#'     `1` = Basically every day, `2` = A few times a week, `3` = A few times
#'     a month, `4` = Rarely, `5` = Not at all, `6` = Refused.}
#'   \item{trust_cps}{Numeric. Trust in neighbors (ordinal): `1` = All of
#'     the people, `2` = Most, `3` = Some, `4` = None, `5` = Refused.}
#'   \item{comgrp_cps}{Integer. Participated in community group in last 12
#'     months: `1` = Yes, `0` = No, `NA` = Refused.}
#'   \item{vol1}{Numeric. Volunteered through an organization in last 12 months:
#'     `1` = Yes, `2` = No, `9` = Refused.}
#'   \item{vol2}{Numeric. Volunteered informally or for children's
#'     organizations: `1` = Yes, `2` = No, `9` = Refused.}
#'   \item{acaapp}{Numeric. ACA approval: `1` = Approve, `2` = Disapprove,
#'     `9` = Refused.}
#'   \item{mrjlegal}{Numeric. Marijuana legalization opinion: `1` = Should be
#'     legal, `2` = Should not be legal, `9` = Refused.}
#'   \item{discrima}{Numeric. Discrimination against Blacks: `1` = A lot,
#'     `2` = Not a lot, `9` = Refused.}
#'   \item{discrimb}{Numeric. Discrimination against gays/lesbians:
#'     `1` = A lot, `2` = Not a lot, `9` = Refused.}
#'   \item{discrimc}{Numeric. Discrimination against Hispanics: `1` = A lot,
#'     `2` = Not a lot, `9` = Refused.}
#'   \item{folnews}{Numeric. Follows the news: `1` = Most of the time,
#'     `2` = Sometimes, `3` = Hardly ever, `9` = Refused.}
#'   \item{newsclosea}{Numeric. How closely follows international news.}
#'   \item{newscloseb}{Numeric. How closely follows national news.}
#'   \item{newsclosec}{Numeric. How closely follows local news.}
#'   \item{pair1}{Numeric. Opinion pair statement 1 (government scope).}
#'   \item{pair2}{Numeric. Opinion pair statement 2 (business regulation).}
#'   \item{pair3}{Numeric. Opinion pair statement 3 (racial discrimination).}
#'   \item{owngun_gss}{Integer. Gun in home: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{evsmk_nhis}{Numeric. Smoked 100+ cigarettes in lifetime:
#'     `1` = Yes, `2` = No, `9` = Refused.}
#'   \item{nowsmk_nhis}{Numeric. Current smoking: `1` = Every day,
#'     `2` = Some days, `3` = Not at all, `9` = Refused.}
#'   \item{racerel}{Numeric. Race relations trend: `1` = Getting better,
#'     `2` = Getting worse, `3` = About the same, `9` = Refused.}
#'   \item{pub_off_cps}{Integer. Contacted public official in last 12 months:
#'     `1` = Yes, `0` = No, `NA` = Refused.}
#'   \item{prtypref_gss}{Numeric. Party preference (raw GSS question):
#'     `1` = Republican, `2` = Democrat, `3` = Independent, `4` = Other,
#'     `5` = No preference, `9` = Refused.}
#'   \item{prtystrg_gss}{Numeric. Strength of party ID: `1` = Strong,
#'     `2` = Not very strong, `9` = Refused.}
#'   \item{prtyind_gss}{Numeric. Independent leaning: `1` = Republican,
#'     `2` = Democrat, `3` = Neither, `9` = Refused.}
#'   \item{polviews_gss}{Numeric. Political views, 7-point scale
#'     (1 = Extremely liberal, 7 = Extremely conservative).}
#'   \item{tablet_cps}{Integer. Uses tablet/e-reader: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{textim_cps}{Integer. Uses texting/instant messaging: `1` = Yes,
#'     `0` = No, `NA` = Refused.}
#'   \item{social_cps}{Integer. Uses social networking: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{adults_hh}{Numeric. Number of adults (18+) in household.}
#'   \item{children_hh}{Numeric. Number of children under 18 in household.}
#'   \item{home_acs}{Numeric. Home ownership/rental status (raw ACS question).}
#'   \item{tenure_acs}{Numeric. Lived in home one year ago: `1` = Yes,
#'     `2` = No -- different address in same city, `3` = No -- different city.}
#'   \item{gender}{Numeric. `1` = Male, `2` = Female, `3` = Refused.}
#'   \item{educ_acs}{Numeric. Highest degree completed (raw ACS question).}
#'   \item{marital_acs}{Numeric. Marital status (ACS question).}
#'   \item{mil_acs}{Numeric. Active-duty military service history (raw ACS).}
#'   \item{hisp_acs}{Numeric. Hispanic or Latino origin (ACS question).}
#'   \item{race_acs_1}{Numeric. Race indicator: White (`1` = selected).}
#'   \item{race_acs_2}{Numeric. Race indicator: Black or African American.}
#'   \item{race_acs_3}{Numeric. Race indicator: Asian.}
#'   \item{race_acs_4}{Numeric. Race indicator: American Indian or Alaska
#'     Native.}
#'   \item{race_acs_5}{Numeric. Race indicator: Native Hawaiian or Pacific
#'     Islander.}
#'   \item{race_acs_6}{Numeric. Race indicator: Some other race.}
#'   \item{born_acs}{Numeric. Born in the United States (ACS question).}
#'   \item{citizen}{Numeric. U.S. citizenship status (raw ACS question).}
#'   \item{insure_nhis}{Numeric. Health insurance coverage (NHIS question).}
#'   \item{fdall_nhanes}{Numeric. Has food allergies (NHANES question):
#'     `1` = Yes, `2` = No, `9` = Refused.}
#'   \item{relig}{Numeric. Present religion (raw question).}
#'   \item{relig_else}{Character. Open-ended religion response ("other").}
#'   \item{chr}{Numeric. Self-identifies as Christian: `1` = Yes, `2` = No,
#'     `9` = Refused.}
#'   \item{born}{Numeric. Born-again or evangelical Christian: `1` = Yes,
#'     `2` = No, `9` = Refused.}
#'   \item{attend}{Numeric. Religious service attendance frequency.}
#'   \item{relimp}{Numeric. Importance of religion in life.}
#'   \item{pray}{Numeric. Prayer frequency outside of religious services.}
#'   \item{fdstmp_cps}{Integer. Household received food stamps in 2015:
#'     `1` = Yes, `0` = No, `NA` = Refused.}
#'   \item{wrkstat_gss}{Numeric. Work status last week (GSS question).}
#'   \item{registered}{Integer. Registered to vote: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{pvote12a}{Numeric. 2012 presidential election: voted or not.}
#'   \item{pvote12b}{Numeric. 2012 presidential vote: Obama, Romney, or other.}
#'   \item{vote14}{Integer. Voted in 2014 midterms: `1` = Voted,
#'     `0` = Did not vote, `NA` = Refused.}
#'   \item{faminc_cps}{Numeric. Family income in past 12 months (raw CPS
#'     categories).}
#'   \item{ideo3}{Numeric. Ideology 3-category recode of `polviews_gss`:
#'     `1` = Liberal, `2` = Moderate, `3` = Conservative, `4` = Refused.}
#'   \item{faminc5}{Numeric. Family income, 5-category recode of `faminc_cps`.}
#'   \item{employed}{Numeric. Employment status, 3-category recode of
#'     `wrkstat_gss`.}
#'   \item{citizen_rec}{Numeric. Citizenship recode of `citizen` (removes
#'     "Not Asked" category).}
#'   \item{mil_acs_rec}{Numeric. Military status, 2-category recode of
#'     `mil_acs`.}
#'   \item{home_acs_rec}{Numeric. Home ownership, 3-category recode of
#'     `home_acs`.}
#'   \item{hhsizecat}{Numeric. Household size category recode.}
#'   \item{hhsize}{Numeric. Household size (sum of `adults_hh` and
#'     `children_hh`).}
#'   \item{childrencat}{Numeric. Children category, 2-category recode of
#'     `children_hh`.}
#'   \item{agecat6}{Numeric. 6-category age recode: `1` = 18-24, `2` = 25-34,
#'     `3` = 35-44, `4` = 45-54, `5` = 55-64, `6` = 65+.}
#'   \item{religcat}{Numeric. Religion, 6-category recode incorporating `born`.}
#'   \item{relig_rec}{Numeric. Religion recode incorporating `chr`.}
#'   \item{racethn}{Numeric. Race/ethnicity: `1` = White non-Hispanic,
#'     `2` = Black non-Hispanic, `3` = Hispanic, `4` = Asian,
#'     `5` = Other race, `6` = Refused.}
#'   \item{educcat3}{Numeric. 3-category education: `1` = HS or less,
#'     `2` = Some college, `3` = College grad, `4` = Refused.}
#'   \item{educcat5}{Numeric. 5-category education: `1` = Less than HS,
#'     `2` = HS Grad, `3` = Some college, `4` = College grad,
#'     `5` = Postgraduate, `6` = Refused.}
#'   \item{partysum}{Numeric. Party ID, 3-category recode of `partyscale5`.}
#'   \item{partyscale3}{Numeric. Party ID, 3-category recode of `prtypref_gss`.}
#'   \item{partyscale5}{Numeric. Party ID: `1` = Republican, `2` = Lean
#'     Republican, `3` = Ind/No Lean, `4` = Lean Democrat, `5` = Democrat.}
#'   \item{partyscale7}{Numeric. 7-point party scale (Strong R to Strong D).}
#'   \item{smoker}{Numeric. Current smoker recode of `evsmk_nhis` and
#'     `nowsmk_nhis`: `1` = Current smoker, `0` = Non-smoker.}
#'   \item{volsum}{Integer. Volunteered in past year: `1` = Volunteered,
#'     `0` = Did not volunteer, `NA` = Refused.}
#'   \item{votesum}{Numeric. Vote intention recode of `votegen` and `votegen3`.}
#'   \item{votescale}{Numeric. 7-category vote scale recode of `votegen`,
#'     `votegen2`, and `votegen3`.}
#'   \item{state}{Character. State of residence.}
#'   \item{division}{Numeric. Census division, **alphabetical coding** (not
#'     standard Census order): `1` = East North Central, `2` = East South
#'     Central, `3` = Middle Atlantic, `4` = Mountain, `5` = New England,
#'     `6` = Pacific, `7` = South Atlantic, `8` = West North Central,
#'     `9` = West South Central. Coding matches [pew_2016_synth_pop].}
#'   \item{region}{Numeric. Census region: `1` = Midwest, `2` = Northeast,
#'     `3` = South, `4` = West.}
#'   \item{language}{Numeric. Interview language: `1` = English,
#'     `2` = Spanish.}
#'   \item{sex}{Factor. Derived from `gender`: `1` = `"Male"`, `2` =
#'     `"Female"`, `3` (Refused) = `NA`. Levels: `c("Male", "Female")`.}
#'   \item{race_f4}{Factor. Derived from `racethn`: `1` = `"White"`,
#'     `2` = `"Black"`, `3` = `"Hispanic"`, `4`/`5` = `"Other"` (Asian
#'     collapsed), `6` = `NA`. Levels:
#'     `c("White", "Black", "Hispanic", "Other")`.}
#'   \item{edu_f3}{Factor. Derived from `educcat5`: `1` = `"Less than HS"`,
#'     `2:3` = `"HS/Some college"`, `4:5` = `"College+"`, `6` = `NA`.
#'     Levels: `c("Less than HS", "HS/Some college", "College+")`.}
#'   \item{pid_f3}{Factor. Derived from `partyscale3` (GSS-style 3-category
#'     party): `1` = `"Republican"`, `2` = `"Democrat"`, `3` =
#'     `"Independent"`. Levels: `c("Republican", "Independent", "Democrat")`.}
#'   \item{age_f3}{Factor. Derived from `agecat6`: `1:2` = `"18-34"`,
#'     `3:4` = `"35-54"`, `5:6` = `"55+"`. Levels:
#'     `c("18-34", "35-54", "55+")`.}
#'   \item{weight}{Numeric. Calibrated survey weight produced by raking to
#'     unweighted proportions from [pew_2016_synth_pop] (Newton-Raphson,
#'     7 marginal dimensions: `sex`, `age_f3`, `race_f4`, `edu_f3`,
#'     `division`, `pid_f3`, `ideo3`; 5th/95th percentile trim). All values
#'     are positive. Use with `weights = weight` when constructing a survey
#'     object.}
#'   \item{repwt_1}{Numeric. Quasi-randomization bootstrap replicate weight 1.
#'     Pass all 200 `repwt_*` columns to `surveycore::as_survey_nonprob()` as
#'     `repweights` for variance estimation.}
#'   \item{repwt_2}{Numeric. Quasi-randomization bootstrap replicate weight 2.}
#'   \item{repwt_3}{Numeric. Quasi-randomization bootstrap replicate weight 3.}
#'   \item{repwt_4}{Numeric. Quasi-randomization bootstrap replicate weight 4.}
#'   \item{repwt_5}{Numeric. Quasi-randomization bootstrap replicate weight 5.}
#'   \item{repwt_6}{Numeric. Quasi-randomization bootstrap replicate weight 6.}
#'   \item{repwt_7}{Numeric. Quasi-randomization bootstrap replicate weight 7.}
#'   \item{repwt_8}{Numeric. Quasi-randomization bootstrap replicate weight 8.}
#'   \item{repwt_9}{Numeric. Quasi-randomization bootstrap replicate weight 9.}
#'   \item{repwt_10}{Numeric. Quasi-randomization bootstrap replicate weight 10.}
#'   \item{repwt_11}{Numeric. Quasi-randomization bootstrap replicate weight 11.}
#'   \item{repwt_12}{Numeric. Quasi-randomization bootstrap replicate weight 12.}
#'   \item{repwt_13}{Numeric. Quasi-randomization bootstrap replicate weight 13.}
#'   \item{repwt_14}{Numeric. Quasi-randomization bootstrap replicate weight 14.}
#'   \item{repwt_15}{Numeric. Quasi-randomization bootstrap replicate weight 15.}
#'   \item{repwt_16}{Numeric. Quasi-randomization bootstrap replicate weight 16.}
#'   \item{repwt_17}{Numeric. Quasi-randomization bootstrap replicate weight 17.}
#'   \item{repwt_18}{Numeric. Quasi-randomization bootstrap replicate weight 18.}
#'   \item{repwt_19}{Numeric. Quasi-randomization bootstrap replicate weight 19.}
#'   \item{repwt_20}{Numeric. Quasi-randomization bootstrap replicate weight 20.}
#'   \item{repwt_21}{Numeric. Quasi-randomization bootstrap replicate weight 21.}
#'   \item{repwt_22}{Numeric. Quasi-randomization bootstrap replicate weight 22.}
#'   \item{repwt_23}{Numeric. Quasi-randomization bootstrap replicate weight 23.}
#'   \item{repwt_24}{Numeric. Quasi-randomization bootstrap replicate weight 24.}
#'   \item{repwt_25}{Numeric. Quasi-randomization bootstrap replicate weight 25.}
#'   \item{repwt_26}{Numeric. Quasi-randomization bootstrap replicate weight 26.}
#'   \item{repwt_27}{Numeric. Quasi-randomization bootstrap replicate weight 27.}
#'   \item{repwt_28}{Numeric. Quasi-randomization bootstrap replicate weight 28.}
#'   \item{repwt_29}{Numeric. Quasi-randomization bootstrap replicate weight 29.}
#'   \item{repwt_30}{Numeric. Quasi-randomization bootstrap replicate weight 30.}
#'   \item{repwt_31}{Numeric. Quasi-randomization bootstrap replicate weight 31.}
#'   \item{repwt_32}{Numeric. Quasi-randomization bootstrap replicate weight 32.}
#'   \item{repwt_33}{Numeric. Quasi-randomization bootstrap replicate weight 33.}
#'   \item{repwt_34}{Numeric. Quasi-randomization bootstrap replicate weight 34.}
#'   \item{repwt_35}{Numeric. Quasi-randomization bootstrap replicate weight 35.}
#'   \item{repwt_36}{Numeric. Quasi-randomization bootstrap replicate weight 36.}
#'   \item{repwt_37}{Numeric. Quasi-randomization bootstrap replicate weight 37.}
#'   \item{repwt_38}{Numeric. Quasi-randomization bootstrap replicate weight 38.}
#'   \item{repwt_39}{Numeric. Quasi-randomization bootstrap replicate weight 39.}
#'   \item{repwt_40}{Numeric. Quasi-randomization bootstrap replicate weight 40.}
#'   \item{repwt_41}{Numeric. Quasi-randomization bootstrap replicate weight 41.}
#'   \item{repwt_42}{Numeric. Quasi-randomization bootstrap replicate weight 42.}
#'   \item{repwt_43}{Numeric. Quasi-randomization bootstrap replicate weight 43.}
#'   \item{repwt_44}{Numeric. Quasi-randomization bootstrap replicate weight 44.}
#'   \item{repwt_45}{Numeric. Quasi-randomization bootstrap replicate weight 45.}
#'   \item{repwt_46}{Numeric. Quasi-randomization bootstrap replicate weight 46.}
#'   \item{repwt_47}{Numeric. Quasi-randomization bootstrap replicate weight 47.}
#'   \item{repwt_48}{Numeric. Quasi-randomization bootstrap replicate weight 48.}
#'   \item{repwt_49}{Numeric. Quasi-randomization bootstrap replicate weight 49.}
#'   \item{repwt_50}{Numeric. Quasi-randomization bootstrap replicate weight 50.}
#'   \item{repwt_51}{Numeric. Quasi-randomization bootstrap replicate weight 51.}
#'   \item{repwt_52}{Numeric. Quasi-randomization bootstrap replicate weight 52.}
#'   \item{repwt_53}{Numeric. Quasi-randomization bootstrap replicate weight 53.}
#'   \item{repwt_54}{Numeric. Quasi-randomization bootstrap replicate weight 54.}
#'   \item{repwt_55}{Numeric. Quasi-randomization bootstrap replicate weight 55.}
#'   \item{repwt_56}{Numeric. Quasi-randomization bootstrap replicate weight 56.}
#'   \item{repwt_57}{Numeric. Quasi-randomization bootstrap replicate weight 57.}
#'   \item{repwt_58}{Numeric. Quasi-randomization bootstrap replicate weight 58.}
#'   \item{repwt_59}{Numeric. Quasi-randomization bootstrap replicate weight 59.}
#'   \item{repwt_60}{Numeric. Quasi-randomization bootstrap replicate weight 60.}
#'   \item{repwt_61}{Numeric. Quasi-randomization bootstrap replicate weight 61.}
#'   \item{repwt_62}{Numeric. Quasi-randomization bootstrap replicate weight 62.}
#'   \item{repwt_63}{Numeric. Quasi-randomization bootstrap replicate weight 63.}
#'   \item{repwt_64}{Numeric. Quasi-randomization bootstrap replicate weight 64.}
#'   \item{repwt_65}{Numeric. Quasi-randomization bootstrap replicate weight 65.}
#'   \item{repwt_66}{Numeric. Quasi-randomization bootstrap replicate weight 66.}
#'   \item{repwt_67}{Numeric. Quasi-randomization bootstrap replicate weight 67.}
#'   \item{repwt_68}{Numeric. Quasi-randomization bootstrap replicate weight 68.}
#'   \item{repwt_69}{Numeric. Quasi-randomization bootstrap replicate weight 69.}
#'   \item{repwt_70}{Numeric. Quasi-randomization bootstrap replicate weight 70.}
#'   \item{repwt_71}{Numeric. Quasi-randomization bootstrap replicate weight 71.}
#'   \item{repwt_72}{Numeric. Quasi-randomization bootstrap replicate weight 72.}
#'   \item{repwt_73}{Numeric. Quasi-randomization bootstrap replicate weight 73.}
#'   \item{repwt_74}{Numeric. Quasi-randomization bootstrap replicate weight 74.}
#'   \item{repwt_75}{Numeric. Quasi-randomization bootstrap replicate weight 75.}
#'   \item{repwt_76}{Numeric. Quasi-randomization bootstrap replicate weight 76.}
#'   \item{repwt_77}{Numeric. Quasi-randomization bootstrap replicate weight 77.}
#'   \item{repwt_78}{Numeric. Quasi-randomization bootstrap replicate weight 78.}
#'   \item{repwt_79}{Numeric. Quasi-randomization bootstrap replicate weight 79.}
#'   \item{repwt_80}{Numeric. Quasi-randomization bootstrap replicate weight 80.}
#'   \item{repwt_81}{Numeric. Quasi-randomization bootstrap replicate weight 81.}
#'   \item{repwt_82}{Numeric. Quasi-randomization bootstrap replicate weight 82.}
#'   \item{repwt_83}{Numeric. Quasi-randomization bootstrap replicate weight 83.}
#'   \item{repwt_84}{Numeric. Quasi-randomization bootstrap replicate weight 84.}
#'   \item{repwt_85}{Numeric. Quasi-randomization bootstrap replicate weight 85.}
#'   \item{repwt_86}{Numeric. Quasi-randomization bootstrap replicate weight 86.}
#'   \item{repwt_87}{Numeric. Quasi-randomization bootstrap replicate weight 87.}
#'   \item{repwt_88}{Numeric. Quasi-randomization bootstrap replicate weight 88.}
#'   \item{repwt_89}{Numeric. Quasi-randomization bootstrap replicate weight 89.}
#'   \item{repwt_90}{Numeric. Quasi-randomization bootstrap replicate weight 90.}
#'   \item{repwt_91}{Numeric. Quasi-randomization bootstrap replicate weight 91.}
#'   \item{repwt_92}{Numeric. Quasi-randomization bootstrap replicate weight 92.}
#'   \item{repwt_93}{Numeric. Quasi-randomization bootstrap replicate weight 93.}
#'   \item{repwt_94}{Numeric. Quasi-randomization bootstrap replicate weight 94.}
#'   \item{repwt_95}{Numeric. Quasi-randomization bootstrap replicate weight 95.}
#'   \item{repwt_96}{Numeric. Quasi-randomization bootstrap replicate weight 96.}
#'   \item{repwt_97}{Numeric. Quasi-randomization bootstrap replicate weight 97.}
#'   \item{repwt_98}{Numeric. Quasi-randomization bootstrap replicate weight 98.}
#'   \item{repwt_99}{Numeric. Quasi-randomization bootstrap replicate weight 99.}
#'   \item{repwt_100}{Numeric. Quasi-randomization bootstrap replicate weight 100.}
#'   \item{repwt_101}{Numeric. Quasi-randomization bootstrap replicate weight 101.}
#'   \item{repwt_102}{Numeric. Quasi-randomization bootstrap replicate weight 102.}
#'   \item{repwt_103}{Numeric. Quasi-randomization bootstrap replicate weight 103.}
#'   \item{repwt_104}{Numeric. Quasi-randomization bootstrap replicate weight 104.}
#'   \item{repwt_105}{Numeric. Quasi-randomization bootstrap replicate weight 105.}
#'   \item{repwt_106}{Numeric. Quasi-randomization bootstrap replicate weight 106.}
#'   \item{repwt_107}{Numeric. Quasi-randomization bootstrap replicate weight 107.}
#'   \item{repwt_108}{Numeric. Quasi-randomization bootstrap replicate weight 108.}
#'   \item{repwt_109}{Numeric. Quasi-randomization bootstrap replicate weight 109.}
#'   \item{repwt_110}{Numeric. Quasi-randomization bootstrap replicate weight 110.}
#'   \item{repwt_111}{Numeric. Quasi-randomization bootstrap replicate weight 111.}
#'   \item{repwt_112}{Numeric. Quasi-randomization bootstrap replicate weight 112.}
#'   \item{repwt_113}{Numeric. Quasi-randomization bootstrap replicate weight 113.}
#'   \item{repwt_114}{Numeric. Quasi-randomization bootstrap replicate weight 114.}
#'   \item{repwt_115}{Numeric. Quasi-randomization bootstrap replicate weight 115.}
#'   \item{repwt_116}{Numeric. Quasi-randomization bootstrap replicate weight 116.}
#'   \item{repwt_117}{Numeric. Quasi-randomization bootstrap replicate weight 117.}
#'   \item{repwt_118}{Numeric. Quasi-randomization bootstrap replicate weight 118.}
#'   \item{repwt_119}{Numeric. Quasi-randomization bootstrap replicate weight 119.}
#'   \item{repwt_120}{Numeric. Quasi-randomization bootstrap replicate weight 120.}
#'   \item{repwt_121}{Numeric. Quasi-randomization bootstrap replicate weight 121.}
#'   \item{repwt_122}{Numeric. Quasi-randomization bootstrap replicate weight 122.}
#'   \item{repwt_123}{Numeric. Quasi-randomization bootstrap replicate weight 123.}
#'   \item{repwt_124}{Numeric. Quasi-randomization bootstrap replicate weight 124.}
#'   \item{repwt_125}{Numeric. Quasi-randomization bootstrap replicate weight 125.}
#'   \item{repwt_126}{Numeric. Quasi-randomization bootstrap replicate weight 126.}
#'   \item{repwt_127}{Numeric. Quasi-randomization bootstrap replicate weight 127.}
#'   \item{repwt_128}{Numeric. Quasi-randomization bootstrap replicate weight 128.}
#'   \item{repwt_129}{Numeric. Quasi-randomization bootstrap replicate weight 129.}
#'   \item{repwt_130}{Numeric. Quasi-randomization bootstrap replicate weight 130.}
#'   \item{repwt_131}{Numeric. Quasi-randomization bootstrap replicate weight 131.}
#'   \item{repwt_132}{Numeric. Quasi-randomization bootstrap replicate weight 132.}
#'   \item{repwt_133}{Numeric. Quasi-randomization bootstrap replicate weight 133.}
#'   \item{repwt_134}{Numeric. Quasi-randomization bootstrap replicate weight 134.}
#'   \item{repwt_135}{Numeric. Quasi-randomization bootstrap replicate weight 135.}
#'   \item{repwt_136}{Numeric. Quasi-randomization bootstrap replicate weight 136.}
#'   \item{repwt_137}{Numeric. Quasi-randomization bootstrap replicate weight 137.}
#'   \item{repwt_138}{Numeric. Quasi-randomization bootstrap replicate weight 138.}
#'   \item{repwt_139}{Numeric. Quasi-randomization bootstrap replicate weight 139.}
#'   \item{repwt_140}{Numeric. Quasi-randomization bootstrap replicate weight 140.}
#'   \item{repwt_141}{Numeric. Quasi-randomization bootstrap replicate weight 141.}
#'   \item{repwt_142}{Numeric. Quasi-randomization bootstrap replicate weight 142.}
#'   \item{repwt_143}{Numeric. Quasi-randomization bootstrap replicate weight 143.}
#'   \item{repwt_144}{Numeric. Quasi-randomization bootstrap replicate weight 144.}
#'   \item{repwt_145}{Numeric. Quasi-randomization bootstrap replicate weight 145.}
#'   \item{repwt_146}{Numeric. Quasi-randomization bootstrap replicate weight 146.}
#'   \item{repwt_147}{Numeric. Quasi-randomization bootstrap replicate weight 147.}
#'   \item{repwt_148}{Numeric. Quasi-randomization bootstrap replicate weight 148.}
#'   \item{repwt_149}{Numeric. Quasi-randomization bootstrap replicate weight 149.}
#'   \item{repwt_150}{Numeric. Quasi-randomization bootstrap replicate weight 150.}
#'   \item{repwt_151}{Numeric. Quasi-randomization bootstrap replicate weight 151.}
#'   \item{repwt_152}{Numeric. Quasi-randomization bootstrap replicate weight 152.}
#'   \item{repwt_153}{Numeric. Quasi-randomization bootstrap replicate weight 153.}
#'   \item{repwt_154}{Numeric. Quasi-randomization bootstrap replicate weight 154.}
#'   \item{repwt_155}{Numeric. Quasi-randomization bootstrap replicate weight 155.}
#'   \item{repwt_156}{Numeric. Quasi-randomization bootstrap replicate weight 156.}
#'   \item{repwt_157}{Numeric. Quasi-randomization bootstrap replicate weight 157.}
#'   \item{repwt_158}{Numeric. Quasi-randomization bootstrap replicate weight 158.}
#'   \item{repwt_159}{Numeric. Quasi-randomization bootstrap replicate weight 159.}
#'   \item{repwt_160}{Numeric. Quasi-randomization bootstrap replicate weight 160.}
#'   \item{repwt_161}{Numeric. Quasi-randomization bootstrap replicate weight 161.}
#'   \item{repwt_162}{Numeric. Quasi-randomization bootstrap replicate weight 162.}
#'   \item{repwt_163}{Numeric. Quasi-randomization bootstrap replicate weight 163.}
#'   \item{repwt_164}{Numeric. Quasi-randomization bootstrap replicate weight 164.}
#'   \item{repwt_165}{Numeric. Quasi-randomization bootstrap replicate weight 165.}
#'   \item{repwt_166}{Numeric. Quasi-randomization bootstrap replicate weight 166.}
#'   \item{repwt_167}{Numeric. Quasi-randomization bootstrap replicate weight 167.}
#'   \item{repwt_168}{Numeric. Quasi-randomization bootstrap replicate weight 168.}
#'   \item{repwt_169}{Numeric. Quasi-randomization bootstrap replicate weight 169.}
#'   \item{repwt_170}{Numeric. Quasi-randomization bootstrap replicate weight 170.}
#'   \item{repwt_171}{Numeric. Quasi-randomization bootstrap replicate weight 171.}
#'   \item{repwt_172}{Numeric. Quasi-randomization bootstrap replicate weight 172.}
#'   \item{repwt_173}{Numeric. Quasi-randomization bootstrap replicate weight 173.}
#'   \item{repwt_174}{Numeric. Quasi-randomization bootstrap replicate weight 174.}
#'   \item{repwt_175}{Numeric. Quasi-randomization bootstrap replicate weight 175.}
#'   \item{repwt_176}{Numeric. Quasi-randomization bootstrap replicate weight 176.}
#'   \item{repwt_177}{Numeric. Quasi-randomization bootstrap replicate weight 177.}
#'   \item{repwt_178}{Numeric. Quasi-randomization bootstrap replicate weight 178.}
#'   \item{repwt_179}{Numeric. Quasi-randomization bootstrap replicate weight 179.}
#'   \item{repwt_180}{Numeric. Quasi-randomization bootstrap replicate weight 180.}
#'   \item{repwt_181}{Numeric. Quasi-randomization bootstrap replicate weight 181.}
#'   \item{repwt_182}{Numeric. Quasi-randomization bootstrap replicate weight 182.}
#'   \item{repwt_183}{Numeric. Quasi-randomization bootstrap replicate weight 183.}
#'   \item{repwt_184}{Numeric. Quasi-randomization bootstrap replicate weight 184.}
#'   \item{repwt_185}{Numeric. Quasi-randomization bootstrap replicate weight 185.}
#'   \item{repwt_186}{Numeric. Quasi-randomization bootstrap replicate weight 186.}
#'   \item{repwt_187}{Numeric. Quasi-randomization bootstrap replicate weight 187.}
#'   \item{repwt_188}{Numeric. Quasi-randomization bootstrap replicate weight 188.}
#'   \item{repwt_189}{Numeric. Quasi-randomization bootstrap replicate weight 189.}
#'   \item{repwt_190}{Numeric. Quasi-randomization bootstrap replicate weight 190.}
#'   \item{repwt_191}{Numeric. Quasi-randomization bootstrap replicate weight 191.}
#'   \item{repwt_192}{Numeric. Quasi-randomization bootstrap replicate weight 192.}
#'   \item{repwt_193}{Numeric. Quasi-randomization bootstrap replicate weight 193.}
#'   \item{repwt_194}{Numeric. Quasi-randomization bootstrap replicate weight 194.}
#'   \item{repwt_195}{Numeric. Quasi-randomization bootstrap replicate weight 195.}
#'   \item{repwt_196}{Numeric. Quasi-randomization bootstrap replicate weight 196.}
#'   \item{repwt_197}{Numeric. Quasi-randomization bootstrap replicate weight 197.}
#'   \item{repwt_198}{Numeric. Quasi-randomization bootstrap replicate weight 198.}
#'   \item{repwt_199}{Numeric. Quasi-randomization bootstrap replicate weight 199.}
#'   \item{repwt_200}{Numeric. Quasi-randomization bootstrap replicate weight 200.}
#' }
#'
#' @source Derived from the Pew Research Center 2016 opt-in sample SPSS file.
#'   See `data-raw/pew-2016-optin.R` for the preparation script.
#' @seealso [pew_2016_synth_pop]
#' @keywords datasets
"pew_2016_optin"

# ============================================================================
# pew_2016_synth_pop + pew_2016_synth_pop_svy
# ============================================================================

#' Pew 2016 ATP synthetic population
#'
#' @title Pew 2016 ATP synthetic population
#' @description A 20,000-row synthetic population dataset derived from the 2016
#'   American Trends Panel (ATP) probability sample, used as the reference
#'   population for the Mercer, Lau and Kennedy (2018) opt-in weighting study.
#'   Population truth values for the 13 benchmark variables can be computed
#'   as unweighted means of the dichotomized benchmark columns.
#'
#'   Value labels are preserved as named numeric attributes on each column
#'   (accessible via `attr(pew_2016_synth_pop$gender, "labels")`). Variable
#'   labels are stored in the `"label"` attribute of each column.
#'
#'   Binary benchmark variables (shared with [pew_2016_optin]) are dichotomised
#'   to `1` = positive response, `0` = negative response; no Refused codes
#'   exist in this dataset.
#'
#'
#' @format A data frame with 20,000 rows and 43 columns:
#' \describe{
#'   \item{id}{Numeric. Row identifier.}
#'   \item{gender}{Numeric. `1` = Male, `2` = Female.}
#'   \item{age}{Numeric (continuous). Age in years.}
#'   \item{racethn}{Numeric. Race/ethnicity: `1` = White non-Hispanic,
#'     `2` = Black non-Hispanic, `3` = Hispanic, `4` = Asian,
#'     `5` = Other race. No Refused category.}
#'   \item{educcat5}{Numeric. 5-category education: `1` = Less than HS,
#'     `2` = HS Grad, `3` = Some college, `4` = College grad,
#'     `5` = Postgraduate. No Refused category.}
#'   \item{division}{Numeric. Census division, **alphabetical coding**: `1` =
#'     East North Central, `2` = East South Central, `3` = Middle Atlantic,
#'     `4` = Mountain, `5` = New England, `6` = Pacific, `7` = South
#'     Atlantic, `8` = West North Central, `9` = West South Central.
#'     Coding matches [pew_2016_optin].}
#'   \item{marital_acs}{Numeric. Marital status (ACS-sourced).}
#'   \item{hhsizecat}{Numeric. Household size category.}
#'   \item{childrencat}{Numeric. Number of children category.}
#'   \item{citizen_rec}{Numeric. U.S. citizenship.}
#'   \item{born_acs}{Numeric. Born in the U.S.}
#'   \item{faminc5}{Numeric. Family income (5 categories).}
#'   \item{employed}{Numeric. Employment status (3 categories).}
#'   \item{worker_class}{Numeric. Employment sector (class of worker).}
#'   \item{usual_hrs_per_week}{Numeric. Hours worked per week.}
#'   \item{hours_vary}{Numeric. Hours worked per week vary.}
#'   \item{mil_acs_rec}{Numeric. Military status.}
#'   \item{home_acs_rec}{Numeric. Home ownership.}
#'   \item{metropolitan}{Numeric. Lives in a metropolitan statistical area.}
#'   \item{internet_access}{Numeric. Household internet access.}
#'   \item{fdstmp_cps}{Integer. Household received food stamps: `1` = Yes,
#'     `0` = No.}
#'   \item{tenure_acs}{Numeric. Lived in home one year ago.}
#'   \item{pub_off_cps}{Integer. Contacted public official in last 12 months:
#'     `1` = Yes, `0` = No.}
#'   \item{boycott}{Numeric. Boycotted a product/service in last 12 months.}
#'   \item{comgrp_cps}{Integer. Participated in community group in last 12
#'     months: `1` = Yes, `0` = No.}
#'   \item{talk_cps}{Numeric. Frequency of talking with neighbors (ordinal):
#'     `1` = Basically every day, `2` = A few times a week, `3` = A few times
#'     a month, `4` = Rarely, `5` = Not at all.}
#'   \item{trust_cps}{Numeric. Trust in neighbors (ordinal): `1` = All of
#'     the people, `2` = Most, `3` = Some, `4` = None.}
#'   \item{tablet_cps}{Integer. Household has a tablet or e-reader:
#'     `1` = Yes, `0` = No.}
#'   \item{textim_cps}{Integer. Uses texting or instant messaging:
#'     `1` = Yes, `0` = No.}
#'   \item{social_cps}{Integer. Uses social networking: `1` = Yes, `0` = No.}
#'   \item{volsum}{Integer. Volunteered in last 12 months: `1` = Volunteered,
#'     `0` = Did not volunteer.}
#'   \item{registered}{Integer. Registered to vote: `1` = Yes, `0` = No.
#'     Recoded from the raw SPSS file (original: `1` = No, `2` = Yes).}
#'   \item{vote14}{Integer. Voted in 2014: `1` = Voted, `0` = Did not vote.
#'     Recoded from the raw SPSS file (original: `1` = Did not vote,
#'     `2` = Voted).}
#'   \item{partyscale5}{Numeric. Party ID: `1` = Republican,
#'     `2` = Lean Republican, `3` = Ind/No Lean, `4` = Lean Democrat,
#'     `5` = Democrat.}
#'   \item{religcat}{Numeric. Religion category (6 levels).}
#'   \item{ideo3}{Numeric. Ideology: `1` = Liberal, `2` = Moderate,
#'     `3` = Conservative.}
#'   \item{folgov}{Numeric. Follows government/public affairs (ordinal):
#'     `1` = Most of the time, `2` = Some of the time, `3` = Only now and
#'     then, `4` = Hardly at all.}
#'   \item{owngun_gss}{Integer. Gun in home: `1` = Yes, `0` = No.}
#'   \item{sex}{Factor. Derived from `gender`: `1` = `"Male"`, `2` =
#'     `"Female"`. Levels: `c("Male", "Female")`.}
#'   \item{race_f4}{Factor. Derived from `racethn`: `1` = `"White"`,
#'     `2` = `"Black"`, `3` = `"Hispanic"`, `4`/`5` = `"Other"`. Levels:
#'     `c("White", "Black", "Hispanic", "Other")`.}
#'   \item{edu_f3}{Factor. Derived from `educcat5`: `1` = `"Less than HS"`,
#'     `2:3` = `"HS/Some college"`, `4:5` = `"College+"`. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`.}
#'   \item{pid_f3}{Factor. Derived from `partyscale5`: `1:2` =
#'     `"Republican"`, `3` = `"Independent"`, `4:5` = `"Democrat"`. Levels:
#'     `c("Republican", "Independent", "Democrat")`.}
#'   \item{age_f3}{Factor. Derived from `age` using
#'     `cut(age, breaks = c(18, 35, 55, Inf), right = FALSE)`. Levels:
#'     `c("18-34", "35-54", "55+")`.}
#' }
#'
#' @source Derived from the Pew Research Center 2016 ATP synthetic population
#'   SPSS file. See `data-raw/pew-2016-synth-pop.R` for the preparation script.
#' @seealso [pew_2016_optin]
#' @keywords datasets
"pew_2016_synth_pop"

# ============================================================================
# ns_wave1 + ns_wave1_svy
# ============================================================================

#' National Survey Wave 1 with harmonized demographic columns
#'
#' @description
#' The National Survey Wave 1 dataset, obtained from `surveycore::ns_wave1`.
#' All 6,422 respondents and 171 original columns are retained. The `gender`
#' column is kept as numeric. Five general-purpose derived columns are added:
#' `sex` (factor from `gender`), `age_f3` (factor from `age`), `race_f4`
#' (factor from `race_ethnicity` and `hispanic`), `edu_f3` (factor from
#' `education`), and `pid_f3` (factor from `pid3`). Eight Nationscape raking
#' recode columns (`ns_*`) are also added as calibration variables used to
#' replicate Nationscape's weighting procedure. Original source columns are
#' kept unchanged.
#'
#' The `weight` column contains the raked+trimmed survey weight that replicates
#' Nationscape's published weighting procedure (Newton-Raphson, 10 marginal
#' dimensions, 5th/95th percentile trim; Pearson r = 0.996 vs. published
#' weights). To construct a `survey_nonprob` for analysis:
#' ```r
#' data(ns_wave1)
#' ns_design <- surveycore::as_survey_nonprob(
#'   ns_wave1, weights = "weight"
#' )
#' ```
#'
#' Some respondents have `NA` in `race_f4` (those who reported "some other
#' race" with no Hispanic origin, which cannot be mapped to a standard category).
#'
#' @format
#' ## `ns_wave1`
#' A data frame with 6,422 rows and 185 columns. All 171 original columns from
#' `surveycore::ns_wave1` are retained, including `gender` as numeric; fourteen
#' new columns are appended: six general-purpose derived columns (`sex`,
#' `age_f3`, `race_f4`, `edu_f3`, `pid_f3`, `hh_income_f9`) and eight
#' Nationscape raking recode columns (`ns_region`, `ns_hispanic`, `ns_race`,
#' `ns_age`, `ns_language`, `ns_foreign_born`, `ns_income`, `ns_vote_2016`):
#' \describe{
#'   \item{response_id}{Character. Respondent identifier.}
#'   \item{start_date}{Character. Survey start date.}
#'   \item{right_track}{Numeric. Right track / wrong track opinion.}
#'   \item{economy_better}{Numeric. Economy better/worse opinion.}
#'   \item{interest}{Numeric. Political interest.}
#'   \item{registration}{Numeric. Voter registration status.}
#'   \item{news_sources_facebook}{Numeric. Gets news from Facebook.}
#'   \item{news_sources_cnn}{Numeric. Gets news from CNN.}
#'   \item{news_sources_msnbc}{Numeric. Gets news from MSNBC.}
#'   \item{news_sources_fox}{Numeric. Gets news from Fox News.}
#'   \item{news_sources_network}{Numeric. Gets news from network TV.}
#'   \item{news_sources_localtv}{Numeric. Gets news from local TV.}
#'   \item{news_sources_telemundo}{Numeric. Gets news from Telemundo.}
#'   \item{news_sources_npr}{Numeric. Gets news from NPR.}
#'   \item{news_sources_amtalk}{Numeric. Gets news from AM talk radio.}
#'   \item{news_sources_new_york_times}{Numeric. Gets news from New York Times.}
#'   \item{news_sources_local_newspaper}{Numeric. Gets news from local newspaper.}
#'   \item{news_sources_other}{Numeric. Gets news from other sources.}
#'   \item{news_sources_other_TEXT}{Character. Other news source (open text).}
#'   \item{pres_approval}{Numeric. Presidential approval.}
#'   \item{vote_intention}{Numeric. 2020 vote intention.}
#'   \item{vote_2016}{Numeric. 2016 presidential vote.}
#'   \item{vote_2016_other_text}{Character. 2016 vote other (open text).}
#'   \item{consider_trump}{Numeric. Considers voting for Trump.}
#'   \item{not_trump}{Numeric. Would not vote for Trump.}
#'   \item{primary_party}{Numeric. Primary party preference.}
#'   \item{group_favorability_whites}{Numeric. Favorability toward Whites.}
#'   \item{group_favorability_blacks}{Numeric. Favorability toward Blacks.}
#'   \item{group_favorability_latinos}{Numeric. Favorability toward Latinos.}
#'   \item{group_favorability_asians}{Numeric. Favorability toward Asians.}
#'   \item{group_favorability_christians}{Numeric. Favorability toward Christians.}
#'   \item{group_favorability_socialists}{Numeric. Favorability toward Socialists.}
#'   \item{group_favorability_muslims}{Numeric. Favorability toward Muslims.}
#'   \item{group_favorability_labor_unions}{Numeric. Favorability toward labor unions.}
#'   \item{group_favorability_the_police}{Numeric. Favorability toward the police.}
#'   \item{group_favorability_undocumented}{Numeric. Favorability toward undocumented immigrants.}
#'   \item{group_favorability_lgbt}{Numeric. Favorability toward LGBT people.}
#'   \item{group_favorability_republicans}{Numeric. Favorability toward Republicans.}
#'   \item{group_favorability_democrats}{Numeric. Favorability toward Democrats.}
#'   \item{cand_favorability_trump}{Numeric. Favorability toward Trump.}
#'   \item{cand_favorability_obama}{Numeric. Favorability toward Obama.}
#'   \item{cand_favorability_cortez}{Numeric. Favorability toward Cortez.}
#'   \item{cand_favorability_biden}{Numeric. Favorability toward Biden.}
#'   \item{cand_favorability_harris}{Numeric. Favorability toward Harris.}
#'   \item{cand_favorability_buttigieg}{Numeric. Favorability toward Buttigieg.}
#'   \item{cand_favorability_warren}{Numeric. Favorability toward Warren.}
#'   \item{cand_favorability_sanders}{Numeric. Favorability toward Sanders.}
#'   \item{cand_favorability_pence}{Numeric. Favorability toward Pence.}
#'   \item{dem_vote_intent}{Numeric. Democratic primary vote intent.}
#'   \item{dem_vote_intent_TEXT}{Character. Democratic primary vote intent (open text).}
#'   \item{rank_dems_1}{Numeric. Ranked choice: 1st choice Democrat.}
#'   \item{rank_dems_2}{Numeric. Ranked choice: 2nd choice Democrat.}
#'   \item{rank_dems_3}{Numeric. Ranked choice: 3rd choice Democrat.}
#'   \item{replace_trump}{Numeric. Wants to replace Trump.}
#'   \item{house_intent}{Numeric. House vote intent.}
#'   \item{senate_intent}{Numeric. Senate vote intent.}
#'   \item{governor_intent}{Numeric. Governor vote intent.}
#'   \item{trump_biden}{Numeric. Trump vs. Biden preference.}
#'   \item{trump_sanders}{Numeric. Trump vs. Sanders preference.}
#'   \item{trump_harris}{Numeric. Trump vs. Harris preference.}
#'   \item{trump_warren}{Numeric. Trump vs. Warren preference.}
#'   \item{trump_buttigieg}{Numeric. Trump vs. Buttigieg preference.}
#'   \item{trump_booker}{Numeric. Trump vs. Booker preference.}
#'   \item{trump_castro}{Numeric. Trump vs. Castro preference.}
#'   \item{trump_gabbard}{Numeric. Trump vs. Gabbard preference.}
#'   \item{trump_gillibrand}{Numeric. Trump vs. Gillibrand preference.}
#'   \item{trump_orourke}{Numeric. Trump vs. O'Rourke preference.}
#'   \item{pence_biden}{Numeric. Pence vs. Biden preference.}
#'   \item{pence_buttigieg}{Numeric. Pence vs. Buttigieg preference.}
#'   \item{pence_harris}{Numeric. Pence vs. Harris preference.}
#'   \item{pence_sanders}{Numeric. Pence vs. Sanders preference.}
#'   \item{pence_warren}{Numeric. Pence vs. Warren preference.}
#'   \item{cand_truth_donald_trump}{Numeric. Candidate truth rating: Trump.}
#'   \item{cand_truth_elizabeth_warren}{Numeric. Candidate truth rating: Warren.}
#'   \item{cand_truth_joe_biden}{Numeric. Candidate truth rating: Biden.}
#'   \item{cand_truth_bernie_sanders}{Numeric. Candidate truth rating: Sanders.}
#'   \item{cand_truth_pete_buttigieg}{Numeric. Candidate truth rating: Buttigieg.}
#'   \item{cand_truth_kamala_harris}{Numeric. Candidate truth rating: Harris.}
#'   \item{cand_facts_donald_trump}{Numeric. Candidate fact rating: Trump.}
#'   \item{cand_facts_elizabeth_warren}{Numeric. Candidate fact rating: Warren.}
#'   \item{cand_facts_joe_biden}{Numeric. Candidate fact rating: Biden.}
#'   \item{cand_facts_bernie_sanders}{Numeric. Candidate fact rating: Sanders.}
#'   \item{cand_facts_pete_buttigieg}{Numeric. Candidate fact rating: Buttigieg.}
#'   \item{cand_facts_kamala_harris}{Numeric. Candidate fact rating: Harris.}
#'   \item{racial_attitudes_tryhard}{Numeric. Racial attitude: trying too hard.}
#'   \item{racial_attitudes_generations}{Numeric. Racial attitude: generations.}
#'   \item{racial_attitudes_marry}{Numeric. Racial attitude: intermarriage.}
#'   \item{racial_attitudes_date}{Numeric. Racial attitude: dating.}
#'   \item{gender_attitudes_maleboss}{Numeric. Gender attitude: male boss.}
#'   \item{gender_attitudes_logical}{Numeric. Gender attitude: logical.}
#'   \item{gender_attitudes_opportunity}{Numeric. Gender attitude: opportunity.}
#'   \item{gender_attitudes_complain}{Numeric. Gender attitude: complain.}
#'   \item{discrimination_blacks}{Numeric. Perceived discrimination: Blacks.}
#'   \item{discrimination_whites}{Numeric. Perceived discrimination: Whites.}
#'   \item{discrimination_muslims}{Numeric. Perceived discrimination: Muslims.}
#'   \item{discrimination_christians}{Numeric. Perceived discrimination: Christians.}
#'   \item{discrimination_women}{Numeric. Perceived discrimination: women.}
#'   \item{discrimination_men}{Numeric. Perceived discrimination: men.}
#'   \item{sen_knowledge}{Numeric. Senate knowledge question.}
#'   \item{sc_knowledge}{Numeric. Supreme Court knowledge question.}
#'   \item{pid3}{Numeric. 3-category party identification.}
#'   \item{pid7_legacy}{Numeric. 7-point party identification (legacy version).}
#'   \item{strength_democrat}{Numeric. Strength of Democratic identification.}
#'   \item{strength_republican}{Numeric. Strength of Republican identification.}
#'   \item{lean_independent}{Numeric. Independent party leaning.}
#'   \item{ideo5}{Numeric. Ideology (5-point scale).}
#'   \item{employment}{Numeric. Employment status.}
#'   \item{employment_other_text}{Character. Employment status (open text).}
#'   \item{foreign_born}{Numeric. Born outside the United States.}
#'   \item{language}{Numeric. Primary language.}
#'   \item{religion}{Numeric. Religion.}
#'   \item{religion_other_text}{Character. Religion (open text).}
#'   \item{is_evangelical}{Numeric. Is evangelical or born-again Christian.}
#'   \item{orientation_group}{Numeric. Sexual orientation.}
#'   \item{in_union}{Numeric. Member of a labor union.}
#'   \item{household_gun_owner}{Numeric. Household gun ownership.}
#'   \item{wall}{Numeric. Opinion on border wall.}
#'   \item{cap_carbon}{Numeric. Opinion on carbon cap.}
#'   \item{environment}{Numeric. Environmental opinion.}
#'   \item{guns_bg}{Numeric. Opinion on gun background checks.}
#'   \item{mctaxes}{Numeric. Opinion on middle-class taxes.}
#'   \item{estate_tax}{Numeric. Opinion on estate tax.}
#'   \item{raise_upper_tax}{Numeric. Opinion on raising upper-income taxes.}
#'   \item{college}{Numeric. Opinion on college affordability.}
#'   \item{abortion_waiting}{Numeric. Opinion on abortion waiting period.}
#'   \item{abortion_never}{Numeric. Opinion on banning abortion.}
#'   \item{abortion_conditions}{Numeric. Opinion on abortion with conditions.}
#'   \item{late_term_abortion}{Numeric. Opinion on late-term abortion.}
#'   \item{abortion_insurance}{Numeric. Opinion on abortion insurance coverage.}
#'   \item{guaranteed_jobs}{Numeric. Opinion on guaranteed jobs program.}
#'   \item{green_new_deal}{Numeric. Opinion on Green New Deal.}
#'   \item{gun_registry}{Numeric. Opinion on gun registry.}
#'   \item{immigration_separation}{Numeric. Opinion on family separation policy.}
#'   \item{immigration_system}{Numeric. Opinion on immigration system.}
#'   \item{immigration_wire}{Numeric. Opinion on border wire.}
#'   \item{impeach_trump}{Numeric. Opinion on Trump impeachment.}
#'   \item{israel}{Numeric. Opinion on Israel policy.}
#'   \item{marijuana}{Numeric. Opinion on marijuana legalization.}
#'   \item{maternityleave}{Numeric. Opinion on maternity leave.}
#'   \item{medicare_for_all}{Numeric. Opinion on Medicare for All.}
#'   \item{military_size}{Numeric. Opinion on military size.}
#'   \item{minwage}{Numeric. Opinion on minimum wage.}
#'   \item{muslimban}{Numeric. Opinion on travel ban.}
#'   \item{oil_and_gas}{Numeric. Opinion on oil and gas development.}
#'   \item{reparations}{Numeric. Opinion on reparations.}
#'   \item{right_to_work}{Numeric. Opinion on right-to-work laws.}
#'   \item{ten_commandments}{Numeric. Opinion on Ten Commandments in schools.}
#'   \item{trade}{Numeric. Opinion on trade policy.}
#'   \item{trans_military}{Numeric. Opinion on transgender military service.}
#'   \item{uctaxes2}{Numeric. Opinion on upper-class taxes (version 2).}
#'   \item{vouchers}{Numeric. Opinion on school vouchers.}
#'   \item{gov_insurance}{Numeric. Opinion on government health insurance.}
#'   \item{public_option}{Numeric. Opinion on public option health insurance.}
#'   \item{health_subsidies}{Numeric. Opinion on health insurance subsidies.}
#'   \item{path_to_citizenship}{Numeric. Opinion on path to citizenship.}
#'   \item{dreamers}{Numeric. Opinion on DACA/Dreamers.}
#'   \item{deportation}{Numeric. Opinion on deportation policy.}
#'   \item{ban_guns}{Numeric. Opinion on banning guns.}
#'   \item{ban_assault_rifles}{Numeric. Opinion on banning assault rifles.}
#'   \item{limit_magazines}{Numeric. Opinion on limiting magazine capacity.}
#'   \item{age}{Numeric. Age in years (original column retained).}
#'   \item{gender}{Numeric. Biological sex: `1` = Male, `2` = Female.
#'     Original integer column retained.}
#'   \item{census_region}{Numeric. Census region.}
#'   \item{hispanic}{Numeric. Hispanic origin (original column retained,
#'     used to derive `race_f4`).}
#'   \item{race_ethnicity}{Numeric. Race/ethnicity code (original column
#'     retained, used to derive `race_f4`).}
#'   \item{household_income}{Numeric. Household income.}
#'   \item{education}{Numeric. Education level code (original column retained,
#'     used to derive `edu_f3`).}
#'   \item{state}{Character. State of residence.}
#'   \item{congress_district}{Numeric. Congressional district.}
#'   \item{weight}{Numeric. Raked survey weight replicating the Nationscape
#'     weighting procedure (Newton-Raphson, 10 marginal dimensions, 5th/95th
#'     percentile trim). Pearson r = 0.996 vs. the original published
#'     Nationscape weight. All values are positive.}
#'   \item{wave_id}{Numeric. Wave identifier.}
#'   \item{sex}{Factor. Derived from `gender`: `1` = `"Male"`, `2` =
#'     `"Female"`, other = `NA`. Levels: `c("Male", "Female")`.}
#'   \item{age_f3}{Factor. Derived from `age` using
#'     `cut(age, breaks = c(18, 35, 55, Inf), right = FALSE)`. Levels:
#'     `c("18-34", "35-54", "55+")`. `NA` for age < 18 or missing.}
#'   \item{race_f4}{Factor. Derived from `race_ethnicity` and `hispanic`:
#'     Hispanic origin takes precedence; `race_ethnicity %in% 3:14` =
#'     `"Other"` (collapses Asian); `race_ethnicity == 15` (some other race,
#'     non-Hispanic) = `NA`. Levels:
#'     `c("White", "Black", "Hispanic", "Other")`. Some `NA` values
#'     (respondents with "some other race", non-Hispanic).}
#'   \item{edu_f3}{Factor. Derived from `education`: `1:3` = `"Less than HS"`,
#'     `4:7` = `"HS/Some college"`, `8:11` = `"College+"`. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`. No `NA` values.}
#'   \item{pid_f3}{Factor. Derived from `pid3`: `1` = `"Democrat"`, `2` =
#'     `"Republican"`, `c(3, 4)` = `"Independent"` (code 4 = Other/No
#'     preference mapped to Independent per Nationscape methodology), other =
#'     `NA`. Levels: `c("Republican", "Independent", "Democrat")`.}
#'   \item{ns_region}{Factor. Census region derived from `census_region`.
#'     Levels: `c("Northeast", "Midwest", "South", "West")`. No `NA` values.}
#'   \item{ns_hispanic}{Factor. Three-category Hispanic ethnicity derived from
#'     `hispanic`: `1` = `"Not Hispanic"`, `2` = `"Mexican"`, `3:15` =
#'     `"Other Hispanic"`. Levels: `c("Not Hispanic", "Mexican", "Other
#'     Hispanic")`. No `NA` values.}
#'   \item{ns_race}{Factor. Four-category race derived from `race_ethnicity`:
#'     `1` = `"White"`, `2` = `"Black"`, `4:14` = `"Asian/Pacific"`,
#'     `c(3, 15)` = `"Other"`. Levels: `c("White", "Black", "Asian/Pacific",
#'     "Other")`. No `NA` values.}
#'   \item{ns_age}{Factor. Seven Nationscape age groups derived from `age`.
#'     Levels: `c("18-23", "24-29", "30-39", "40-49", "50-59", "60-69",
#'     "70+")`. No `NA` values.}
#'   \item{ns_language}{Factor. Household language derived from `language`:
#'     `3` = `"English only"`, `1` = `"Spanish"`, `2` = `"Other"`. Levels:
#'     `c("English only", "Spanish", "Other")`. No `NA` values.}
#'   \item{ns_foreign_born}{Factor. Country of birth derived from
#'     `foreign_born`: `1` = `"United States"`, `2` = `"Other"`. Levels:
#'     `c("United States", "Other")`. No `NA` values.}
#'   \item{ns_income}{Factor. Nine household income brackets derived from
#'     `household_income` (codes `1`–`24`), plus `"No answer"` for `NA`
#'     responses. Levels: `c("<$20k", "$20-35k", "$35-50k", "$50-65k",
#'     "$65-80k", "$80-100k", "$100-125k", "$125-200k", ">=$200k",
#'     "No answer")`. No `NA` values.}
#'   \item{hh_income_f9}{Factor. Nine-bracket household income harmonized
#'     with `cps_2023$hh_income_f9` for use as a `selection` variable in
#'     `ipw()`. Derived from `ns_income`; `"No answer"` is mapped to `NA`.
#'     Levels: `c("<$20k", "$20-35k", "$35-50k", "$50-65k", "$65-80k",
#'     "$80-100k", "$100-125k", "$125-200k", "≥$200k")`.}
#'   \item{ns_vote_2016}{Factor. 2016 presidential vote derived from
#'     `vote_2016`: `1` = `"Trump"`, `2` = `"Clinton"`, `3:5` = `"Other"`,
#'     `6:8` = `"No vote"` (includes ineligible and don't recall). Levels:
#'     `c("Trump", "Clinton", "Other", "No vote")`. No `NA` values.}
#' }
#'
#' @source Derived from `surveycore::ns_wave1`.
#'   See `data-raw/ns-wave1.R` for the construction script.
#' @seealso [gss_2024], [npors_2025_clean], [cps_2023]
#' @keywords datasets
"ns_wave1"

# ============================================================================
# cps_2023
# ============================================================================

#' CPS ASEC 2023 national adult sample with harmonized demographic columns
#'
#' @description
#' A person-level probability sample of U.S. adults drawn from the 2023
#' Current Population Survey Annual Social and Economic Supplement (CPS ASEC,
#' March 2023), obtained from IPUMS-CPS. The CPS ASEC is conducted by the
#' U.S. Census Bureau and Bureau of Labor Statistics and is the primary source
#' for national estimates of income, poverty, and employment. Approximately
#' 10,000 adult respondents (age 18+) are retained after stratified random
#' sampling from the full ASEC extract (stratified by census region and sex,
#' `set.seed(42)`). The person weight `wtfinl` is population-scaled by design;
#' use it directly for IPW reference construction.
#'
#' PSU and stratum identifiers are not released in the public CPS microdata.
#' The 160 SDR replicate weight columns (`repwtp1`-`repwtp160`) are the Census
#' Bureau's official substitute for variance estimation. To use `cps_2023` as
#' a `survey_replicate` reference in `ipw()`, construct it inline:
#' ```r
#' data(cps_2023)
#' cps_ref <- surveycore::as_survey_replicate(
#'   cps_2023,
#'   weights    = "wtfinl",
#'   repweights = paste0("repwtp", 1:160),
#'   type       = "successive-difference",
#'   scale      = 4 / 160,
#'   rscales    = rep(1, 160)
#' )
#' ipw(
#'   ns_wave1, cps_ref,
#'   selection = ~sex + age_f3 + race_f4 + edu_f3 + hh_income_f9,
#'   missing_method = "omit"
#' )
#' ```
#'
#' @format A data frame with approximately 10,000 rows and 187 columns:
#' \describe{
#'   \item{cpsidp}{Character. IPUMS-CPS person identifier (unique within the
#'     extract).}
#'   \item{serial}{Integer. Household serial number.}
#'   \item{wtfinl}{Numeric. CPS ASEC final person weight, population-scaled
#'     by design (values reflect the U.S. adult civilian non-institutional
#'     population). Use directly for IPW reference construction; no scaling
#'     needed.}
#'   \item{repwtp1}{Numeric. Successive-difference replicate weight 1. Pass all 160 `repwtp*` columns to `surveycore::as_survey_replicate()` to construct a variance-estimation design.}
#'   \item{repwtp2}{Numeric. Successive-difference replicate weight 2.}
#'   \item{repwtp3}{Numeric. Successive-difference replicate weight 3.}
#'   \item{repwtp4}{Numeric. Successive-difference replicate weight 4.}
#'   \item{repwtp5}{Numeric. Successive-difference replicate weight 5.}
#'   \item{repwtp6}{Numeric. Successive-difference replicate weight 6.}
#'   \item{repwtp7}{Numeric. Successive-difference replicate weight 7.}
#'   \item{repwtp8}{Numeric. Successive-difference replicate weight 8.}
#'   \item{repwtp9}{Numeric. Successive-difference replicate weight 9.}
#'   \item{repwtp10}{Numeric. Successive-difference replicate weight 10.}
#'   \item{repwtp11}{Numeric. Successive-difference replicate weight 11.}
#'   \item{repwtp12}{Numeric. Successive-difference replicate weight 12.}
#'   \item{repwtp13}{Numeric. Successive-difference replicate weight 13.}
#'   \item{repwtp14}{Numeric. Successive-difference replicate weight 14.}
#'   \item{repwtp15}{Numeric. Successive-difference replicate weight 15.}
#'   \item{repwtp16}{Numeric. Successive-difference replicate weight 16.}
#'   \item{repwtp17}{Numeric. Successive-difference replicate weight 17.}
#'   \item{repwtp18}{Numeric. Successive-difference replicate weight 18.}
#'   \item{repwtp19}{Numeric. Successive-difference replicate weight 19.}
#'   \item{repwtp20}{Numeric. Successive-difference replicate weight 20.}
#'   \item{repwtp21}{Numeric. Successive-difference replicate weight 21.}
#'   \item{repwtp22}{Numeric. Successive-difference replicate weight 22.}
#'   \item{repwtp23}{Numeric. Successive-difference replicate weight 23.}
#'   \item{repwtp24}{Numeric. Successive-difference replicate weight 24.}
#'   \item{repwtp25}{Numeric. Successive-difference replicate weight 25.}
#'   \item{repwtp26}{Numeric. Successive-difference replicate weight 26.}
#'   \item{repwtp27}{Numeric. Successive-difference replicate weight 27.}
#'   \item{repwtp28}{Numeric. Successive-difference replicate weight 28.}
#'   \item{repwtp29}{Numeric. Successive-difference replicate weight 29.}
#'   \item{repwtp30}{Numeric. Successive-difference replicate weight 30.}
#'   \item{repwtp31}{Numeric. Successive-difference replicate weight 31.}
#'   \item{repwtp32}{Numeric. Successive-difference replicate weight 32.}
#'   \item{repwtp33}{Numeric. Successive-difference replicate weight 33.}
#'   \item{repwtp34}{Numeric. Successive-difference replicate weight 34.}
#'   \item{repwtp35}{Numeric. Successive-difference replicate weight 35.}
#'   \item{repwtp36}{Numeric. Successive-difference replicate weight 36.}
#'   \item{repwtp37}{Numeric. Successive-difference replicate weight 37.}
#'   \item{repwtp38}{Numeric. Successive-difference replicate weight 38.}
#'   \item{repwtp39}{Numeric. Successive-difference replicate weight 39.}
#'   \item{repwtp40}{Numeric. Successive-difference replicate weight 40.}
#'   \item{repwtp41}{Numeric. Successive-difference replicate weight 41.}
#'   \item{repwtp42}{Numeric. Successive-difference replicate weight 42.}
#'   \item{repwtp43}{Numeric. Successive-difference replicate weight 43.}
#'   \item{repwtp44}{Numeric. Successive-difference replicate weight 44.}
#'   \item{repwtp45}{Numeric. Successive-difference replicate weight 45.}
#'   \item{repwtp46}{Numeric. Successive-difference replicate weight 46.}
#'   \item{repwtp47}{Numeric. Successive-difference replicate weight 47.}
#'   \item{repwtp48}{Numeric. Successive-difference replicate weight 48.}
#'   \item{repwtp49}{Numeric. Successive-difference replicate weight 49.}
#'   \item{repwtp50}{Numeric. Successive-difference replicate weight 50.}
#'   \item{repwtp51}{Numeric. Successive-difference replicate weight 51.}
#'   \item{repwtp52}{Numeric. Successive-difference replicate weight 52.}
#'   \item{repwtp53}{Numeric. Successive-difference replicate weight 53.}
#'   \item{repwtp54}{Numeric. Successive-difference replicate weight 54.}
#'   \item{repwtp55}{Numeric. Successive-difference replicate weight 55.}
#'   \item{repwtp56}{Numeric. Successive-difference replicate weight 56.}
#'   \item{repwtp57}{Numeric. Successive-difference replicate weight 57.}
#'   \item{repwtp58}{Numeric. Successive-difference replicate weight 58.}
#'   \item{repwtp59}{Numeric. Successive-difference replicate weight 59.}
#'   \item{repwtp60}{Numeric. Successive-difference replicate weight 60.}
#'   \item{repwtp61}{Numeric. Successive-difference replicate weight 61.}
#'   \item{repwtp62}{Numeric. Successive-difference replicate weight 62.}
#'   \item{repwtp63}{Numeric. Successive-difference replicate weight 63.}
#'   \item{repwtp64}{Numeric. Successive-difference replicate weight 64.}
#'   \item{repwtp65}{Numeric. Successive-difference replicate weight 65.}
#'   \item{repwtp66}{Numeric. Successive-difference replicate weight 66.}
#'   \item{repwtp67}{Numeric. Successive-difference replicate weight 67.}
#'   \item{repwtp68}{Numeric. Successive-difference replicate weight 68.}
#'   \item{repwtp69}{Numeric. Successive-difference replicate weight 69.}
#'   \item{repwtp70}{Numeric. Successive-difference replicate weight 70.}
#'   \item{repwtp71}{Numeric. Successive-difference replicate weight 71.}
#'   \item{repwtp72}{Numeric. Successive-difference replicate weight 72.}
#'   \item{repwtp73}{Numeric. Successive-difference replicate weight 73.}
#'   \item{repwtp74}{Numeric. Successive-difference replicate weight 74.}
#'   \item{repwtp75}{Numeric. Successive-difference replicate weight 75.}
#'   \item{repwtp76}{Numeric. Successive-difference replicate weight 76.}
#'   \item{repwtp77}{Numeric. Successive-difference replicate weight 77.}
#'   \item{repwtp78}{Numeric. Successive-difference replicate weight 78.}
#'   \item{repwtp79}{Numeric. Successive-difference replicate weight 79.}
#'   \item{repwtp80}{Numeric. Successive-difference replicate weight 80.}
#'   \item{repwtp81}{Numeric. Successive-difference replicate weight 81.}
#'   \item{repwtp82}{Numeric. Successive-difference replicate weight 82.}
#'   \item{repwtp83}{Numeric. Successive-difference replicate weight 83.}
#'   \item{repwtp84}{Numeric. Successive-difference replicate weight 84.}
#'   \item{repwtp85}{Numeric. Successive-difference replicate weight 85.}
#'   \item{repwtp86}{Numeric. Successive-difference replicate weight 86.}
#'   \item{repwtp87}{Numeric. Successive-difference replicate weight 87.}
#'   \item{repwtp88}{Numeric. Successive-difference replicate weight 88.}
#'   \item{repwtp89}{Numeric. Successive-difference replicate weight 89.}
#'   \item{repwtp90}{Numeric. Successive-difference replicate weight 90.}
#'   \item{repwtp91}{Numeric. Successive-difference replicate weight 91.}
#'   \item{repwtp92}{Numeric. Successive-difference replicate weight 92.}
#'   \item{repwtp93}{Numeric. Successive-difference replicate weight 93.}
#'   \item{repwtp94}{Numeric. Successive-difference replicate weight 94.}
#'   \item{repwtp95}{Numeric. Successive-difference replicate weight 95.}
#'   \item{repwtp96}{Numeric. Successive-difference replicate weight 96.}
#'   \item{repwtp97}{Numeric. Successive-difference replicate weight 97.}
#'   \item{repwtp98}{Numeric. Successive-difference replicate weight 98.}
#'   \item{repwtp99}{Numeric. Successive-difference replicate weight 99.}
#'   \item{repwtp100}{Numeric. Successive-difference replicate weight 100.}
#'   \item{repwtp101}{Numeric. Successive-difference replicate weight 101.}
#'   \item{repwtp102}{Numeric. Successive-difference replicate weight 102.}
#'   \item{repwtp103}{Numeric. Successive-difference replicate weight 103.}
#'   \item{repwtp104}{Numeric. Successive-difference replicate weight 104.}
#'   \item{repwtp105}{Numeric. Successive-difference replicate weight 105.}
#'   \item{repwtp106}{Numeric. Successive-difference replicate weight 106.}
#'   \item{repwtp107}{Numeric. Successive-difference replicate weight 107.}
#'   \item{repwtp108}{Numeric. Successive-difference replicate weight 108.}
#'   \item{repwtp109}{Numeric. Successive-difference replicate weight 109.}
#'   \item{repwtp110}{Numeric. Successive-difference replicate weight 110.}
#'   \item{repwtp111}{Numeric. Successive-difference replicate weight 111.}
#'   \item{repwtp112}{Numeric. Successive-difference replicate weight 112.}
#'   \item{repwtp113}{Numeric. Successive-difference replicate weight 113.}
#'   \item{repwtp114}{Numeric. Successive-difference replicate weight 114.}
#'   \item{repwtp115}{Numeric. Successive-difference replicate weight 115.}
#'   \item{repwtp116}{Numeric. Successive-difference replicate weight 116.}
#'   \item{repwtp117}{Numeric. Successive-difference replicate weight 117.}
#'   \item{repwtp118}{Numeric. Successive-difference replicate weight 118.}
#'   \item{repwtp119}{Numeric. Successive-difference replicate weight 119.}
#'   \item{repwtp120}{Numeric. Successive-difference replicate weight 120.}
#'   \item{repwtp121}{Numeric. Successive-difference replicate weight 121.}
#'   \item{repwtp122}{Numeric. Successive-difference replicate weight 122.}
#'   \item{repwtp123}{Numeric. Successive-difference replicate weight 123.}
#'   \item{repwtp124}{Numeric. Successive-difference replicate weight 124.}
#'   \item{repwtp125}{Numeric. Successive-difference replicate weight 125.}
#'   \item{repwtp126}{Numeric. Successive-difference replicate weight 126.}
#'   \item{repwtp127}{Numeric. Successive-difference replicate weight 127.}
#'   \item{repwtp128}{Numeric. Successive-difference replicate weight 128.}
#'   \item{repwtp129}{Numeric. Successive-difference replicate weight 129.}
#'   \item{repwtp130}{Numeric. Successive-difference replicate weight 130.}
#'   \item{repwtp131}{Numeric. Successive-difference replicate weight 131.}
#'   \item{repwtp132}{Numeric. Successive-difference replicate weight 132.}
#'   \item{repwtp133}{Numeric. Successive-difference replicate weight 133.}
#'   \item{repwtp134}{Numeric. Successive-difference replicate weight 134.}
#'   \item{repwtp135}{Numeric. Successive-difference replicate weight 135.}
#'   \item{repwtp136}{Numeric. Successive-difference replicate weight 136.}
#'   \item{repwtp137}{Numeric. Successive-difference replicate weight 137.}
#'   \item{repwtp138}{Numeric. Successive-difference replicate weight 138.}
#'   \item{repwtp139}{Numeric. Successive-difference replicate weight 139.}
#'   \item{repwtp140}{Numeric. Successive-difference replicate weight 140.}
#'   \item{repwtp141}{Numeric. Successive-difference replicate weight 141.}
#'   \item{repwtp142}{Numeric. Successive-difference replicate weight 142.}
#'   \item{repwtp143}{Numeric. Successive-difference replicate weight 143.}
#'   \item{repwtp144}{Numeric. Successive-difference replicate weight 144.}
#'   \item{repwtp145}{Numeric. Successive-difference replicate weight 145.}
#'   \item{repwtp146}{Numeric. Successive-difference replicate weight 146.}
#'   \item{repwtp147}{Numeric. Successive-difference replicate weight 147.}
#'   \item{repwtp148}{Numeric. Successive-difference replicate weight 148.}
#'   \item{repwtp149}{Numeric. Successive-difference replicate weight 149.}
#'   \item{repwtp150}{Numeric. Successive-difference replicate weight 150.}
#'   \item{repwtp151}{Numeric. Successive-difference replicate weight 151.}
#'   \item{repwtp152}{Numeric. Successive-difference replicate weight 152.}
#'   \item{repwtp153}{Numeric. Successive-difference replicate weight 153.}
#'   \item{repwtp154}{Numeric. Successive-difference replicate weight 154.}
#'   \item{repwtp155}{Numeric. Successive-difference replicate weight 155.}
#'   \item{repwtp156}{Numeric. Successive-difference replicate weight 156.}
#'   \item{repwtp157}{Numeric. Successive-difference replicate weight 157.}
#'   \item{repwtp158}{Numeric. Successive-difference replicate weight 158.}
#'   \item{repwtp159}{Numeric. Successive-difference replicate weight 159.}
#'   \item{repwtp160}{Numeric. Successive-difference replicate weight 160.}
#'   \item{statefip}{Integer. State FIPS code (numeric, e.g., 6 = California).}
#'   \item{region}{Integer. Census region: 1 = Northeast, 2 = Midwest,
#'     3 = South, 4 = West.}
#'   \item{metro}{Integer. Metropolitan status: 0 = not identified,
#'     1 = not in metropolitan area, 2 = central city of metropolitan area,
#'     3 = outside central city, 4 = central city status unclear.}
#'   \item{age}{Integer. Age in years (18+ by construction).}
#'   \item{sex}{Factor. Derived from the raw `sex` column (overwritten
#'     in-place): `1` = `"Male"`, `2` = `"Female"`. No `NA` values. Levels:
#'     `c("Male", "Female")`.}
#'   \item{race}{Integer. IPUMS race recode. Key codes: 100 = White,
#'     200 = Black/African American, 300 = American Indian/Alaska Native,
#'     650-652 = Asian or Pacific Islander groups. See `race_f4` for a
#'     derived four-category factor.}
#'   \item{hispan}{Integer. Hispanic origin. 0 = Not Hispanic;
#'     100-412 = Hispanic origins (various national groups);
#'     901-902 = Not applicable/unknown. See `race_f4` for a derived
#'     factor where Hispanic origin takes precedence over `race`.}
#'   \item{educ}{Integer. IPUMS educational attainment recode. Key codes:
#'     0 = N/A or preschool; 1-59 = did not complete high school; 60 = HS
#'     diploma or equivalent; 71-110 = some college or associate's degree;
#'     111-125 = bachelor's degree or higher. See `edu_f3` for a derived
#'     three-category factor.}
#'   \item{marst}{Integer. Marital status: 1 = Married, spouse present;
#'     2 = Married, spouse absent; 3 = Separated; 4 = Divorced;
#'     5 = Widowed; 6 = Never married/single.}
#'   \item{empstat}{Integer. Employment status. Key codes: 1 = Armed Forces;
#'     10 = At work; 12 = Has job, not at work last week; 20-22 = Unemployed;
#'     30-36 = Not in labor force. See `empstat_f` for a derived three-category
#'     factor.}
#'   \item{classwkr}{Integer. Class of worker. Key codes: 0 = N/A;
#'     10 = Self-employed; 20-28 = Private sector; 25 = Nonprofit;
#'     27 = For-profit; 28 = Private (not specified); 29 = Self-employed
#'     (not incorporated); 40-50 = Government; 99 = Unknown.}
#'   \item{wkswork2}{Integer. Weeks worked last year (interval codes):
#'     1 = 1-13 weeks; 2 = 14-26 weeks; 3 = 27-39 weeks; 4 = 40-47 weeks;
#'     5 = 48-49 weeks; 6 = 50-52 weeks. 0 = N/A (did not work).}
#'   \item{uhrsworkly}{Integer. Usual hours worked per week last year.
#'     999 = N/A (did not work or not applicable).}
#'   \item{inctot}{Integer. Total personal income in dollars.
#'     99999999 = N/A or missing.}
#'   \item{hhincome}{Integer. Total household income in dollars.
#'     99999999 = N/A or missing. See `inc_hh_cat` for a derived
#'     five-bracket factor.}
#'   \item{health}{Integer. Self-reported health status: 1 = Excellent;
#'     2 = Very good; 3 = Good; 4 = Fair; 5 = Poor.}
#'   \item{nchild}{Integer. Number of own children in the household
#'     (under age 18).}
#'   \item{famsize}{Integer. Number of persons in the family.}
#'   \item{age_f3}{Factor. Age group derived from `age`:
#'     `cut(age, breaks = c(18, 35, 55, Inf), right = FALSE)`. No `NA`
#'     values (all respondents are 18+). Levels:
#'     `c("18-34", "35-54", "55+")`.}
#'   \item{race_f4}{Factor. Race/ethnicity derived from `race` and `hispan`:
#'     Hispanic origin takes precedence (`hispan` in 100-412); `race == 100`
#'     = `"White"`; `race == 200` = `"Black"`; all other codes (including
#'     Asian/Pacific Islander codes 650-652) = `"Other"`. No `NA` values.
#'     Levels: `c("White", "Black", "Hispanic", "Other")`.}
#'   \item{edu_f3}{Factor. Educational attainment derived from `educ` (IPUMS
#'     recode): codes 1-59 = `"Less than HS"`; codes 60-110 = `"HS/Some
#'     college"` (HS diploma through associate's degree); codes 111-125 =
#'     `"College+"`. Code 0 (N/A/preschool) maps to `NA`. Levels:
#'     `c("Less than HS", "HS/Some college", "College+")`.}
#'   \item{empstat_f}{Factor. Employment status derived from `empstat`: codes
#'     10-12 = `"Employed"` (at work or has job but not at work); codes
#'     20-22 = `"Unemployed"`; all remaining codes (Armed Forces, not in
#'     labor force) = `"Not in labor force"`. No `NA` values. Levels:
#'     `c("Employed", "Unemployed", "Not in labor force")`.}
#'   \item{inc_hh_cat}{Factor. Household income brackets derived from
#'     `hhincome`. Code 99999999 (missing/N/A) maps to `NA`. Levels:
#'     `c("Under $25k", "$25k-$50k", "$50k-$75k", "$75k-$100k", "$100k+")`.
#'     Some `NA` values present.}
#'   \item{hh_income_f9}{Factor. Nine-bracket household income harmonized
#'     with `ns_wave1$hh_income_f9` for use as a `selection` variable in
#'     `ipw()`. Derived from `hhincome`; code 99999999 (missing/N/A) maps
#'     to `NA`. Levels: `c("<$20k", "$20-35k", "$35-50k", "$50-65k",
#'     "$65-80k", "$80-100k", "$100-125k", "$125-200k", "≥$200k")`.}
#' }
#'
#' @source IPUMS-CPS, 2023 Annual Social and Economic Supplement (March 2023).
#'   Sarah Flood, Miriam King, Renae Rodgers, Steven Ruggles, J. Robert Warren,
#'   Daniel Backman, Annie Chen, Grace Cooper, Stephanie Richards, Megan
#'   Schouweiler, and Michael Westberry. IPUMS CPS: Version 11.0 \[dataset\].
#'   Minneapolis, MN: IPUMS, 2023. \doi{10.18128/D030.V11.0}
#'   See `data-raw/cps-2023.R` for the construction script.
#' @seealso [ns_wave1], [pew_2016_optin], [npors_2025], [npors_2025_clean],
#'   [gss_2024], [pew_2016_synth_pop]
#' @keywords datasets
"cps_2023"
