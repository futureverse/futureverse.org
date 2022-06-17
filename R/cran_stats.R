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
