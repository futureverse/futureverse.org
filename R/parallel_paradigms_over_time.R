## Fraction of CRAN packages that parallelize by *multi-processing* (several
## R processes) versus by *multi-threading* (several threads inside one
## process), over time.
##
## Produces a 0-100% stacked area graph, where 100% is all CRAN packages at
## that point in time.  The three coloured bands are mutually exclusive, so
## the stack sums to the exact fraction of CRAN that parallelizes at all.
##
## IMPORTANT - the multi-threading band is a *lower bound*.  It counts the
## packages that declare a threading dependency (RcppParallel, RcppThread,
## ...).  It cannot see the packages that reach for OpenMP directly from
## src/Makevars via $(SHLIB_OPENMP_*FLAGS), which is how most threaded R
## packages do it: only 26 packages on CRAN today mention OpenMP in
## SystemRequirements, and no historical package index carries that field
## anyway.  Multi-processing, by contrast, always goes through a package and
## is therefore counted in full.

source("R/cran_snapshots.R")


## ---------------------------------------------------------------------
## Which paradigm does each framework provide?
##
## 'foreach' and 'doRNG' are left out for the same reason as in the
## per-framework graph: neither parallelizes on its own.  'nanonext' is a
## transport layer.
## ---------------------------------------------------------------------
paradigm <- c(
  ## Separate R processes - forked, PSOCK, MPI ranks, or queued batch jobs
  parallel          = "multi-processing",
  snow              = "multi-processing",
  multicore         = "multi-processing",
  Rmpi              = "multi-processing",
  snowfall          = "multi-processing",
  nws               = "multi-processing",
  doParallel        = "multi-processing",
  doMC              = "multi-processing",
  doSNOW            = "multi-processing",
  doMPI             = "multi-processing",
  doRedis           = "multi-processing",
  doAzureParallel   = "multi-processing",
  future            = "multi-processing",
  future.apply      = "multi-processing",
  furrr             = "multi-processing",
  doFuture          = "multi-processing",
  parallelly        = "multi-processing",
  future.batchtools = "multi-processing",
  future.callr      = "multi-processing",
  future.mirai      = "multi-processing",
  future.mapreduce  = "multi-processing",
  futureverse       = "multi-processing",
  mirai             = "multi-processing",
  crew              = "multi-processing",
  crew.cluster      = "multi-processing",
  batchtools        = "multi-processing",
  BatchJobs         = "multi-processing",
  clustermq         = "multi-processing",
  rslurm            = "multi-processing",
  batch             = "multi-processing",
  parallelMap       = "multi-processing",
  ## Threads inside a single R process, at the C/C++ level
  RcppParallel      = "multi-threading",
  RcppThread        = "multi-threading"
)

## 'RhpcBLASctl' and 'OpenMPController' are collected but deliberately not
## classified: they control how many threads BLAS and OpenMP may use, which
## is most often done to *suppress* nested threading while forking.  Of the
## 19 packages that depend on them without also depending on a threading
## engine, 11 are multi-processing packages doing exactly that.

data <- filter(data, framework %in% names(paradigm))
data <- mutate(data, paradigm = unname(paradigm[framework]))

levels <- c("multi-processing", "both", "multi-threading", "no parallelism")

build_counts <- function(kind) {
  this <- filter(data, kind == !!kind)

  ## One row per date and dependent package, saying which paradigms it
  ## reaches for.  A package doing both lands in its own band, so the three
  ## bands stay mutually exclusive and the stack sums to the true total.
  classes <- this |>
    group_by(date, package) |>
    summarize(
      procs   = any(paradigm == "multi-processing"),
      threads = any(paradigm == "multi-threading"),
      .groups = "drop"
    ) |>
    mutate(class = case_when(
      procs & threads ~ "both",
      procs           ~ "multi-processing",
      threads         ~ "multi-threading"
    ))

  counts <- classes |>
    count(date, class, name = "packages") |>
    tidyr::complete(date = totals_all$date, class = setdiff(levels, "no parallelism"),
                    fill = list(packages = 0L)) |>
    left_join(totals_all, by = "date") |>
    mutate(fraction = packages / total)

  none <- counts |>
    group_by(date) |>
    summarize(total = first(total), any = sum(packages), .groups = "drop") |>
    transmute(date, class = "no parallelism", packages = total - any,
              total, fraction = 1 - any / total)

  counts <- bind_rows(counts, none)
  counts <- mutate(counts, kind = !!kind, class = factor(class, levels = levels))
  arrange(counts, date, class)
}

counts_by_kind <- lapply(kind_order, FUN = build_counts)
names(counts_by_kind) <- kind_order

write_tsv(bind_rows(counts_by_kind),
          file = file.path(path, "parallel_paradigms_over_time.tsv"))


## ---------------------------------------------------------------------
## Plot
##
## Three hues validated all-pairs for colour-vision deficiency on the light
## surface: worst pair CVD dE 9.2, normal-vision dE 24.0.  The aqua sits
## below 3:1 against the surface, so every band is also directly labelled.
## ---------------------------------------------------------------------
colors <- c(
  "multi-processing" = "#2A78D6",
  "both"             = "#EB6834",
  "multi-threading"  = "#1BAF7A",
  "no parallelism"   = "#E7E5E0"
)

surface <- "#FCFCFB"

