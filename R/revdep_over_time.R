library(revdepcheck.extras)
library(progressr)

handlers(global = TRUE)
handlers(handler_progress(
  format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta"
))

## Count package dependencies on CRAN
pkgs <- c("future", "future.apply", "furrr", "doFuture")
dates <- c(seq(as.Date("2015-06-19"), Sys.Date(), by=7), Sys.Date())
stats <- revdep_over_time(dates, pkgs = pkgs)

library(ggplot2)
counts <- dplyr::select(stats, -doFuture)
counts <- tidyr::gather(counts, package, count, -1, factor_key = TRUE)
gg <- ggplot(counts)
gg <- gg + geom_line(aes(x = date, y = count, color = package), size = 1.2)
gg <- gg + labs(x = "Date", y = "Number of reverse dependencies on CRAN")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + theme(legend.position = c(0.14, 0.85))
ggsave(gg, filename = "revdep_over_time_on_CRAN.png", width = 7.5, height = 6)
