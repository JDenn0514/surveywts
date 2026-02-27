# R/zzz.R
# nocov start
.onLoad <- function(libname, pkgname) {
  S7::methods_register()
}
# nocov end