caption <- paste0(
  "Multi-threading is a lower bound: it counts the packages that declare a ",
  "threading engine (RcppParallel, RcppThread). Packages that call OpenMP ",
  "straight from src/Makevars are invisible to every historical CRAN index, ",
  "so the real multi-threading share is higher. Multi-processing always goes ",
  "through a package, and is counted in full."
)
caption <- paste(strwrap(caption, width = 132), collapse = "\n")

label_at <- function(data) {
  data |>
    filter(date == max(date), class != "no parallelism") |>
    arrange(class) |>
    mutate(y = cumsum(fraction) - fraction / 2,
           label = sprintf("%s\n%.1f%%", class, 100 * fraction))
}

gg_base <- function(data, kind) {
  labels <- label_at(data)
  gg <- ggplot(data, aes(x = date, y = fraction, fill = class))
  gg <- gg + geom_area(position = position_stack(reverse = TRUE),
                       colour = surface, linewidth = 0.25)
  gg <- gg + scale_fill_manual(values = colors, breaks = rev(levels))
  gg <- gg + scale_x_date(
    breaks = seq(as.Date("2010-01-01"),
                 as.Date(format(Sys.Date(), "%Y-01-01")), by = "2 years"),
    date_labels = "%Y", expand = expansion(mult = c(0, 0.34))
  )
  gg <- gg + ggrepel::geom_text_repel(
    data = labels, aes(x = max(data$date), y = y, label = label,
                       colour = class),
    hjust = 0, size = 4.0, fontface = "bold", direction = "y",
    nudge_x = 120, min.segment.length = 0.4, segment.size = 0.3,
    segment.colour = "#A8A6A0", box.padding = 0.14, seed = 1L,
    show.legend = FALSE, inherit.aes = FALSE
  )
  gg <- gg + scale_colour_manual(values = colors, guide = "none")
  gg <- gg + labs(x = NULL, y = "Fraction of all CRAN packages",
                  title = sprintf("Parallelism on CRAN, by %s", kind_label[[kind]]),
                  caption = caption)
  gg <- gg + guides(fill = guide_legend(title = "Parallelizes by:"))
  gg <- gg + theme_minimal(base_size = 15)
  gg <- gg + theme(
    plot.background   = element_rect(fill = surface, colour = NA),
    panel.background  = element_rect(fill = surface, colour = NA),
    panel.grid.minor  = element_blank(),
    panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "#E3E1DC", linewidth = 0.4),
    axis.text         = element_text(size = 14, colour = "#52514E"),
    axis.title        = element_text(size = 15, colour = "#0B0B0B", face = "bold"),
    legend.text       = element_text(size = 12, colour = "#0B0B0B"),
    legend.title      = element_text(size = 13, colour = "#0B0B0B", face = "bold"),
    legend.key.size   = unit(14, "pt"),
    plot.title        = element_text(size = 15, colour = "#0B0B0B", face = "bold",
                                     margin = margin(b = 10)),
    plot.title.position = "plot",
    plot.caption      = element_text(size = 11, colour = "#52514E", hjust = 0,
                                     margin = margin(t = 10), lineheight = 1.15),
    plot.caption.position = "plot",
    plot.margin       = margin(t = 8, r = 10, b = 8, l = 6, unit = "pt")
  )
  gg
}

image_dims <- c(10.0, 6.0)

## Shared zoom ceiling, so the hard and soft figures are on one scale
zoom_ymax <- max(vapply(counts_by_kind, FUN = function(counts) {
  counts |>
    filter(class != "no parallelism") |>
    group_by(date) |>
    summarize(y = sum(fraction), .groups = "drop") |>
    pull(y) |>
    max()
}, FUN.VALUE = NA_real_))

make_charts <- function(kind) {
  counts <- counts_by_kind[[kind]]
  suffix <- if (kind == "hard") "" else paste0("-", kind)

  ## Full 0-100% stack
  latest_share <- with(filter(counts, date == max(date),
                              class == "no parallelism"), 1 - fraction)
  gg <- gg_base(counts, kind)
  gg <- gg + annotate(
    "segment", x = max(counts$date), xend = max(counts$date) + 140,
    y = latest_share, yend = latest_share, colour = "#A8A6A0", linewidth = 0.3
  )
  gg <- gg + annotate(
    "text", x = max(counts$date) + 150, y = latest_share, hjust = 0, vjust = -0.4,
    label = sprintf("%.1f%% of CRAN", 100 * latest_share),
    size = 4.6, fontface = "bold", colour = "#0B0B0B"
  )
  ## No explicit limits: the bands sum to 1 only up to floating point, and a
  ## cumulative 1+1e-16 would put the top of the stack outside c(0, 1) and get
  ## it silently dropped.
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                breaks = seq(0, 1, by = 0.25))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_paradigms_over_time_on_CRAN%s.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)

  ## Zoomed in on the packages that parallelize at all
  zoom <- filter(counts, class != "no parallelism")
  gg <- gg_base(zoom, kind)
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                limits = c(0, 1.02 * zoom_ymax))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_paradigms_over_time_on_CRAN%s-zoom.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)
}

for (kind in kind_order) make_charts(kind)


## ---------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------
for (kind in kind_order) {
  message(sprintf("\n%s dependencies, every second year:", kind))
  wide <- counts_by_kind[[kind]] |>
    filter(format(date, "%m-%d") == "01-01" | date == max(date)) |>
    select(date, class, packages, total) |>
    tidyr::pivot_wider(names_from = class, values_from = packages)
  print(as.data.frame(wide), row.names = FALSE)
}
