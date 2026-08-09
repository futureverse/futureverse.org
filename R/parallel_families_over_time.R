## Evolution of CRAN packages that depend on a parallel framework, with the
## framework packages grouped into the ecosystem they belong to.
##
## This is the per-package graph (R/parallel_frameworks_over_time.R) one level
## up.  Grouping is not just cosmetic: within a family a dependent package is
## counted *once*, so a package that imports future, future.apply and furrr
## contributes one unit of Futureverse rather than three.  Family shares are
## therefore shares of packages, not of dependency edges.
##
## A package that reaches into several families still counts once per family
## - those really are separate choices - so the bands are rescaled to make the
## stack sum to the exact fraction of CRAN with at least one dependency.
##
## Drawn for hard dependencies (Depends, Imports, LinkingTo) and for soft ones
## (Suggests), on a shared zoomed y-axis so the pair can be read side by side.

source("R/cran_snapshots.R")
source("R/parallel_families.R")   ## family map, families, colors, surface, image_dims


levels <- c(families, "no dependency")

data <- filter(data, framework %in% names(family))
data <- mutate(data, family = unname(family[framework]))

message("Family membership:")
membership <- tibble(pkg = names(family), fam = unname(family))
print(membership |>
        group_by(fam) |>
        summarize(packages = paste(pkg, collapse = ", "), .groups = "drop"),
      n = Inf, width = Inf)


## ---------------------------------------------------------------------
## One stacked series per dependency kind
## ---------------------------------------------------------------------
build_counts <- function(kind) {
  this <- filter(data, kind == !!kind)

  totals <- this |>
    group_by(date) |>
    summarize(any = n_distinct(package), .groups = "drop") |>
    right_join(totals_all, by = "date") |>
    mutate(any = coalesce(any, 0L))

  ## Distinct dependent packages per family - the within-family de-duplication
  members <- this |>
    distinct(date, family, package) |>
    count(date, family, name = "packages") |>
    tidyr::complete(date = totals_all$date, family = families,
                    fill = list(packages = 0L))

  ## sum(packages) is scalar, so ifelse() would collapse the whole group to
  ## one value; keep the denominator as a column and divide row-wise
  counts <- members |>
    group_by(date) |>
    mutate(denom = sum(packages)) |>
    ungroup() |>
    mutate(share = if_else(denom > 0, packages / denom, 0)) |>
    left_join(totals, by = "date") |>
    mutate(fraction = share * any / total)

  none <- totals |>
    transmute(date, family = "no dependency", packages = NA_integer_,
              share = NA_real_, total, any, fraction = 1 - any / total)

  counts <- bind_rows(counts, none)
  counts <- mutate(counts, kind = !!kind,
                   family = factor(family, levels = levels))
  arrange(counts, date, family)
}

counts_by_kind <- lapply(kind_order, FUN = build_counts)
names(counts_by_kind) <- kind_order

write_tsv(bind_rows(counts_by_kind),
          file = file.path(path, "parallel_families_over_time.tsv"))


caption <- paste0(
  "Within a family a dependent package is counted once, so importing future, ",
  "future.apply and furrr is one unit of Futureverse, not three. A package ",
  "reaching into several families counts once in each. Multi-threading ",
  "(RcppParallel, RcppThread) is excluded - these are the multi-process ",
  "ecosystems. 'foreach' and 'doRNG' are left out too: it is the do*() ",
  "backends that parallelize, not they."
)
caption <- paste(strwrap(caption, width = 132), collapse = "\n")

label_at <- function(data, min_fraction) {
  data |>
    filter(date == max(date)) |>
    arrange(family) |>
    mutate(y = cumsum(fraction) - fraction / 2) |>
    filter(fraction >= min_fraction, family != "no dependency") |>
    mutate(label = sprintf("%s  %.1f%%", family, 100 * fraction))
}

