# R/data.R
#
# Roxygen2 documentation for bundled IPW example datasets.

#' National Survey Wave 1 IPW subset
#'
#' @title National Survey Wave 1 IPW subset
#' @description A harmonized subset of the `ns_wave1` dataset from
#'   `surveycore`, prepared for use in IPW examples and tests. Contains
#'   demographic variables with factor labels aligned to `gss_ipw_ref`,
#'   `acs_ipw_ref`, and `npors_2025_ref`.
#'
#' @format A data frame with 6,422 rows and 4 columns:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{age_group}{Factor with levels `"18-34"`, `"35-54"`, `"55+"`.}
#'   \item{race_ethn}{Factor with levels `"White"`, `"Black"`,
#'     `"Hispanic"`, `"Asian"`, `"Other"`. Approximately 120 rows have
#'     `NA` (respondents who reported `"some other race"` with no Hispanic
#'     origin, which cannot be mapped to a standard category).}
#'   \item{educ}{Factor with levels `"Less than HS"`, `"HS/Some college"`,
#'     `"College+"`. No `NA` values.}
#' }
#'
#' @source Derived from `surveycore::ns_wave1`. See `data-raw/ns-gss-ipw.R`
#'   for the harmonization script.
#' @keywords datasets
"ns_wave1_ipw"

#' GSS 2024 IPW reference design
#'
#' @title GSS 2024 IPW reference design
#' @description A harmonized `survey_taylor` reference design derived from
#'   the `gss_2024` dataset in `surveycore`. Gender factor levels are aligned
#'   to `ns_wave1_ipw`. Rows with `NA` sex (n = 19) or `NA` age (n = 93) are
#'   dropped. The `wtssps` weight is scaled to the 2024 US adult population
#'   (260,000,000) so that it can be used as a population-level reference in
#'   the IPW pseudo-likelihood.
#'
#' @format A `survey_taylor` object. The underlying data frame contains:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{age_group}{Factor with levels `"18-34"`, `"35-54"`, `"55+"`.}
#'   \item{vpsu}{PSU identifier used for variance estimation.}
#'   \item{vstrat}{Stratum identifier used for variance estimation.}
#'   \item{wt_pop}{Person-level population weight: `wtssps` scaled by the
#'     2024 US adult population (260,000,000) divided by the number of
#'     retained rows. Required for the IPW pseudo-likelihood formulation.}
#' }
#'
#' @source Derived from `surveycore::gss_2024`. See `data-raw/ns-gss-ipw.R`
#'   for the harmonization script.
#' @keywords datasets
"gss_ipw_ref"

#' Pew NPORS 2025 IPW reference design
#'
#' @title Pew NPORS 2025 IPW reference design
#' @description A harmonized `survey_taylor` reference design derived from
#'   the `pew_npors_2025` dataset in `surveycore`. The `weight` variable is
#'   scaled to the 2024 US adult population (260,000,000) for use in the
#'   IPW pseudo-likelihood. Factor levels are aligned to `ns_wave1_ipw`.
#'
#' @format A `survey_taylor` object with 5,022 rows. The underlying data
#'   frame contains:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`. Approximately
#'     0.5% `NA` from `3` (Non-binary) and `99` (Refused) recoding.}
#'   \item{age_group}{Factor with levels `"18-34"`, `"35-54"`, `"55+"`.
#'     Derived by collapsing the 13-level `agegrp` variable.}
#'   \item{race_ethn}{Factor with levels `"White"`, `"Black"`,
#'     `"Hispanic"`, `"Asian"`, `"Other"`. Approximately 0.5% `NA` from
#'     `99` (Refused) recoding.}
#'   \item{educ}{Factor with levels `"Less than HS"`, `"HS/Some college"`,
#'     `"College+"`. Approximately 0.5% `NA` from `99` (Refused) recoding.}
#'   \item{wt_pop}{Person-level population weight: `weight` scaled by the
#'     2024 US adult population (260,000,000) divided by the sample size.}
#' }
#'
#' @source Derived from `surveycore::pew_npors_2025`. See
#'   `data-raw/npors-acs-ipw.R` for the harmonization script.
#' @keywords datasets
"npors_2025_ref"

