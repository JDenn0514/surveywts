# .validate_bounds() error messages are informative [snapshot]

    Code
      .validate_bounds(c(1, 2), "multiplicative", allow_null = FALSE)
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "multiplicative"`, the lower bound `L` must be strictly less than 1.
      i Got `L = 1`.
      v Supply `bounds = c(L, U)` where `L < 1 < U`, e.g. `c(0.5, 2)`.

---

    Code
      .validate_bounds(c(0, 2000), "absolute", allow_null = FALSE)
    Condition
      Error in `.validate_bounds()`:
      x For `bounds_scale = "absolute"`, the lower bound `L` must be strictly positive.
      i Got `L = 0`.
      v Supply `bounds = c(L, U)` where `0 < L < U`.

# .validate_unit_scale() error messages are informative [snapshot]

    Code
      .validate_unit_scale(c(1, 0, 1), n = 3L)
    Condition
      Error in `.validate_unit_scale()`:
      x `unit_scale` must contain only strictly positive values.
      i Found 1 non-positive value in `unit_scale`.
      v All q-weights must be > 0.

