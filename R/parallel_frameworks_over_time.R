## Evolution of CRAN packages that depend on 'parallel' or on a CRAN package
## implementing a parallel framework in R, one band per package.
##
## Drawn twice: once for hard dependencies (Depends, Imports, LinkingTo) and
## once for soft ones (Suggests).  A hard dependency forces the framework on
## every user of the package; a soft one only offers it.  Bands, colours and
## the zoomed y-axis are shared between the two, so the pair can be read
## side by side.
##
## 100% is *all* CRAN packages at that point in time.  A package that depends
## on several frameworks is counted once per framework, i.e. the relative
## heights of the coloured bands are shares of dependency *edges*, whereas the
## total height of the stack is the exact fraction of CRAN packages with at
## least one such dependency.

source("R/cran_snapshots.R")


## ---------------------------------------------------------------------
## What to draw
##
## 'foreach' is an iteration API rather than a parallel backend - it is its
## do*() adaptors that parallelize - so it is left out to avoid counting the
## same packages twice over.  'doRNG' likewise only adds reproducible RNG on
## top of whatever backend is registered, and 'nanonext' is a transport layer.
##
## The remaining frameworks are shown one band each, bottom-up in roughly the
## order they arrived on CRAN.  The long tail is lumped into 'other'.  The
## named set is deliberately the same for both dependency kinds, even though
## the soft ranking differs, so that a band means the same thing in both.
## ---------------------------------------------------------------------
exclude <- c("foreach", "doRNG", "nanonext",
             ## thread *control*, not a parallel framework
             "RhpcBLASctl", "OpenMPController")
data <- filter(data, !framework %in% exclude)

## Bottom-up stacking order
named <- c("parallel", "doParallel", "doSNOW", "RcppParallel", "mirai",
           "parallelly", "future", "doFuture", "future.apply", "furrr")

## Spell 'other' out in the caption, biggest contributor first.  Computed
## across both kinds, so the two figures carry the same caption.
lumped <- data |>
  filter(!framework %in% named) |>
  count(date, kind, framework) |>
  group_by(framework) |>
  summarize(peak = max(n), .groups = "drop") |>
  arrange(desc(peak), framework)
message("Lumped into 'other':")
print(lumped, n = Inf)

caption <- paste0(
  "'other' is ", paste(lumped$framework, collapse = ", "), ".  ",
  "'foreach' and 'doRNG' are left out: neither parallelizes on its own, ",
  "so counting them would double-count their backends."
)
caption <- paste(strwrap(caption, width = 128), collapse = "\n")

levels <- c("other", named, "no dependency")
data <- mutate(data, framework = ifelse(framework %in% named, framework, "other"))


## ---------------------------------------------------------------------
## One stacked series per dependency kind
## ---------------------------------------------------------------------
build_counts <- function(kind) {
  this <- filter(data, kind == !!kind)

  ## CRAN size, and packages with >= 1 dependency of this kind
  totals <- this |>
    group_by(date) |>
    summarize(any = n_distinct(package), .groups = "drop") |>
    right_join(totals_all, by = "date") |>
    mutate(any = coalesce(any, 0L))

  ## Dependency edges per framework and date.  A package that depends on
  ## several frameworks contributes one edge to each of them.  Every
  ## framework/date cell must exist, or geom_area() stacks a ragged grid.
  edges <- this |>
    count(date, framework, name = "edges") |>
    tidyr::complete(date, framework, fill = list(edges = 0L))

  ## Bands: share of edges, scaled so the stack sums to any/total exactly
  counts <- edges |>
    group_by(date) |>
    mutate(share = edges / sum(edges)) |>
    ungroup() |>
    left_join(totals, by = "date") |>
    mutate(fraction = share * any / total)

  ## The unshaded remainder
  none <- totals |>
    transmute(date, framework = "no dependency",
              edges = NA_integer_, share = NA_real_,
              total, any, fraction = 1 - any / total)

  counts <- bind_rows(counts, none)
  counts <- mutate(counts, kind = !!kind,
                   framework = factor(framework, levels = levels))
  arrange(counts, date, framework)
}

counts_by_kind <- lapply(kind_order, FUN = build_counts)
names(counts_by_kind) <- kind_order

write_tsv(bind_rows(counts_by_kind),
          file = file.path(path, "parallel_frameworks_over_time.tsv"))


## ---------------------------------------------------------------------
## Plot
##
## Categorical palette, hand-assigned and validated for colour-vision
## deficiency on the pairs that actually touch each other in the stack:
## worst adjacent CVD dE 9.2, worst adjacent normal-vision dE 19.5 (OKLab
## x100, light surface).  'other' is deliberately desaturated so that it
## recedes; it is the only slot that sits below the chroma floor.
## ---------------------------------------------------------------------
colors <- c(
  "other"         = "#9C8AA5",
  "parallel"      = "#EDA100",
  "doParallel"    = "#008300",
  "doSNOW"        = "#2A78D6",
  "RcppParallel"  = "#EB6834",
  "mirai"         = "#1BAF7A",
  "parallelly"    = "#5B8DEF",
  "future"        = "#E34948",
  "doFuture"      = "#4A3AA7",
  "future.apply"  = "#E87BA4",
  "furrr"         = "#B85C00",
  "no dependency" = "#E7E5E0"
)
colors <- colors[levels]

