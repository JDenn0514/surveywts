# Error and Warning Classes

All `cli_abort()` and `cli_warn()` calls must use a class from this table.

## Errors

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyweights_error_not_data_frame` | `my_fn()` | `data` is not a data.frame |

## Warnings

| Class | Thrown by | Condition |
|-------|-----------|-----------|
| `surveyweights_warning_example` | `my_fn()` | Example warning condition |
