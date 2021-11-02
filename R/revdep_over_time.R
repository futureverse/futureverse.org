library(revdepcheck.extras)
library(tidyr)
library(dplyr)
library(ggplot2)
library(progressr)
future::plan("multicore")

handlers(global = TRUE)
handlers(handler_progress(
  format = ":spin :current/:total (:message) [:bar] :percent in :elapsed ETA: :eta"
))

## All packages of interest
all_pkgs <- c("parallel", "foreach", "doParallel", "future", "future.apply", "furrr", "doFuture")
plot_pkgs <- c("foreach", "doParallel", "future", "future.apply", "furrr")
exclude <- "doParallel"
exclude <- c(exclude, "foreach")

## Count package dependencies
pkgs <- all_pkgs
dates <- c(seq(as.Date("2015-06-19"), Sys.Date(), by=7), Sys.Date())
stats <- revdep_over_time(dates, pkgs = pkgs)

counts_all <- tidyr::gather(stats, package, count, -1, factor_key = TRUE)
counts_all <- subset(counts_all, count > 2)
counts_all <- subset(counts_all, !(package == "foreach" & count < 10))
excl_dates <- unique(subset(counts_all, date > "2018-01-01" & count <= 4)$date)
counts_all <- subset(counts_all, ! date %in% excl_dates)

pkgs <- setdiff(plot_pkgs, exclude)
counts_all <- subset(counts_all, package %in% pkgs)
ncolors <- length(unique(counts_all$package))
colors <- scales::hue_pal()(ncolors+1)[-1]
names(colors) <- pkgs

image_dims <- c(7.5, 6.0)
#image_dims <- 0.7*image_dims

## Non-log scale
counts <- subset(counts_all, package %in% plot_pkgs)
counts <- subset(counts_all, ! package %in% c(exclude, "foreach"))
gg <- ggplot(counts, aes(x = date, y = count, color = package))
gg <- gg + geom_line(size = 1.2)
#gg <- gg + scale_colour_manual(values = colors)
gg <- gg + scale_colour_manual(values = colors, aesthetics = c("color"))
gg <- gg + labs(x = "Date", y = "Number of reverse dependencies on CRAN")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + theme(legend.position = c(0.14, 0.85))
ggsave(gg, filename = "revdep_over_time_on_CRAN.png", width = image_dims[1], height = image_dims[2])


## Log scale
counts <- subset(counts_all, package %in% plot_pkgs)
#counts <- subset(counts_all, ! package %in% c(exclude, "foreach"))
gg <- ggplot(counts, aes(x = date, y = count, color = package))
gg <- gg + geom_line(size = 1.2)
gg <- gg + scale_colour_manual(values = colors)
gg <- gg + labs(x = "Date", y = "Number of reverse dependencies on CRAN")
gg <- gg + guides(col = guide_legend(title = "Package:"))
gg <- gg + scale_y_log10()
gg <- gg + theme(legend.position = c(0.88, 0.15))
ggsave(gg, filename = "revdep_over_time_on_CRAN-log.png", width = image_dims[1], height = image_dims[2])

message("Number of reverse dependencies:")
print(tail(stats, n = 20L))

if (FALSE) {
  message("Number of recursive reverse dependencies:")
  db <- utils::available.packages()  
  deps1 <- tools::package_dependencies(all_pkgs, which = "all", reverse = TRUE, recursive = FALSE, db = db)
  depsInf <- tools::package_dependencies(all_pkgs, which = "all", reverse = TRUE, recursive = TRUE, db = db)
}