#' Pew NPORS 2025 IPW reference design (complete cases)
#'
#' @title Pew NPORS 2025 IPW reference design (complete cases)
#' @description A filtered version of [npors_2025_ref] with rows removed where
#'   any of `gender`, `age_group`, `race_ethn`, or `educ` is `NA`. Use this
#'   object when passing to [ipw()] to avoid the
#'   `surveywts_warning_ipw_reference_na_omitted` warning. Use
#'   [npors_2025_ref] when downstream code handles missingness itself.
#'
#' @format A `survey_taylor` object with 4,814 rows (5,022 minus the 208 rows
#'   with `NA` in at least one predictor column). The
#'   underlying data frame contains the same columns as [npors_2025_ref]:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`. No `NA` values.}
#'   \item{age_group}{Factor with levels `"18-34"`, `"35-54"`, `"55+"`.
#'     No `NA` values.}
#'   \item{race_ethn}{Factor with levels `"White"`, `"Black"`,
#'     `"Hispanic"`, `"Asian"`, `"Other"`. No `NA` values.}
#'   \item{educ}{Factor with levels `"Less than HS"`, `"HS/Some college"`,
#'     `"College+"`. No `NA` values.}
#'   \item{wt_pop}{Person-level population weight: `weight` scaled by the
#'     2024 US adult population (260,000,000) divided by the original sample
#'     size (5,022). Weights are not rescaled after row removal.}
#' }
#'
#' @source Derived from [npors_2025_ref]. See `data-raw/npors-acs-ipw.R`
#'   for the construction script.
#' @seealso [npors_2025_ref]
#' @keywords datasets
"npors_2025_clean_ref"

