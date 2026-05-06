# as_taylor_design() already_taylor warning snapshot

    Code
      expect_warning(as_taylor_design(td), class = "surveywts_warning_already_taylor")

# as_taylor_design() rejects unsupported class

    Code
      as_taylor_design(list(x = 1))
    Condition
      Error in `as_taylor_design()`:
      x `data` must be a <survey_replicate> or <survey_taylor>.
      i Got <list>.

# as_taylor_design() errors when no replicate_creation history entry

    Code
      as_taylor_design(rep)
    Condition
      Error in `as_taylor_design()`:
      x No "replicate_creation" entry found in the weighting history.
      i Cannot reconstruct the original Taylor design without the stored structure.
      v Only designs created with `create_*_weights()` functions can be converted back.

# as_taylor_design() errors when post-creation calibration is present

    Code
      as_taylor_design(rep)
    Condition
      Error in `as_taylor_design()`:
      x Cannot reconstruct Taylor design: replicate weights were adjusted after creation.
      i Post-creation operation(s): "calibration".
      v Conversion back to Taylor is only supported for unadjusted replicate designs.

# as_taylor_design() errors when source was survey_nonprob

    Code
      as_taylor_design(rep)
    Condition
      Error in `as_taylor_design()`:
      x Source design was a <survey_nonprob>; cannot reconstruct a <survey_taylor>.
      i Non-probability samples lack the probability-design structure required for Taylor linearization.

