suppressPackageStartupMessages({
  library(revdepcheck.extras)
  library(tidyr)
  library(dplyr)
  library(tibble)
  library(ggplot2)
  library(progressr)
})
source("R/gg_modify.R")

future::plan("multicore")

handlers(global = TRUE)
if (requireNamespace("cli", quietly = TRUE)) {
  handlers(handler_cli(format = "{cli::pb_spin} {cli::pb_current}/{cli::pb_total} {cli::pb_bar} {cli::pb_percent} {cli::pb_status} {cli::pb_eta}"))
} else if (requireNamespace("progress", quietly = TRUE)) {
  handlers(handler_progress(format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta"))
}

options(ggmode = c("presentation", "website")[2])

## All packages of interest
all_pkgs <- c("parallel", "foreach", "doParallel", "future", "future.apply", "furrr", "doFuture")
plot_pkgs <- c("foreach", "doParallel", "future", "future.apply", "furrr")
exclude <- NULL
exclude <- c(exclude, "doParallel")
## exclude <- c(exclude, "foreach")



first_release <- as.Date(c(
       "foreach" = "2009-06-27",
        "doSNOW" = "2009-08-21",
    "doParallel" = "2011-12-07",
        "future" = "2015-06-19",
      "doFuture" = "2016-06-25",
  "future.apply" = "2018-01-15",
         "furrr" = "2018-05-16"
))

## Count package dependencies
pkgs <- all_pkgs

from <- first_release[["future"]]
until <- Sys.Date()
#until <- as.Date("2023-10-31")

dates <- c(seq(from, until, by = 7), until)
stats <- revdep_over_time(dates, pkgs = pkgs)
stats0 <- stats
for (kk in which(sapply(stats, FUN = is.integer))) {
  x <- stats[[kk]]
  x[is.na(x) | x <= 1L] <- NA_integer_
  stats[[kk]] <- x
}
stats <- stats[!duplicated(stats$date), ]

counts_all <- tidyr::gather(stats, package, count, -1, factor_key = TRUE)
counts_all <- as_tibble(counts_all)
counts_all <- group_by(counts_all, package)

repeat {
  counts_all <- mutate(counts_all, diff = count - lag(count), change = diff / count)
  drop <- which(counts_all$change < -2)
  if (length(drop) == 0) break
  counts_all <- counts_all[-drop, ]
}

## Drop "false" data points
for (pkg in names(first_release)) {
  counts_all <- subset(counts_all, !(package == pkg & date < first_release[pkg]))
}

pkgs <- setdiff(plot_pkgs, exclude)
counts_all <- subset(counts_all, package %in% pkgs)
npkgs <- length(unique(counts_all$package))
if (npkgs == 1L) {
  colors <- "#663399"
} else {
  colors <- scales::hue_pal()(npkgs+1)[-1]
}
names(colors) <- pkgs
if (npkgs == 1L) colors <- rep(colors, length.out = 2)
print(colors)

## Non-log scale
counts <- subset(counts_all, package %in% plot_pkgs)
counts <- subset(counts_all, ! package %in% c(exclude, "foreach"))
gg <- ggplot(counts, aes(x = date, y = count, color = package))
#gg <- gg + scale_colour_manual(values = colors)
gg <- gg + scale_colour_manual(values = colors, aesthetics = c("color"))
gg <- gg_modify(gg, legend = "upper-left")
gg <- gg + theme(legend.position = if (npkgs == 1L) "none" else "inside")
image_dims <- attr(gg, "image_dims")
gg <- gg + scale_colour_manual(values = colors[-1], aesthetics = c("color"))
gg <- gg + theme(plot.margin = margin(t = 5, r = 20, b = -15, l = 5, unit = "pt"))
pathname <- ggsave(gg, filename = "revdep_over_time_on_CRAN.png", width = image_dims[1], height = image_dims[2])
message("Wrote: ", pathname)


## Log scale
counts <- subset(counts_all, package %in% plot_pkgs)
gg <- ggplot(counts, aes(x = date, y = count, color = package))
gg <- gg + scale_colour_manual(values = colors)
gg <- gg + scale_y_log10()
gg <- gg_modify(gg, legend = "lower-right")
gg <- gg + theme(legend.position = if (npkgs == 1L) "none" else "inside")
gg <- gg + theme(plot.margin = margin(t = 5, r = 20, b = -15, l = 5, unit = "pt"))
image_dims <- attr(gg, "image_dims")
pathname <- ggsave(gg, filename = "revdep_over_time_on_CRAN-log.png", width = image_dims[1], height = image_dims[2])
message("Wrote: ", pathname)

message("Number of reverse dependencies:")
print(tail(stats, n = 20L))

message("Growth:")
rstats <- lapply(tail(stats, n = 20L), FUN = function(x) {
  if (is.numeric(x)) x <- x / x[1]
  x
})
rstats <- as.data.frame(rstats)
print(rstats, digits = 3)

if (FALSE) {
  message("Number of recursive reverse dependencies:")
  db <- utils::available.packages()  
  deps1 <- tools::package_dependencies(all_pkgs, which = "all", reverse = TRUE, recursive = FALSE, db = db)
  depsInf <- tools::package_dependencies(all_pkgs, which = "all", reverse = TRUE, recursive = TRUE, db = db)
}
