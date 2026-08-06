## Shared data layer: for a monthly series of CRAN snapshots, who hard-depends
## (Depends, Imports, LinkingTo) on 'parallel' or on a CRAN package that
## implements a parallel framework in R?
##
## Sourced by R/parallel_frameworks_over_time.R and
## R/parallel_paradigms_over_time.R.  Leaves behind:
##   data   - one row per date/framework/dependent package
##   totals is left to the callers, since they slice 'data' differently

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(readr)
  library(ggplot2)
  library(future)
  library(future.apply)
  library(progressr)
})
options(width = 120)

plan("multicore")

handlers(global = TRUE)
if (requireNamespace("cli", quietly = TRUE)) {
  handlers(handler_cli(format = "{cli::pb_spin} {cli::pb_current}/{cli::pb_total} {cli::pb_bar} {cli::pb_percent} {cli::pb_status} {cli::pb_eta}"))
}

path <- file.path("cranlogs", "parallel-frameworks")
dir.create(path, recursive = TRUE, showWarnings = FALSE)


## ---------------------------------------------------------------------
## The packages that implement, or give direct access to, a parallel
## framework in R.  Grouped only for readability; each is counted on its own.
## ---------------------------------------------------------------------
frameworks <- c(
  ## base R and its predecessors
  "parallel", "snow", "multicore", "Rmpi", "snowfall", "nws",
  ## foreach adaptors
  "foreach", "doParallel", "doMC", "doSNOW", "doMPI", "doRedis",
  "doAzureParallel", "doRNG",
  ## Futureverse
  "future", "future.apply", "furrr", "doFuture", "parallelly",
  "future.batchtools", "future.callr", "future.mirai", "future.mapreduce",
  "futureverse",
  ## mirai / NNG
  "mirai", "crew", "crew.cluster", "nanonext",
  ## HPC schedulers and batch systems
  "batchtools", "BatchJobs", "clustermq", "rslurm", "batch", "parallelMap",
  ## C/C++ level threading
  "RcppParallel", "RcppThread", "RhpcBLASctl", "OpenMPController"
)

## How binding is the dependency?
kinds <- list(
  hard = c("Depends", "Imports", "LinkingTo"),
  soft = "Suggests"
)


## ---------------------------------------------------------------------
## CRAN snapshots
##
## Posit Public Package Manager (PPPM) is a true point-in-time snapshot of
## CRAN, but it only reaches back to 2017-10.  EverCRAN reaches back to the
## very beginning, but it is cumulative: its snapshot for date D also serves
## every package that had already been archived by D.  Left uncorrected, that
## inflates the denominator by ~11% at the 2017 handover and puts a visible
## step in the curve.
##
## So for the EverCRAN era we drop the packages that CRAN had already
## archived by that date, using the archival dates recorded by crandb.  A
## package that is on CRAN today is never dropped, which slightly overcounts
## the few packages that were archived and later restored.  The correction
## lands within ~6% of the EverCRAN-minus-PPPM difference on every date where
## both sources exist.
## ---------------------------------------------------------------------
pppm_from <- as.Date("2017-11-01")

snapshot_url <- function(date) {
  if (date >= pppm_from) {
    format(date, "https://packagemanager.posit.co/cran/%Y-%m-%d")
  } else {
    format(date, "https://evercran.r-pkg.org/%Y/%m/%d")
  }
}

## package -> date first archived by CRAN (NA = archived before crandb's
## records begin, i.e. archived from the start as far as we are concerned)
cran_archivals <- local({
  pathname <- file.path(path, "cran-archivals.tsv.gz")
  if (!utils::file_test("-f", pathname)) {
    url <- "https://crandb.r-pkg.org/-/archivals?limit=100000&descending=true"
    events <- jsonlite::fromJSON(url, simplifyVector = FALSE)
    data <- tibble(
      package = vapply(events, FUN = `[[`, "name", FUN.VALUE = NA_character_),
      date    = vapply(events, FUN = function(e) {
        if (is.null(e$date)) NA_character_ else substr(e$date, 1, 10)
      }, FUN.VALUE = NA_character_)
    )
    data <- summarize(group_by(data, package),
                      archived = suppressWarnings(min(as.Date(date), na.rm = TRUE)))
    data$archived[!is.finite(data$archived)] <- as.Date("1990-01-01")
    write_tsv(data, file = pathname)
  }
  read_tsv(pathname, col_types = cols(package = col_character(),
                                      archived = col_date()))
})
message("CRAN archivals on record: ", nrow(cran_archivals))

