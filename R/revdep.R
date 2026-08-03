suppressPackageStartupMessages({
  library(revdepcheck.extras)
  library(futurize)
  library(progressify)
})

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
  
    pkgs <- lapply(pkgs, revdepcheck.extras::revdep_children) |> progressify() |> futurize()
    pkgs <- sort(unique(unlist(pkgs)))
    deps[[kk]] <- pkgs
  }
  str(pkgs)
}
