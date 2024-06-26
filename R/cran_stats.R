suppressPackageStartupMessages({
  library(cranlogs)
  library(dplyr)
  library(readr)
  library(tibble)
  library(ggplot2)
  library(future.apply)
  library(progressr)
})
source("R/cran_utils.R")
source("R/gg_modify.R")

future::plan("multisession", workers = 3)
#future::plan("sequential")

handlers(global = TRUE)
if (requireNamespace("cli", quietly = TRUE)) {
  handlers(handler_cli(format = "{cli::pb_spin} {cli::pb_current}/{cli::pb_total} {cli::pb_bar} {cli::pb_percent} {cli::pb_status} {cli::pb_eta}"))
} else if (requireNamespace("progress", quietly = TRUE)) {
  handlers(handler_progress(format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta"))
}


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

## all_pkgs <- c("matrixStats")

pkgs <- setdiff(all_pkgs, "parallel") ## 'parallel' is part of R
counts <- subset(data, package %in% pkgs)
counts <- select(counts, week_of, package, fraction)
counts <- mutate(counts, package = factor(package, levels = pkgs))
counts <- group_by(counts, package)

## Average every four weeks (assuming there are no missing entries)
counts4 <- group_modify(counts, function(data, package) {
  chunks <- parallel::splitIndices(nrow(data), nrow(data)/4)
  p <- progressor(along = chunks)
  res <- lapply(chunks, FUN = function(chunk) {
    p()
    t <- data[chunk, ]
    data.frame(week_of = t$week_of[1], fraction = mean(t$fraction, na.rm = TRUE))
  })
  do.call(rbind, res)
})

message(sprintf("CRAN ranks last four week (average '%s' per week):", method))
print(head(arrange(counts4, desc(week_of)), n = 2*length(pkgs)))


pkgs <- c("foreach", "doParallel", "future", "future.apply", "furrr")
exclude <- NULL
exclude <- c(exclude, "doParallel")
pkgs <- setdiff(pkgs, exclude)
colors <- scales::hue_pal()(length(pkgs)+1)[-1]
names(colors) <- pkgs

image_dims <- c(7.5, 6.0)
#image_dims <- 0.7*image_dims

counts4b <- subset(counts4, package %in% pkgs)
gg <- ggplot(counts4b, aes(x = week_of, y = fraction, color = package))
gg <- gg + geom_line(linewidth = 1.2)
gg <- gg + scale_colour_manual(values = colors)
#gg <- gg + geom_smooth(method = "loess", span = 0.1)
#gg <- gg + geom_smooth(method = lm, formula = y ~ splines::bs(x, 3), se = FALSE)
gg <- gg + scale_y_reverse(labels = scales::percent)
gg <- gg_modify(gg, legend = "lower-right")
image_dims <- attr(gg, "image_dims")
gg <- gg + labs(x = "", y = "Download rank (4-week avg.)")
gg <- gg + coord_cartesian(ylim = c(0.20, 0))
gg <- gg + theme(plot.margin = margin(t = 5, r = 20, b = -15, l = 5, unit = "pt"))
pathname <- ggsave(gg, filename = "downloads_over_time_on_CRAN.png", width = image_dims[1], height = image_dims[2])
message("Wrote: ", pathname)


gg <- gg + coord_cartesian(ylim = c(0.03, 0))
gg <- gg + theme(plot.margin = margin(t = 5, r = 20, b = -15, l = 5, unit = "pt"))
pathname <- ggsave(gg, filename = "downloads_over_time_on_CRAN-zoom.png", width = image_dims[1], height = image_dims[2])
message("Wrote: ", pathname)