## Packages on CRAN right now; these are never treated as archived
cran_today <- rownames(available.packages(repos = "https://cloud.r-project.org"))

drop_archived <- function(db, date) {
  gone <- filter(cran_archivals, archived <= date)$package
  gone <- setdiff(gone, cran_today)
  db[!rownames(db) %in% gone, , drop = FALSE]
}

from <- as.Date("2010-01-01")
until <- Sys.Date() - 1L
dates <- seq(from, until, by = "1 month")
dates <- c(dates, until)
dates <- unique(dates)


## Reverse dependencies of every framework, as of one snapshot date, split by
## how binding the dependency is.  A hard dependency drags the framework in
## whether the user wants it or not; a soft one only offers it, and the
## package still installs and works without it.  'Enhances' is left out: it
## says "I improve that package", which is not the same statement.
revdeps_on_date <- function(date) {
  pathname <- file.path(path, sprintf("%s-revdeps-v4.tsv.gz", format(date, "%Y-%m-%d")))
  if (utils::file_test("-f", pathname)) return(pathname)

  repos <- snapshot_url(date)
  db <- tryCatch(available.packages(repos = repos), error = identity)
  if (inherits(db, "error") || nrow(db) == 0L) {
    warning(sprintf("No CRAN snapshot for %s (%s)", date, repos))
    return(NA_character_)
  }
  if (date < pppm_from) db <- drop_archived(db, date)

  data <- lapply(names(kinds), FUN = function(kind) {
    revdeps <- tools::package_dependencies(frameworks, reverse = TRUE,
                                           which = kinds[[kind]], db = db)
    tibble(
      date      = date,
      total     = nrow(db),
      kind      = kind,
      framework = rep(names(revdeps), times = lengths(revdeps)),
      package   = unlist(revdeps, use.names = FALSE)
    )
  })
  data <- bind_rows(data)
  ## Dates with no revdeps at all must still record the CRAN size
  if (nrow(data) == 0L) {
    data <- tibble(date = date, total = nrow(db), kind = NA_character_,
                   framework = NA_character_, package = NA_character_)
  }

  pathnameT <- sprintf("%s.tmp", pathname)
  write_tsv(data, file = pathnameT)
  file.rename(pathnameT, pathname)
  pathname
}

pathnames <- local({
  p <- progressor(along = dates)
  future_vapply(dates, FUN = function(date) {
    on.exit(p(format(date, "%Y-%m")))
    revdeps_on_date(date)
  }, FUN.VALUE = NA_character_, future.chunk.size = 1L)
})
pathnames <- pathnames[!is.na(pathnames)]

col_types <- cols(date = col_date(), total = col_integer(),
                  kind = col_character(), framework = col_character(),
                  package = col_character())
data <- lapply(pathnames, FUN = read_tsv, col_types = col_types)
data <- bind_rows(data)

## CRAN size per date, kept separately so it survives any slicing of 'data'
totals_all <- data |>
  group_by(date) |>
  summarize(total = first(total), .groups = "drop")

data <- filter(data, !is.na(framework))

## A third, derived kind: "any" is the union of hard and soft, so a package
## that both imports one framework and suggests another appears once per
## framework, exactly as it does within each kind on its own.  Derived rather
## than collected, since the union needs no extra snapshot round-trip.
data <- bind_rows(
  data,
  data |> distinct(date, total, framework, package) |> mutate(kind = "any")
)

## The kinds the charts iterate over, in the order they should be produced.
## 'kinds' above stays the *collection* spec and does not gain "any".
kind_order <- c("hard", "soft", "any")

## Human-readable names for the dependency kinds, used in titles and captions
kind_label <- c(hard = "hard dependency (Depends, Imports, LinkingTo)",
                soft = "soft dependency (Suggests)",
                any  = "any dependency (hard or soft)")
kind_short <- c(hard = "hard", soft = "soft", any = "any")