## Recomputed from the data - the membership/package gap moves as families
## are added or excluded, so it must not be hardcoded
rel_stats <- local({
  latest <- filter(counts_by_kind[["hard"]], date == max(date))
  list(memberships = sum(latest$packages, na.rm = TRUE),
       packages = filter(latest, family == "no dependency")$any)
})
caption_rel <- paste0(
  "Multi-threading (RcppParallel, RcppThread) is excluded: these are the ",
  "multi-process ecosystems. Denominator is family memberships, not packages: ",
  "a package in two families is counted in both, so the bands can fill 100%. ",
  sprintf("Today that is %d memberships across %d distinct packages, ",
          rel_stats$memberships, rel_stats$packages),
  sprintf("because %d belong to more than one family.",
          rel_stats$memberships - rel_stats$packages)
)
caption_rel <- paste(strwrap(caption_rel, width = 132), collapse = "\n")

gg_base <- function(data, labels, kind, relative = FALSE) {
  gg <- ggplot(data, aes(x = date, y = fraction, fill = family))
  gg <- gg + geom_area(position = position_stack(reverse = TRUE),
                       colour = surface, linewidth = 0.25)
  gg <- gg + scale_fill_manual(values = colors, breaks = rev(levels))
  gg <- gg + scale_x_date(
    breaks = seq(as.Date("2010-01-01"),
                 as.Date(format(Sys.Date(), "%Y-01-01")), by = "2 years"),
    date_labels = "%Y", expand = expansion(mult = c(0, 0.34))
  )
  gg <- gg + ggrepel::geom_text_repel(
    data = labels, aes(x = max(data$date), y = y, label = label, colour = family),
    hjust = 0, size = 3.9, fontface = "bold", direction = "y",
    nudge_x = 120, min.segment.length = 0.4, segment.size = 0.3,
    segment.colour = "#A8A6A0", box.padding = 0.12, seed = 1L,
    show.legend = FALSE, inherit.aes = FALSE
  )
  gg <- gg + scale_colour_manual(values = colors, guide = "none")
  gg <- gg + labs(
    x = NULL,
    y = if (relative) "Share of multi-process ecosystem use"
        else "Fraction of all CRAN packages",
    title = if (relative)
      sprintf("Which multi-process ecosystem do CRAN packages reach for? (%s)",
              kind_short[[kind]])
    else
      sprintf("Multi-process ecosystems on CRAN, by %s", kind_label[[kind]]),
    caption = if (relative) caption_rel else caption
  )
  gg <- gg + guides(fill = guide_legend(title = "Ecosystem:"))
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
    filter(family != "no dependency") |>
    group_by(date) |>
    summarize(y = sum(fraction), .groups = "drop") |>
    pull(y) |>
    max()
}, FUN.VALUE = NA_real_))

make_charts <- function(kind) {
  counts <- counts_by_kind[[kind]]
  suffix <- if (kind == "hard") "" else paste0("-", kind)

  latest_share <- with(filter(counts, date == max(date),
                              family == "no dependency"), 1 - fraction)
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
  ## cumulative 1+1e-16 would put the top of the stack outside c(0, 1) and get
  ## it silently dropped.
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                breaks = seq(0, 1, by = 0.25))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_families_over_time_on_CRAN%s.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)

  zoom <- filter(counts, family != "no dependency")
  gg <- gg_base(zoom, label_at(zoom, min_fraction = 0.001), kind)
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                limits = c(0, 1.02 * zoom_ymax))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_families_over_time_on_CRAN%s-zoom.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)

  ## Relative: each family as a share of all parallel-using packages, so the
  ## stack fills 100% and the bands are ecosystem market share rather than
  ## penetration of CRAN
  rel <- zoom |> mutate(fraction = share)
  gg <- gg_base(rel, label_at(rel, min_fraction = 0.02), kind, relative = TRUE)
  gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                                breaks = seq(0, 1, by = 0.25))
  pathname <- ggsave(
    gg, filename = sprintf("parallel_families_over_time_on_CRAN%s-relative.png", suffix),
    width = image_dims[1], height = image_dims[2], dpi = 300, bg = surface)
  message("Wrote: ", pathname)
}

for (kind in kind_order) make_charts(kind)


## ---------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------
for (kind in kind_order) {
  message(sprintf("\n%s dependencies, packages per ecosystem, every second year:", kind))
  wide <- counts_by_kind[[kind]] |>
    filter(family != "no dependency",
           format(date, "%m-%d") == "01-01" | date == max(date)) |>
    select(date, family, packages) |>
    tidyr::pivot_wider(names_from = family, values_from = packages)
  print(as.data.frame(wide), row.names = FALSE)
}
