cran_package_names <- local({
  packages <- NULL
  function(repos = "https://cloud.r-project.org") {
    if (!is.null(packages)) return(packages)
    avail <- utils::available.packages(repos = repos)
    packages <<- sort(unique(rownames(avail)))
    packages
  }
}) # cran_package_names()

cran_all_downloads <- function(..., packages = cran_package_names(), chunk_size = 200L) {
  npkgs <- length(packages)
  nchunks <- npkgs/chunk_size
  chunks <- parallel::splitIndices(npkgs, nchunks)
  chunks <- lapply(chunks, FUN = function(chunk) packages[chunk])
  p <- progressr::progressor(along = chunks)
  stats <- future_lapply(chunks, FUN = function(pkgs, ...) {
    p()
    res <- tryCatch({
      cranlogs::cran_downloads(..., packages = pkgs)
    }, error = identity)
    if (inherits(res, "error")) {
      utils::str(list(...))
      return(NULL)
      stats <- lapply(pkgs, FUN = function(pkg, ...) {
        tryCatch({
          cranlogs::cran_downloads(..., packages = pkg)
        }, error = function(ex) {
          warning(sprintf("Failed to retrieve CRAN download stats for package '%s'", pkg))
          NULL
        })
      }, ...)
      res <- do.call(rbind, stats)
    }
    res
  }, ...)
  stats <- do.call(rbind, stats)
  if (nrow(stats) > 0) {
    stats$count <- as.integer(stats$count)
    stats <- subset(stats, count > 0)
  }
  stats <- tibble::as_tibble(stats)
  stats
} # cran_all_downloads()

#' @importFrom dplyr group_by summarize mutate rank n
#' @importFrom ISOweek ISOweek2date
#' @importFrom future.apply future_vapply
#' @importFrom progressr progressor
#' @importFrom utils file_test
cran_all_downloads_by_week <- function(weeks, path = file.path("cranlogs", "per-day")) {
  stopifnot(is.character(weeks), !anyNA(weeks))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  nweeks <- length(weeks)
  p <- progressr::progressor(along = weeks)
  pathnames <- vapply(weeks, FUN = function(week) {
    pathname <- file.path(path, sprintf("%s-per-day.tsv.gz", week))
    if (!utils::file_test("-f", pathname)) {
      p(sprintf("D: %s", week))
      from <- ISOweek::ISOweek2date(sprintf("%s-1", week))
      to <- from + 6L
      stopifnot(length(unique(format(c(from, to), format = "%G-W%V"))) == 1L)
      all <- cran_all_downloads(from = from, to = to)
      pathnameT <- sprintf("%s.tmp", pathname)
      write.table(all, file = gzfile(pathnameT), sep = "\t", quote = FALSE, row.names = FALSE)
      file.rename(pathnameT, pathname)
    } else {
      p(sprintf("d: %s", week))
    }
    pathname
  }, FUN.VALUE = NA_character_)
  pathnames
} ## cran_all_downloads_by_week()


#' @importFrom stats median
cran_all_downloads_summarize_by_week <- function(pathnames, method = c("sum", "mean", "median"), path = file.path("cranlogs", "per-week")) {
  method <- match.arg(method)
  fcn <- switch(method, sum = sum, mean = mean, median = stats::median)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  p <- progressr::progressor(along = pathnames)
  pathnames <- vapply(pathnames, FUN = function(src_pathname) {
    stopifnot(utils::file_test("-f", src_pathname))
    week <- gsub("-per.*", "", basename(src_pathname))
    pathname <- file.path(path, sprintf("%s-%s-per-week.tsv.gz", week, method))
    if (!utils::file_test("-f", pathname)) {
      p(sprintf("S: %s", week))
      col_types <- cols(
        date = col_date(format = ""),
        count = col_integer(),
        package = col_character()
      )
      data <- read_tsv(src_pathname, col_types = col_types)
      from <- data$date
      weeks <- unique(format(from, format = "%G-W%V"))
      stopifnot(all(weeks == weeks[1]))
      data <- group_by(data, package)
      data <- summarize(data, count = as.integer(fcn(count)))
      data$week_of <- min(from)
      from <- NULL
      data <- select(data, week_of, package, count)
      pathnameT <- sprintf("%s.tmp", pathname)
      write.table(data, file = gzfile(pathnameT), sep = "\t", quote = FALSE, row.names = FALSE)
      file.rename(pathnameT, pathname)
    } else {
      p(sprintf("s: %s", week))
    }
    pathname
  }, FUN.VALUE = NA_character_)
} # cran_all_downloads_sum_by_week()

cran_all_download_rank_by_week <- function(pathnames, path = file.path("cranlogs", "per-week-with-ranks")) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  stopifnot(all(utils::file_test("-f", pathnames)))

  weeks <- gsub("-per.*", "", basename(pathnames))
  pathnames_out <- file.path(path, sprintf("%s-per-week-with_ranks.tsv.gz", weeks))
  todo <- which(!utils::file_test("-f", pathnames_out))

  p <- progressr::progressor(along = todo)
  future_vapply(pathnames[todo], FUN = function(src_pathname) {
    stopifnot(utils::file_test("-f", src_pathname))
    pattern <- "^([[:digit:]]+-W[[:digit:]]+)-([[:alnum:]]+-per-week).*"
    week <- gsub(pattern, "\\1", basename(src_pathname))
    what <- gsub(pattern, "\\2", basename(src_pathname))
    pathname <- file.path(path,
                          sprintf("%s-%s-with_ranks.tsv.gz", week, what))
    if (!utils::file_test("-f", pathname)) {
      p(sprintf("R: %s",week))
      col_types <- cols(
        week_of = col_date(format = ""),
        count   = col_integer(),
        package = col_character()
      )
      data <- read_tsv(src_pathname, col_types = col_types)
      data <- group_by(data, package)
      data <- summarize(data, week_of = week_of, count = sum(count))
      data <- mutate(data, rank = n() - rank(count, ties.method = "min"), n = n(), fraction = rank/n)
      data <- select(data, week_of, package, count, fraction, rank, max = n)
      pathnameT <- sprintf("%s.tmp", pathname)
      write.table(data, file = gzfile(pathnameT), sep = "\t", quote = FALSE, row.names = FALSE)
      file.rename(pathnameT, pathname)
    } else {
      p(sprintf("r: %s",week))
    }
    pathname
  }, FUN.VALUE = NA_character_, future.chunk.size = 1L)
  stopifnot(all(utils::file_test("-f", pathnames_out)))
  
  pathnames_out
} # cran_all_download_rank_by_week()

read_final_cran_stats <- function(pathnames) {
  col_types <- cols(
    week_of = col_date(format = ""),
    package = col_character(),
    count = col_integer(),
    fraction = col_double(),
    rank = col_integer(),
    max = col_integer()
  )
  data <- lapply(pathnames, FUN = read_tsv, col_types = col_types)
  data <- do.call(rbind, data)
}
