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
