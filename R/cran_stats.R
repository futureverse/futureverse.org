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
## Drop current week
weeks <- weeks[-length(weeks)]

method <- "median"
pathnames_per_day <- cran_all_downloads_by_week(weeks)
pathnames_per_week <- cran_all_downloads_summarize_by_week(pathnames_per_day, method = method)
pathnames_per_week_with_ranks <- cran_all_download_rank_by_week(pathnames_per_week)

data <- read_final_cran_stats(pathnames_per_week_with_ranks)


all_pkgs <- c("parallel", "foreach", "doParallel", "future", "future.apply", "furrr", "doFuture", "progressr")

pkgs <- setdiff(all_pkgs, "parallel") ## 'parallel' is part of R
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

message(sprintf("CRAN ranks last four week (average '%s' per week):", method))
print(head(arrange(counts4, desc(week_of)), n = 2*length(pkgs)))


pkgs <- c("foreach", "future", "future.apply", "furrr")
exclude <- NULL
pkgs <- setdiff(pkgs, exclude)
colors <- scales::hue_pal()(length(pkgs)+1)[-1]
names(colors) <- pkgs

image_dims <- c(7.5, 6.0)
#image_dims <- 0.7*image_dims

counts4b <- subset(counts4, package %in% pkgs)
gg <- ggplot(counts4b, aes(x = week_of, y = fraction, color = package))
gg <- gg + geom_line(size = 1.2)
gg <- gg + scale_colour_manual(values = colors)
#gg <- gg + geom_smooth(method = "loess", span = 0.1)
#gg <- gg + geom_smooth(method = lm, formula = y ~ splines::bs(x, 3), se = FALSE)
gg <- gg + labs(x = "Date", y = "Download ranks on CRAN (four-week averages)")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + theme(legend.position = c(0.88, 0.15))
#gg <- gg + theme(legend.position = c(0.14, 0.85))
gg <- gg + scale_y_reverse(labels = scales::percent)
gg <- gg + coord_cartesian(ylim = c(0.20, 0))
ggsave(gg, filename = "downloads_over_time_on_CRAN.png", width = image_dims[1], height = image_dims[2])
