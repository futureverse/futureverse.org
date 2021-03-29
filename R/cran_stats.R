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
  stats <- future_lapply(chunks, FUN = function(pkgs) {
    p()
    cranlogs::cran_downloads(..., packages = pkgs)
  })
  stats <- do.call(rbind, stats)
  stats$count <- as.integer(stats$count)
  stats <- subset(stats, count > 0)
  stats <- tibble::as_tibble(stats)
  stats
} # cran_all_downloads()

#' @importFrom dplyr group_by summarize mutate rank n
#' @importFrom ISOweek ISOweek2date
#' @importFrom future.apply future_vapply
#' @importFrom progressr progressor
#' @importFrom utils file_test
cran_all_downloads_by_week <- function(weeks, path = file.path("cranlogs", "weeks")) {
  stopifnot(is.character(weeks), !anyNA(weeks))
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  nweeks <- length(weeks)
  p <- progressr::progressor(along = weeks)
  pathnames <- vapply(weeks, FUN = function(week) {
    pathname <- file.path(path, sprintf("%s-per-day.tsv.gz", week))
    p(sprintf("D: %s",week))
    if (!utils::file_test("-f", pathname)) {
      from <- ISOweek::ISOweek2date(sprintf("%s-1", week))
      to <- from + 6L
      stopifnot(length(unique(format(c(from, to), format = "%G-W%V"))) == 1L)
      all <- cran_all_downloads(from = from, to = to)
      pathnameT <- sprintf("%s.tmp", pathname)
      write.table(all, file = gzfile(pathnameT), sep = "\t", quote = FALSE, row.names = FALSE)
      file.rename(pathnameT, pathname)
    }
    pathname
  }, FUN.VALUE = NA_character_)
  pathnames
} ## cran_all_downloads_by_week()


cran_all_downloads_sum_by_week <- function(pathnames) {
  p <- progressr::progressor(along = pathnames)
  pathnames <- vapply(pathnames, FUN = function(src_pathname) {
    stopifnot(utils::file_test("-f", src_pathname))
    week <- gsub("-per.*", "", basename(src_pathname))
    p(sprintf("S: %s",week))
    pathname <- file.path(dirname(src_pathname),
                          sprintf("%s-per-week.tsv.gz", week))
    if (!utils::file_test("-f", pathname)) {
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
      data <- summarize(data, count = as.integer(sum(count)))
      data$week_of <- min(from)
      from <- NULL
      data <- select(data, week_of, package, count)
      pathnameT <- sprintf("%s.tmp", pathname)
      write.table(data, file = gzfile(pathnameT), sep = "\t", quote = FALSE, row.names = FALSE)
      file.rename(pathnameT, pathname)
    }
    pathname
  }, FUN.VALUE = NA_character_)
} # cran_all_downloads_sum_by_week()

cran_all_download_rank_by_week <- function(pathnames) {
  p <- progressr::progressor(along = pathnames)
  future_vapply(pathnames, FUN = function(src_pathname) {
    stopifnot(utils::file_test("-f", src_pathname))
    week <- gsub("-per.*", "", basename(src_pathname))
    p(sprintf("R: %s",week))
    pathname <- file.path(dirname(src_pathname),
                          sprintf("%s-per-week-with_ranks.tsv.gz", week))
    if (!utils::file_test("-f", pathname)) {
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
    }
    pathname
  }, FUN.VALUE = NA_character_, future.chunk.size = 1L)
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

library(cranlogs)
library(dplyr)
library(readr)
library(tibble)
library(ggplot2)
library(future.apply)

future::plan("multisession", workers = 3)
#future::plan("sequential")

library(progressr)
handlers(global = TRUE)
handlers(handler_progress(format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta"))

## Get (week, from, to) since beginning of 'future'
dates <- seq(as.Date("2015-06-19") + 3L, Sys.Date(), by = 7L)
weeks <- unique(format(dates, format = "%G-W%V"))

pathnames_per_day <- cran_all_downloads_by_week(weeks)
pathnames_per_week <- cran_all_downloads_sum_by_week(pathnames_per_day)
pathnames_per_week_with_ranks <- cran_all_download_rank_by_week(pathnames_per_week)

data <- read_final_cran_stats(pathnames_per_week_with_ranks)

pkgs <- c("future", "future.apply", "furrr", "foreach")
counts <- subset(data, package %in% pkgs)
counts <- select(counts, week_of, package, fraction)
counts <- mutate(counts, package = factor(package, levels = pkgs))
counts <- group_by(counts, package)

## Average every four weeks (assuming there are no missing entries)
counts4 <- group_modify(counts, function(data, package) {
  chunks <- parallel::splitIndices(nrow(data), nrow(data)/4)
  res <- lapply(chunks, FUN = function(chunk) {
    t <- data[chunk, ]
    data.frame(week_of = t$week_of[1], fraction = mean(t$fraction, na.rm = TRUE))
  })
  do.call(rbind, res)
})



gg <- ggplot(counts4, aes(x = week_of, y = fraction, color = package))
gg <- gg + geom_line(size = 1.2)
#gg <- gg + geom_smooth(method = "loess", span = 0.1)
#gg <- gg + geom_smooth(method = lm, formula = y ~ splines::bs(x, 3), se = FALSE)
gg <- gg + labs(x = "Date", y = "Download ranks on CRAN (four-week averages)")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + theme(legend.position = c(0.88, 0.15))
gg <- gg + scale_y_reverse(labels = scales::percent)
gg <- gg + coord_cartesian(ylim = c(0.20, 0))
ggsave(gg, filename = "downloads_over_time_on_CRAN.png", width = 7.5, height = 6)