#' Pew 2016 ATP opt-in sample
#'
#' @title Pew 2016 ATP opt-in sample
#' @description A 2016 Pew Research Center study fielded simultaneously on three
#'   opt-in (non-probability) online vendor panels alongside the probability-based
#'   American Trends Panel (ATP). The dataset is used in Mercer, Lau and Kennedy
#'   (2018) "For Weighting Online Opt-In Samples, What Matters Most?" and
#'   provides 13 benchmark variables that can be validated against population
#'   truth estimates from [pew_2016_synth_pop].
#'
#'   Value labels are preserved as named numeric attributes on each column
#'   (accessible via `attr(pew_2016_optin$gender, "labels")`). Variable labels
#'   are stored in the `"label"` attribute of each column.
#'
#' @format A data frame with 31,863 rows and 99 columns. Key columns:
#' \describe{
#'   \item{rid}{Character. Respondent ID with vendor prefix (e.g., `"V1_7"`).}
#'   \item{vendor}{Numeric. Opt-in panel vendor: `1` = Vendor 1, `2` = Vendor 2,
#'     `3` = Vendor 3.}
#'   \item{enddate}{Date. Date respondent completed the survey.}
#'   \item{language}{Numeric. Interview language: `1` = English, `2` = Spanish.}
#'   \item{age}{Numeric (continuous). Age in years (range 18–110; values above
#'     ~95 are likely data entry artefacts or sentinel codes).}
#'   \item{gender}{Numeric. `1` = Male, `2` = Female, `3` = Refused.}
#'   \item{agecat6}{Numeric. 6-category age recode: `1` = 18–24, `2` = 25–34,
#'     `3` = 35–44, `4` = 45–54, `5` = 55–64, `6` = 65+.}
#'   \item{racethn}{Numeric. Race/ethnicity: `1` = White non-Hispanic,
#'     `2` = Black non-Hispanic, `3` = Hispanic, `4` = Asian,
#'     `5` = Other race, `6` = Refused.}
#'   \item{educcat3}{Numeric. 3-category education: `1` = HS or less,
#'     `2` = Some college, `3` = College grad, `4` = Refused.}
#'   \item{educcat5}{Numeric. 5-category education: `1` = Less than HS,
#'     `2` = HS Grad, `3` = Some college, `4` = College grad,
#'     `5` = Postgraduate, `6` = Refused.}
#'   \item{division}{Numeric. Census division, **alphabetical coding** (not
#'     standard Census order): `1` = East North Central, `2` = East South
#'     Central, `3` = Middle Atlantic, `4` = Mountain, `5` = New England,
#'     `6` = Pacific, `7` = South Atlantic, `8` = West North Central,
#'     `9` = West South Central. Coding matches [pew_2016_synth_pop].}
#'   \item{region}{Numeric. Census region: `1` = Midwest, `2` = Northeast,
#'     `3` = South, `4` = West.}
#'   \item{partyscale5}{Numeric. Party ID: `1` = Republican, `2` = Lean
#'     Republican, `3` = Ind/No Lean, `4` = Lean Democrat, `5` = Democrat.}
#'   \item{partyscale7}{Numeric. 7-point party scale (Strong R ... Strong D).}
#'   \item{ideo3}{Numeric. Ideology: `1` = Liberal, `2` = Moderate,
#'     `3` = Conservative, `4` = Refused.}
#' }
#'
#' **Benchmark variables** (shared with [pew_2016_synth_pop]): binary items
#' are dichotomised to `1` = positive response, `0` = negative response;
#' Refused is `NA`. Coding is consistent with [pew_2016_synth_pop].
#' \describe{
#'   \item{registered}{Integer. Registered to vote: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{vote14}{Integer. Voted in 2014 midterms: `1` = Voted,
#'     `0` = Did not vote, `NA` = Refused.}
#'   \item{folgov}{Numeric. Follows government/public affairs (ordinal):
#'     `1` = Most of the time, `2` = Some of the time, `3` = Only now and
#'     then, `4` = Hardly at all, `5` = Refused.}
#'   \item{talk_cps}{Numeric. Frequency of talking with neighbors (ordinal):
#'     `1` = Basically every day … `5` = Not at all, `6` = Refused.}
#'   \item{trust_cps}{Numeric. Trust in neighbors (ordinal): `1` = All of
#'     the people … `4` = None, `5` = Refused.}
#'   \item{comgrp_cps}{Integer. Participated in community group: `1` = Yes,
#'     `0` = No, `NA` = Refused.}
#'   \item{pub_off_cps}{Integer. Contacted public official: `1` = Yes,
#'     `0` = No, `NA` = Refused.}
#'   \item{volsum}{Integer. Volunteered in past year: `1` = Volunteered,
#'     `0` = Did not volunteer, `NA` = Refused.}
#'   \item{tablet_cps}{Integer. Uses tablet/e-reader: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{textim_cps}{Integer. Uses texting/instant messaging: `1` = Yes,
#'     `0` = No, `NA` = Refused.}
#'   \item{social_cps}{Integer. Uses social networking: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#'   \item{fdstmp_cps}{Integer. Household received food stamps in 2015:
#'     `1` = Yes, `0` = No, `NA` = Refused.}
#'   \item{owngun_gss}{Integer. Gun in home: `1` = Yes, `0` = No,
#'     `NA` = Refused.}
#' }
#'
#' Additional columns (not individually described here) cover presidential
#' approval, voting intentions, political opinions, health, religion, household
#' demographics (ACS-sourced items), media use, and composite recodes. See
#' `attr(pew_2016_optin[[col]], "label")` for the variable label of any column.
#'
#' @source Derived from the Pew Research Center 2016 opt-in sample SPSS file.
#'   See `data-raw/pew-2016.R` for the preparation script.
#' @seealso [pew_2016_synth_pop]
#' @keywords datasets
"pew_2016_optin"

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
#' @format A data frame with 20,000 rows and 38 columns:
#' \describe{
#'   \item{id}{Integer. Row identifier.}
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
#'   \item{partyscale5}{Numeric. Party ID: `1` = Republican,
#'     `2` = Lean Republican, `3` = Ind/No Lean, `4` = Lean Democrat,
#'     `5` = Democrat.}
#'   \item{ideo3}{Numeric. Ideology: `1` = Liberal, `2` = Moderate,
#'     `3` = Conservative.}
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
#'   \item{tenure_acs}{Numeric. Lived in home one year ago.}
#'   \item{boycott}{Numeric. Boycotted a product/service in last 12 months.}
#'   \item{religcat}{Numeric. Religion category (6 levels).}
#' }
#'
#' **Benchmark variables** (shared with [pew_2016_optin]): binary items are
#' dichotomised to `1` = positive response, `0` = negative response; no Refused
#' codes exist in this dataset. Coding is consistent with [pew_2016_optin].
#' \describe{
#'   \item{registered}{Integer. Registered to vote: `1` = Yes, `0` = No.
#'     Recoded from the raw SPSS file (original: `1` = No, `2` = Yes).}
#'   \item{vote14}{Integer. Voted in 2014: `1` = Voted, `0` = Did not vote.
#'     Recoded from the raw SPSS file (original: `1` = Did not vote,
#'     `2` = Voted).}
#'   \item{folgov}{Numeric. Follows government/public affairs (ordinal):
#'     `1` = Most of the time, `2` = Some of the time, `3` = Only now and
#'     then, `4` = Hardly at all.}
#'   \item{talk_cps}{Numeric. Frequency of talking with neighbors (ordinal):
#'     `1` = Basically every day … `5` = Not at all.}
#'   \item{trust_cps}{Numeric. Trust in neighbors (ordinal): `1` = All of
#'     the people … `4` = None.}
#'   \item{comgrp_cps}{Integer. Participated in community group: `1` = Yes,
#'     `0` = No.}
#'   \item{pub_off_cps}{Integer. Contacted public official: `1` = Yes,
#'     `0` = No.}
#'   \item{volsum}{Integer. Volunteered in past year: `1` = Volunteered,
#'     `0` = Did not volunteer.}
#'   \item{tablet_cps}{Integer. Uses tablet/e-reader: `1` = Yes, `0` = No.}
#'   \item{textim_cps}{Integer. Uses texting/instant messaging: `1` = Yes,
#'     `0` = No.}
#'   \item{social_cps}{Integer. Uses social networking: `1` = Yes, `0` = No.}
#'   \item{fdstmp_cps}{Integer. Household received food stamps: `1` = Yes,
#'     `0` = No.}
#'   \item{owngun_gss}{Integer. Gun in home: `1` = Yes, `0` = No.}
#' }
#'
#' @source Derived from the Pew Research Center 2016 ATP synthetic population
#'   SPSS file. See `data-raw/pew-2016.R` for the preparation script.
#' @seealso [pew_2016_optin]
#' @keywords datasets
"pew_2016_synth_pop"

#' ACS PUMS Wyoming IPW reference design
#'
#' @title ACS PUMS Wyoming IPW reference design
#' @description A harmonized `survey_taylor` reference design derived from
#'   the `acs_pums_wy` dataset in `surveycore`, restricted to adults
#'   (age >= 18). Factor levels for `age_group`, `gender`, `race_ethn`, and
#'   `educ` are identical to `ns_wave1_ipw`.
#'
#' @format A `survey_taylor` object with 4,736 rows. The underlying data
#'   frame contains:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{age_group}{Factor with levels `"18-34"`, `"35-54"`, `"55+"`.}
#'   \item{race_ethn}{Factor with levels `"White"`, `"Black"`,
#'     `"Hispanic"`, `"Asian"`, `"Other"`.}
#'   \item{educ}{Factor with levels `"Less than HS"`, `"HS/Some college"`,
#'     `"College+"`. No `NA` values.}
#'   \item{pwgtp}{Person weight from the ACS PUMS.}
#' }
#'
#' @source Derived from `surveycore::acs_pums_wy`. See
#'   `data-raw/npors-acs-ipw.R` for the harmonization script.
#' @keywords datasets
"acs_ipw_ref"
