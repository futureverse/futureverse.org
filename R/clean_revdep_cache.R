#!/usr/bin/env Rscript
# Script to clear R.cache entries for revdepcheck.extras::revdep_over_time
# Usage:
#   Rscript R/clean_revdep_cache.R
#   Rscript R/clean_revdep_cache.R 2026-05-31
#   Rscript R/clean_revdep_cache.R 2026-05-22 2026-05-29 2026-05-31
#   Rscript R/clean_revdep_cache.R 2026-07-01/2026-07-10
#
# Note on Outlier Counts:
#   If you encounter outlier counts (e.g., extremely low counts for recent dates),
#   this is usually because the default EverCRAN snapshot mirror is down or
#   returning HTTP 500 errors, causing R's available.packages() to fall back
#   to an incomplete local crancache.
#
#   To resolve this, you can switch the snapshot source to PPPM (Posit Package
#   Manager) for the statistics script. First, clear the cache for those dates:
#     Rscript R/clean_revdep_cache.R 2026-07-01/2026-07-12
#   Then run the stats script with PPPM configured:
#     R_REVDEPCHECK_EXTRAS_SNAPSHOT_SOURCE=PPPM Rscript R/revdep_over_time.R
#
#   (Do not use PPPM by default for the entire history since PPPM snapshots only
#   go back to October 2017, whereas the stats script starts at 2015-06-19).

library(R.cache)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
  # Default to clearing today's date if no date is specified
  dates <- Sys.Date()
} else {
  dates <- as.Date(character(0))
  for (arg in args) {
    if (grepl("/", arg)) {
      # ISO-date range: start/end
      parts <- strsplit(arg, split = "/", fixed = TRUE)[[1]]
      if (length(parts) != 2L) {
        stop(sprintf("Invalid ISO-date range: %s", arg))
      }
      start <- as.Date(parts[1])
      end <- as.Date(parts[2])
      if (is.na(start) || is.na(end)) {
        stop(sprintf("Invalid date(s) in range: %s", arg))
      }
      if (start > end) {
        stop(sprintf("Start date must be before or equal to end date in range: %s", arg))
      }
      dates <- c(dates, seq(from = start, to = end, by = "days"))
    } else {
      date <- as.Date(arg)
      if (is.na(date)) {
        stop(sprintf("Invalid date: %s", arg))
      }
      dates <- c(dates, date)
    }
  }
  dates <- unique(dates)
}

pkgs <- c("parallel", "foreach", "doParallel", "future", "future.apply", "furrr", "doFuture", "parallelly", "progressr")
dirs <- c("revdepcheck.extras", "revdep_over_time")
dirs_pkg <- c(dirs, "packages")

cat(sprintf("Clearing revdepcache for %d date(s):\n", length(dates)))

for (date in dates) {
  date_str <- format(as.Date(date, origin = "1970-01-01"), "%F")
  
  # Remove cache for all known snapshot mirrors
  for (mirror in c("EverCRAN", "PPPM")) {
    oopts <- options(revdepcheck.extras.snapshot.source = mirror)
    mran_repos <- tryCatch(
      revdepcheck.extras:::getSnapshotURL(as.Date(date, origin = "1970-01-01"), online = FALSE),
      error = function(e) NULL
    )
    options(oopts)
    if (is.null(mran_repos)) next
    
    repos <- c(CRAN = mran_repos)
    
    # Remove overall cache
    key <- list(method = "revdep_over_time", pkgs = pkgs, repos = repos)
    p <- findCache(key = key, dirs = dirs)
    if (!is.null(p) && file.exists(p)) {
      cat(sprintf("  Removing overall cache for %s (%s): %s\n", date_str, mirror, basename(p)))
      file.remove(p)
    }
    
    # Remove package-specific cache
    for (pkg in pkgs) {
      key_pkg <- list(method = "revdep_over_time", pkg = pkg, repos = repos)
      p_pkg <- findCache(key = key_pkg, dirs = dirs_pkg)
      if (!is.null(p_pkg) && file.exists(p_pkg)) {
        cat(sprintf("  Removing %s cache for %s (%s): %s\n", pkg, date_str, mirror, basename(p_pkg)))
        file.remove(p_pkg)
      }
    }
  }

  # Remove crancache metadata cache if crancache is installed
  if (requireNamespace("crancache", quietly = TRUE)) {
    cache_dir <- crancache::get_cache_dir()
    path <- normalizePath(cache_dir, mustWork = FALSE)
    while (basename(path) != "R-crancache" && path != dirname(path)) {
      path <- dirname(path)
    }
    if (dir.exists(path)) {
      meta_dirs <- list.files(path, pattern = "^_meta$", recursive = TRUE, include.dirs = TRUE, all.files = TRUE, full.names = TRUE)
      for (meta_dir in meta_dirs) {
        if (dir.exists(meta_dir)) {
          dirs_to_remove <- list.files(meta_dir, pattern = date_str, full.names = TRUE)
          dirs_to_remove <- dirs_to_remove[file.info(dirs_to_remove)$isdir]
          for (d in dirs_to_remove) {
            cat(sprintf("  Removing crancache metadata cache for %s: %s\n", date_str, basename(d)))
            unlink(d, recursive = TRUE, force = TRUE)
          }
        }
      }
    }
  }
}
cat("Done!\n")
