## Pew Research Center — 2016 ATP Opt-In + Synthetic Population
## Prepare package datasets
##
## Source: Pew Research Center (used in Mercer, Lau & Kennedy 2018
##         "For Weighting Online Opt-In Samples, What Matters Most?")
## License: Academic / non-commercial use per Pew Research Center terms.
##
## Output datasets:
##   pew_2016_optin     — 31,863 opt-in respondents (3 vendors), 99 variables
##   pew_2016_synth_pop — 20,000-row synthetic population (ATP-derived), 38 variables
##
## Both datasets share a common set of benchmark variables (see below) whose
## population truth values can be estimated from pew_2016_synth_pop.
##
## Benchmark variables (present in both datasets):
##   registered, vote14, folgov, talk_cps, trust_cps, comgrp_cps, pub_off_cps,
##   volsum, tablet_cps, textim_cps, social_cps, fdstmp_cps, owngun_gss
##
## Adjustment variables (present in both datasets):
##   gender, racethn, educcat5, division, partyscale5, ideo3, registered
##
## NOTE: The division variable uses non-standard alphabetical coding in both
##   datasets (1 = East North Central, not 1 = New England). This matches
##   across datasets but differs from the standard Census 9-division scheme.
##
## The raw .sav files are excluded from version control (see .gitignore).
## They must be placed at:
##   data-raw/pew_2016/pew_2016_optin.sav
##   data-raw/pew_2016/pew_2016_synth_pop.sav
##
## Run this script from the package root: source("data-raw/pew-2016.R")

library(haven)
library(janitor)
library(usethis)

OPTIN_FILE <- file.path(
  here::here(), "data-raw", "pew_2016",
  "pew_2016_optin.sav"
)
POP_FILE <- file.path(
  here::here(), "data-raw", "pew_2016",
  "pew_2016_synth_pop.sav"
)

for (f in c(OPTIN_FILE, POP_FILE)) {
  if (!file.exists(f)) {
    stop(
      "Raw file not found: ", f, "\n",
      "Place both SAV files in data-raw/pew_2016/ and re-run.\n",
      "Source: Pew Research Center (contact prc.info@pewresearch.org)"
    )
  }
}

## ---- 1. Read ----

message("Reading pew_2016_optin.sav (~28 MB)...")
optin_raw <- read_spss(OPTIN_FILE)
message("Read ", nrow(optin_raw), " rows x ", ncol(optin_raw), " cols")

message("Reading pew_2016_synth_pop.sav (~9 MB)...")
pop_raw <- read_spss(POP_FILE)
message("Read ", nrow(pop_raw), " rows x ", ncol(pop_raw), " cols")

## ---- 2. Strip haven class, preserve label/labels attributes ----
##
## Converts haven_labelled vectors to plain R numeric/character vectors while
## retaining the SPSS variable label (attr "label") and value label map
## (attr "labels") on each column. This keeps the metadata accessible
## (e.g. via attr(df$gender, "labels")) without the haven class dependency.

as_plain <- function(df) {
  df[] <- lapply(df, function(x) {
    if (!inherits(x, "haven_labelled")) return(x)
    raw  <- as.vector(x)
    lbl  <- attr(x, "label",  exact = TRUE)
    lbvl <- attr(x, "labels", exact = TRUE)
    if (!is.null(lbl))  attr(raw, "label")  <- lbl
    if (!is.null(lbvl)) attr(raw, "labels") <- lbvl
    raw
  })
  df
}

pew_2016_optin     <- as_plain(as.data.frame(optin_raw))
pew_2016_synth_pop <- as_plain(as.data.frame(pop_raw))
rownames(pew_2016_optin)     <- NULL
rownames(pew_2016_synth_pop) <- NULL

## ---- 3. Standardise column names to snake_case ----
##
## Key mappings (SCREAMING_SNAKE → snake_case):
##   pew_2016_optin:
##     rid, vendor, enddate, age, gender, agecat6, racethn, educcat3,
##     educcat5, division, region, partyscale5, partyscale7, ideo3,
##     registered, vote14, folgov, talk_cps, trust_cps, comgrp_cps,
##     pub_off_cps, volsum, tablet_cps, textim_cps, social_cps,
##     fdstmp_cps, owngun_gss, ...
##   pew_2016_synth_pop:
##     id, gender, age, racethn, educcat5, division, partyscale5,
##     ideo3, registered, vote14, folgov, talk_cps, trust_cps,
##     comgrp_cps, pub_off_cps, volsum, tablet_cps, textim_cps,
##     social_cps, fdstmp_cps, owngun_gss, ...

pew_2016_optin     <- clean_names(pew_2016_optin)
pew_2016_synth_pop <- clean_names(pew_2016_synth_pop)