surface <- "#FCFCFB"
image_dims <- c(10.0, 6.0)

## Band midpoints at the right edge, for direct labels.  The remainder band
## is left to the legend - it is near-white, so it cannot label itself in its
## own fill, and its name is too long for the label gutter.
label_at <- function(data, min_fraction) {
  data |>
    filter(date == max(date)) |>
    arrange(framework) |>
    mutate(y = cumsum(fraction) - fraction / 2) |>
    filter(fraction >= min_fraction, framework != "no dependency") |>
    mutate(colour = unname(colors[as.character(framework)]))
}

gg_base <- function(data, labels, kind) {
  gg <- ggplot(data, aes(x = date, y = fraction, fill = framework))
  ## The thin surface-coloured outline is the 2px spacer between fills
  gg <- gg + geom_area(position = position_stack(reverse = TRUE),
                       colour = surface, linewidth = 0.25)
  gg <- gg + scale_fill_manual(values = colors, breaks = rev(levels))
  gg <- gg + scale_x_date(
    breaks = seq(as.Date("2010-01-01"),
                 as.Date(format(Sys.Date(), "%Y-01-01")), by = "2 years"),
    date_labels = "%Y", expand = expansion(mult = c(0, 0.26))
  )
  gg <- gg + ggrepel::geom_text_repel(
    data = labels, aes(x = max(data$date), y = y, label = framework,
                       colour = colour),
    hjust = 0, size = 4.0, fontface = "bold", direction = "y",
    nudge_x = 120, min.segment.length = 0.4, segment.size = 0.3,
    segment.colour = "#A8A6A0", box.padding = 0.12, seed = 1L,
    show.legend = FALSE, inherit.aes = FALSE
  )
  gg <- gg + scale_colour_identity(guide = "none")
  gg <- gg + labs(x = NULL, y = "Fraction of all CRAN packages",
                  title = sprintf("Parallel frameworks on CRAN, by %s", kind_label[[kind]]),
                  caption = caption)
  gg <- gg + guides(fill = guide_legend(
    title = sprintf("%s dependency on:", tools::toTitleCase(kind_short[[kind]]))))
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

## Shared zoom ceiling, so the hard and soft figures are on one scale
zoom_ymax <- max(vapply(counts_by_kind, FUN = function(counts) {
  counts |>
    filter(framework != "no dependency") |>
    group_by(date) |>
    summarize(y = sum(fraction), .groups = "drop") |>
    pull(y) |>
    max()
}, FUN.VALUE = NA_real_))

make_charts <- function(kind) {
  counts <- counts_by_kind[[kind]]
  suffix <- if (kind == "hard") "" else paste0("-", kind)

  ## Full 0-100% stack.  The coloured stack is a sliver at this scale, so
  ## call out how tall it currently is.
  latest <- filter(counts, date == max(date), framework == "no dependency")
  latest_share <- 1 - latest$fraction
  gg <- gg_base(counts, label_at(counts, min_fraction = 0.05), kind)
  gg <- gg + annotate(
    "segment", x = max(counts$date), xend = max(counts$date) + 140,
    y = latest_share, yend = latest_share, colour = "#A8A6A0", linewidth = 0.3
  )
  gg <- gg + annotate(
    "text", x = max(counts$date) + 150, y = latest_share, hjust = 0, vjust = -0.3,
    label = sprintf("%.1f%% of CRAN", 100 * latest_share),
    size = 4.6, fontface = "bold", colour = "#0B0B0B"
  )
  ## No explicit limits: the bands sum to 1 only up to floating point, and a
  ## cumulative 1+1e-16 would put the top of the stack outside c(0, 1) and
  ## get it silently dropped.
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                breaks = seq(0, 1, by = 0.25))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_frameworks_over_time_on_CRAN%s.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)

  ## Zoomed in on the packages that do parallelize
  zoom <- filter(counts, framework != "no dependency")
  gg <- gg_base(zoom, label_at(zoom, min_fraction = 0.0025), kind)
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                limits = c(0, 1.02 * zoom_ymax))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_frameworks_over_time_on_CRAN%s-zoom.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)
}

for (kind in kind_order) make_charts(kind)


## ---------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------
for (kind in kind_order) {
  counts <- counts_by_kind[[kind]]
  message(sprintf("\nLatest breakdown by %s dependency edges:", kind))
  latest <- filter(counts, date == max(date), framework != "no dependency")
  print(arrange(select(latest, framework, edges, share, fraction), desc(edges)),
        n = Inf)
}
