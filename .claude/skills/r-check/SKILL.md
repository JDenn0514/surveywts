---
name: r-check
description: >
  Run devtools::check() and parse results. Use when verifying R CMD check
  status mid-development or diagnosing CI failures. Runs the check, categorizes
  errors/warnings/notes, and suggests fixes. Trigger when user says "run check", "does it
  pass check", "what's failing", or "fix the check".
---

Run `devtools::check()` for the surveywts package. Then:

1. Parse stdout/stderr for ERRORS, WARNINGS, and NOTES
2. For each issue, identify the root cause (roxygen2 out of sync → run document(); missing example package → add library(); failing test → read the test)
3. Pre-approved NOTEs (no visible binding, CRAN feasibility) — flag as OK, don't block
4. Report summary: pass/fail, counts, and next action
5. If errors exist, propose targeted fixes following code-style.md and r-package-conventions.md

Run: `Rscript -e "devtools::check(args = c('--no-manual'))"`