# Common Testing Patterns

## Testing Errors with Specific Classes

```r
test_that("validation catches errors", {
  expect_error(
    validate_input("wrong_type"),
    class = "vctrs_error_cast"
  )
})
```

## Testing with Temporary Files

```r
test_that("file processing works", {
  temp_file <- withr::local_tempfile(
    lines = c("line1", "line2", "line3")
  )

  result <- process_file(temp_file)
  expect_equal(length(result), 3)
})
```

## Testing with Modified Options

```r
test_that("output respects width", {
  withr::local_options(width = 40)

  output <- capture_output(print(my_object))
  expect_lte(max(nchar(strsplit(output, "\n")[[1]])), 40)
})
```

## Testing Multiple Related Cases

```r
test_that("str_trunc() handles all directions", {
  trunc <- function(direction) {
    str_trunc("This string is moderately long", direction, width = 20)
  }

  expect_equal(trunc("right"), "This string is mo...")
  expect_equal(trunc("left"), "...erately long")
  expect_equal(trunc("center"), "This stri...ely long")
})
```

## Custom Expectations in Helper Files

```r
# In tests/testthat/helper-expectations.R
expect_valid_user <- function(user) {
  expect_type(user, "list")
  expect_named(user, c("id", "name", "email"))
  expect_type(user$id, "integer")
  expect_match(user$email, "@")
}

# In test file
test_that("user creation works", {
  user <- create_user("test@example.com")
  expect_valid_user(user)
})
```

## File System Discipline

**Always write to temp directory:**

```r
# Good
output <- withr::local_tempfile(fileext = ".csv")
write.csv(data, output)

# Bad - writes to package directory
write.csv(data, "output.csv")
```

**Access test fixtures with `test_path()`:**

```r
# Good - works in all contexts
data <- readRDS(test_path("fixtures", "data.rds"))

# Bad - relative paths break
data <- readRDS("fixtures/data.rds")
```

## testthat 3 Modernizations

**Deprecated → Modern:**
- `context()` → Remove (duplicates filename)
- `expect_equivalent()` → `expect_equal(ignore_attr = TRUE)`
- `with_mock()` → `local_mocked_bindings()`
- `is_null()`, `is_true()`, `is_false()` → `expect_null()`, `expect_true()`, `expect_false()`

**New in testthat 3:**
- Edition system (`Config/testthat/edition: 3`)
- Improved snapshot testing
- `waldo::compare()` for better diff output
- `local_mocked_bindings()` works with byte-compiled code
- Parallel test execution support
