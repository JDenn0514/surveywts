# R/data.R
#
# Roxygen2 documentation for bundled IPW example datasets.

#' National Survey Wave 1 IPW subset
#'
#' @title National Survey Wave 1 IPW subset
#' @description A harmonized subset of the `ns_wave1` dataset from
#'   `surveycore`, prepared for use in IPW examples and tests. Contains
#'   gender and age variables with factor labels aligned to `gss_ipw_ref`.
#'
#' @format A data frame with 6,422 rows and 2 columns:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{age}{Integer. Respondent age in years.}
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
#'   to `ns_wave1_ipw`. Rows with `NA` sex (n = 19) are dropped, leaving
#'   3,290 respondents.
#'
#' @format A `survey_taylor` object with 3,290 rows. The underlying data
#'   frame contains:
#' \describe{
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{age}{Integer. Respondent age in years.}
#'   \item{vpsu}{PSU identifier used for variance estimation.}
#'   \item{vstrat}{Stratum identifier used for variance estimation.}
#'   \item{wtssps}{Analytic survey weight.}
#' }
#'
#' @source Derived from `surveycore::gss_2024`. See `data-raw/ns-gss-ipw.R`
#'   for the harmonization script.
#' @keywords datasets
"gss_ipw_ref"

#' Pew NPORS 2025 IPW subset
#'
#' @title Pew NPORS 2025 IPW subset
#' @description A harmonized subset of the `pew_npors_2025` dataset from
#'   `surveycore`, prepared for use in IPW examples and tests. Refuse/DK
#'   responses (coded 99) are recoded to `NA`. Factor levels are aligned
#'   to `acs_ipw_ref`.
#'
#' @format A data frame with 5,022 rows and 4 columns. Each predictor has
#'   approximately 1–2% `NA` from 99-code recoding:
#' \describe{
#'   \item{age_group}{Factor with 13 levels: `"18-24"`, `"25-29"`, ...,
#'     `"80+"`.}
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{race_ethn}{Factor with levels `"White"`, `"Black"`, `"Hispanic"`,
#'     `"Asian"`, `"Other"`.}
#'   \item{educ}{Factor with levels `"Less than HS"`, `"HS/Some college"`,
#'     `"College+"`.}
#' }
#'
#' @source Derived from `surveycore::pew_npors_2025`. See
#'   `data-raw/npors-acs-ipw.R` for the harmonization script.
#' @keywords datasets
"npors_2025_ipw"

#' ACS PUMS Wyoming IPW reference design
#'
#' @title ACS PUMS Wyoming IPW reference design
#' @description A harmonized `survey_taylor` reference design derived from
#'   the `acs_pums_wy` dataset in `surveycore`, restricted to adults
#'   (age >= 18). Factor levels for `age_group`, `gender`, `race_ethn`, and
#'   `educ` are identical to `npors_2025_ipw`.
#'
#' @format A `survey_taylor` object with 4,736 rows. The underlying data
#'   frame contains:
#' \describe{
#'   \item{age_group}{Factor with 13 levels: `"18-24"`, `"25-29"`, ...,
#'     `"80+"`.}
#'   \item{gender}{Factor with levels `"Male"`, `"Female"`.}
#'   \item{race_ethn}{Factor with levels `"White"`, `"Black"`, `"Hispanic"`,
#'     `"Asian"`, `"Other"`.}
#'   \item{educ}{Factor with levels `"Less than HS"`, `"HS/Some college"`,
#'     `"College+"`.}
#'   \item{pwgtp}{Person weight from the ACS PUMS.}
#' }
#'
#' @source Derived from `surveycore::acs_pums_wy`. See
#'   `data-raw/npors-acs-ipw.R` for the harmonization script.
#' @keywords datasets
"acs_ipw_ref"
