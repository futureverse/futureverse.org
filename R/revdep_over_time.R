library(revdepcheck.extras)
library(progressr)
future::plan("multicore")

handlers(global = TRUE)
handlers(handler_progress(
  format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta"
))

## Count package dependencies on CRAN
pkgs <- c("parallel", "foreach", "doParallel", "future", "future.apply", "furrr", "doFuture")
dates <- c(seq(as.Date("2015-06-19"), Sys.Date(), by=7), Sys.Date())
stats <- revdep_over_time(dates, pkgs = pkgs)
message("Number of CRAN reverse dependencies:")
print(tail(stats))

library(ggplot2)
counts_all <- tidyr::gather(stats, package, count, -1, factor_key = TRUE)
counts_all <- subset(counts_all, count > 1)

ncolors <- length(levels(counts_all$package))
colors <- scales::hue_pal()(ncolors)
names(colors) <- pkgs

## Non-log scale
counts <- subset(counts_all, package %in% c("future", "future.apply", "furrr"))
gg <- ggplot(counts, aes(x = date, y = count, color = package))
gg <- gg + geom_line(size = 1.2)
gg <- gg + scale_colour_manual(values = colors)
gg <- gg + labs(x = "Date", y = "Number of reverse dependencies on CRAN")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + theme(legend.position = c(0.14, 0.85))
gg <- gg + scale_colour_manual(values = colors, aesthetics = c("color"))
ggsave(gg, filename = "revdep_over_time_on_CRAN.png", width = 7.5, height = 6)


## Log scale
counts <- subset(counts_all, package %in% c("future", "future.apply", "furrr", "foreach")) ## , "doParallel", "parallel"))
gg <- ggplot(counts, aes(x = date, y = count, color = package))
gg <- gg + geom_line(size = 1.2)
gg <- gg + scale_colour_manual(values = colors)
gg <- gg + labs(x = "Date", y = "Number of reverse dependencies on CRAN")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + scale_y_log10()
gg <- gg + theme(legend.position = c(0.88, 0.15))
ggsave(gg, filename = "revdep_over_time_on_CRAN-log.png", width = 7.5, height = 6)