## ---- 4. Recode binary benchmark variables to 0/1 ----
##
## All yes/no benchmark variables are converted to integer 0/1:
##   1 = positive response (Yes, Voted, Volunteered, etc.)
##   0 = negative response (No, Did not vote, etc.)
##   NA = Refused (optin only; no Refused codes in synth_pop)
##
## In the raw synth_pop SPSS file, registered and vote14 carry the negative
## response as 1 (1 = No / 1 = Did not vote). The yes_code arguments below
## handle this reversal so both datasets end up on the same 0/1 scale.

make_binary <- function(x, yes_code, refused_codes = integer(0),
                        yes_label = "Yes", no_label = "No") {
  lbl <- attr(x, "label", exact = TRUE)
  out <- ifelse(x == yes_code, 1L,
                ifelse(x %in% refused_codes, NA_integer_, 0L))
  attr(out, "label")  <- lbl
  attr(out, "labels") <- c(0L, 1L)
  names(attr(out, "labels")) <- c(no_label, yes_label)
  out
}

# pew_2016_optin — positive code is always 1; 3 = Refused → NA
optin_specs <- list(
  registered  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  vote14      = list(yes = 1L, yes_label = "Voted",         no_label = "Did not vote"),
  comgrp_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  pub_off_cps = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  volsum      = list(yes = 1L, yes_label = "Volunteered",   no_label = "Did not volunteer"),
  tablet_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  textim_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  social_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  fdstmp_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  owngun_gss  = list(yes = 1L, yes_label = "Yes",           no_label = "No")
)

for (v in names(optin_specs)) {
  s <- optin_specs[[v]]
  pew_2016_optin[[v]] <- make_binary(
    pew_2016_optin[[v]],
    yes_code = s$yes, refused_codes = 3L,
    yes_label = s$yes_label, no_label = s$no_label
  )
}

# pew_2016_synth_pop — registered and vote14 have reversed raw coding
# (1 = No / 1 = Did not vote), so yes_code = 2 for those two.
synth_specs <- list(
  registered  = list(yes = 2L, yes_label = "Yes",           no_label = "No"),
  vote14      = list(yes = 2L, yes_label = "Voted",         no_label = "Did not vote"),
  comgrp_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  pub_off_cps = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  volsum      = list(yes = 1L, yes_label = "Volunteered",   no_label = "Did not volunteer"),
  tablet_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  textim_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  social_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  fdstmp_cps  = list(yes = 1L, yes_label = "Yes",           no_label = "No"),
  owngun_gss  = list(yes = 1L, yes_label = "Yes",           no_label = "No")
)

for (v in names(synth_specs)) {
  s <- synth_specs[[v]]
  pew_2016_synth_pop[[v]] <- make_binary(
    pew_2016_synth_pop[[v]],
    yes_code = s$yes, refused_codes = integer(0),
    yes_label = s$yes_label, no_label = s$no_label
  )
}

## ---- 5. Save ----

message("Saving pew_2016_optin and pew_2016_synth_pop to data/...")
usethis::use_data(pew_2016_optin, pew_2016_synth_pop, overwrite = TRUE)

message("Done.")
message(
  "  pew_2016_optin:     ",
  nrow(pew_2016_optin), " rows x ", ncol(pew_2016_optin), " cols"
)
message(
  "  pew_2016_synth_pop: ",
  nrow(pew_2016_synth_pop), " rows x ", ncol(pew_2016_synth_pop), " cols"
)
message("  Shared benchmark variables: registered, vote14, folgov, talk_cps,")
message("    trust_cps, comgrp_cps, pub_off_cps, volsum, tablet_cps,")
message("    textim_cps, social_cps, fdstmp_cps, owngun_gss")
message("Document with: ?pew_2016_optin  or  ?pew_2016_synth_pop")

## ---- 6. Build survey object companions ----

# pew_2016_optin_svy — survey_nonprob with equal weights (raw panel, no wt col)
# Build from a COPY so equal_wt is NOT saved in the tibble's .rda file.
# The tibble's .rda was saved in section 5 and is not affected here.
optin_for_svy <- pew_2016_optin
optin_for_svy$equal_wt <- 1L
pew_2016_optin_svy <- surveycore::as_survey_nonprob(
  optin_for_svy,
  weights = equal_wt
)

# pew_2016_synth_pop_svy — SRS survey_taylor with equal weights (synthetic pop)
# Build from a COPY for symmetry with the optin approach above.
synth_for_svy <- pew_2016_synth_pop
synth_for_svy$equal_wt <- 1L
pew_2016_synth_pop_svy <- surveycore::as_survey(
  synth_for_svy,
  weights = equal_wt
)

# Verify equal_wt was not added to the saved tibbles
stopifnot(!"equal_wt" %in% names(pew_2016_optin))
stopifnot(!"equal_wt" %in% names(pew_2016_synth_pop))

usethis::use_data(pew_2016_optin_svy, pew_2016_synth_pop_svy, overwrite = TRUE)
message("Saved pew_2016_optin_svy and pew_2016_synth_pop_svy")
