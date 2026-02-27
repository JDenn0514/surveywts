# surveyweights R Package Conventions

**Version:** 0.1 — stub, to be expanded as the Phase 0 API is designed
**Status:** In progress — fill in as functions and classes are specified

This document extends the **generic R package conventions** (`r-package-conventions.md`)
with surveyweights-specific examples and detailed guidance.

**Read `r-package-conventions.md` first, then this document.**

---

## Quick Reference (surveyweights-specific)

| Decision | Choice | Example |
|----------|--------|---------|
| Error prefix | `surveyweights_error_*` | `surveyweights_error_not_data_frame` |
| Warning prefix | `surveyweights_warning_*` | `surveyweights_warning_negative_weights` |
| Setter return | Always `invisible(x)` | TBD once setters are defined |
| Getter return | Always visible | TBD once getters are defined |

---

## 1. Naming Conventions

> **TODO:** Fill in after Phase 0 spec is written.

The table below will be completed as the API is designed:

| Category | Pattern | Example |
|----------|---------|---------|
| Constructor functions | TBD | TBD |
| Internal helpers | prefix `.` | `.validate_weights()` |

---

## 2. Function Families (`@family` groups)

> **TODO:** Fill in after Phase 0 spec is written.

Define `@family` groups here once the function categories are established.

---

## 3. Return Value Visibility

| Function type | Return |
|---------------|--------|
| Constructors (return new objects) | Visible |
| Setters (modify and return) | `invisible(x)` |
| Extractors/getters | Visible |
| Print/summary S7 methods | `invisible(x)` |
| Internal validators | `invisible(TRUE)` on success |

---

## 4. Export Policy

### What to export
- All constructors and main user-facing functions
- All S7 class objects (they are part of the public API)
- All getter/extractor functions

### What NOT to export
- All `.`-prefixed internal helpers
- Internal validators
- Internal S7 generics not part of the public API

---

## 5. S7 Classes

> **TODO:** Fill in with class names, properties, and hierarchy once the Phase 0
> spec is written. Follow the patterns in `code-style.md §2`.

---

## 6. Documentation Checklist

Before committing any roxygen2 changes:

- [ ] `devtools::document()` has been run
- [ ] `NAMESPACE` file has been updated
- [ ] All exported functions have `@return`
- [ ] All `@examples` are runnable
- [ ] Internal helpers have `@keywords internal` + `@noRd` if needed
- [ ] `@family` tags are correct
- [ ] No `@importFrom` tags anywhere
- [ ] All external calls use `::`
- [ ] `R CMD check` passes with 0 errors, 0 warnings, ≤2 notes
