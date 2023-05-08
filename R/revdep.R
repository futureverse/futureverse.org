suppressPackageStartupMessages({
  library(revdepcheck.extras)
  library(future.apply)
  library(progressr)
})
source("R/progressr_progressify.R")

plan(multicore)
handlers(global = TRUE)

pkgs <- c("future", "future.apply", "furrr", "doFuture", "globals", "progressr")
pkg <- "future"

n_generations <- 4L

if (!exists("deps", mode = "list")) deps <- list()
for (kk in seq_len(n_generations)) {
  message("Generation #", kk)

  if (length(deps) < kk || length(pkgs <- deps[[kk]]) == 0L) {
    if (kk == 1L) {
      pkgs <- pkg
    } else {
      pkgs <- deps[[kk-1]]
    }
  
    pkgs <- future_lapply(pkgs, revdep_children) %progressify% TRUE
    pkgs <- sort(unique(unlist(pkgs)))
    deps[[kk]] <- pkgs
  }
  str(pkgs)
}
