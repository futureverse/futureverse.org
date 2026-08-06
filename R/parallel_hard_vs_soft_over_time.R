## Hard versus soft adoption of parallel frameworks on CRAN, over time.
##
## The question this answers: when a package author reaches for a parallel
## framework, do they make it mandatory (Depends/Imports/LinkingTo, so every
## user installs it) or optional (Suggests, so parallelism is offered but not
## forced)?  A rising soft share is the signature of "I want to support
## parallelization, but conservatively - I am not forcing it on anyone".
##
## Two figures:
##   1. a stacked area of CRAN split into hard / soft-only / neither
##   2. the soft share, soft-only / (hard + soft-only), per framework
##
## The three bands in figure 1 are mutually exclusive: a package that both
## hard-depends on one framework and suggests another counts as hard, since
## it does force a framework on its users.

source("R/cran_snapshots.R")

exclude <- c("foreach", "doRNG", "nanonext", "RhpcBLASctl", "OpenMPController")
data <- filter(data, !framework %in% exclude)

surface <- "#FCFCFB"
image_dims <- c(10.0, 6.0)

theme_base <- function() {
  theme_minimal(base_size = 15) +
    theme(
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
}

x_scale <- function(expand_right) {
  scale_x_date(
    breaks = seq(as.Date("2010-01-01"),
                 as.Date(format(Sys.Date(), "%Y-01-01")), by = "2 years"),
    date_labels = "%Y", expand = expansion(mult = c(0, expand_right))
  )
}


## ---------------------------------------------------------------------
## 1. CRAN split into hard / soft-only / neither
## ---------------------------------------------------------------------
classes <- data |>
  group_by(date, package) |>
  summarize(hard = any(kind == "hard"), .groups = "drop") |>
  mutate(class = ifelse(hard, "mandatory (hard)", "optional (soft only)"))

levels <- c("mandatory (hard)", "optional (soft only)", "no parallel dependency")

counts <- classes |>
  count(date, class, name = "packages") |>
  tidyr::complete(date = totals_all$date, class = levels[1:2],
                  fill = list(packages = 0L)) |>
  left_join(totals_all, by = "date") |>
  mutate(fraction = packages / total)

none <- counts |>
  group_by(date) |>
  summarize(total = first(total), any = sum(packages), .groups = "drop") |>
  transmute(date, class = "no parallel dependency", packages = total - any,
            total, fraction = 1 - any / total)

counts <- bind_rows(counts, none)
counts <- mutate(counts, class = factor(class, levels = levels))
counts <- arrange(counts, date, class)

write_tsv(counts, file = file.path(path, "parallel_hard_vs_soft_over_time.tsv"))

## Blue for mandatory, orange for optional - validated all-pairs for
## colour-vision deficiency on the light surface (CVD dE 15.4, normal 25.1)
colors <- c("mandatory (hard)"       = "#2A78D6",
            "optional (soft only)"   = "#EB6834",
            "no parallel dependency" = "#E7E5E0")

caption1 <- paste0(
  "A package counts as mandatory if it has any hard dependency (Depends, ",
  "Imports, LinkingTo) on a parallel framework, even if it also suggests ",
  "others - it does force a framework on its users either way. Optional ",
  "means Suggests and nothing harder."
)
caption1 <- paste(strwrap(caption1, width = 132), collapse = "\n")

make_split <- function(zoom) {
  this <- if (zoom) filter(counts, class != "no parallel dependency") else counts
  labels <- this |>
    filter(date == max(date), class != "no parallel dependency") |>
    arrange(class) |>
    mutate(y = cumsum(fraction) - fraction / 2,
           label = sprintf("%s\n%.1f%%", class, 100 * fraction))

  gg <- ggplot(this, aes(x = date, y = fraction, fill = class))
  gg <- gg + geom_area(position = position_stack(reverse = TRUE),
                       colour = surface, linewidth = 0.25)
  gg <- gg + scale_fill_manual(values = colors, breaks = rev(levels))
  gg <- gg + x_scale(0.34)
  gg <- gg + ggrepel::geom_text_repel(
    data = labels, aes(x = max(this$date), y = y, label = label, colour = class),
    hjust = 0, size = 4.0, fontface = "bold", direction = "y",
    nudge_x = 120, min.segment.length = 0.4, segment.size = 0.3,
    segment.colour = "#A8A6A0", box.padding = 0.14, seed = 1L,
    show.legend = FALSE, inherit.aes = FALSE
  )
  gg <- gg + scale_colour_manual(values = colors, guide = "none")
  gg <- gg + labs(
    x = NULL, y = "Fraction of all CRAN packages",
    title = "Do CRAN packages force a parallel framework on their users, or only offer one?",
    caption = caption1
  )
  gg <- gg + guides(fill = guide_legend(title = "Parallel support is:"))
  gg <- gg + theme_base()
  if (zoom) {
    ymax <- max(summarize(group_by(this, date), y = sum(fraction))$y)
    gg <- gg + scale_y_continuous(labels = scales::percent,
                                  expand = expansion(0), limits = c(0, 1.02 * ymax))
  } else {
    gg <- gg + scale_y_continuous(labels = scales::percent,
                                  expand = expansion(0), breaks = seq(0, 1, by = 0.25))
  }
  gg
}

pathname <- ggsave(make_split(FALSE),
                   filename = "parallel_hard_vs_soft_over_time_on_CRAN.png",
                   width = image_dims[1], height = image_dims[2], dpi = 300,
                   bg = surface)
message("Wrote: ", pathname)
pathname <- ggsave(make_split(TRUE),
                   filename = "parallel_hard_vs_soft_over_time_on_CRAN-zoom.png",
                   width = image_dims[1], height = image_dims[2], dpi = 300,
                   bg = surface)
message("Wrote: ", pathname)


## ---------------------------------------------------------------------
## 2. The soft share per framework
##
## Of the packages that depend on framework F at all, what fraction do so
## only softly?  This is per framework, so a package can contribute to
## several - here that is a feature, since the question is about how each
## framework is adopted, not about how many packages there are.
## ---------------------------------------------------------------------
named <- c("parallel", "doParallel", "RcppParallel", "mirai",
           "parallelly", "future", "future.apply", "furrr")

share <- data |>
  filter(framework %in% named) |>
  group_by(date, framework, package) |>
  summarize(hard = any(kind == "hard"), .groups = "drop") |>
  group_by(date, framework) |>
  summarize(n = n(), soft_only = sum(!hard), .groups = "drop") |>
  mutate(soft_share = soft_only / n)

## Only draw a framework once it has a footing; a share computed from a
## handful of packages is noise, not a trend
share <- filter(share, n >= 20)
share <- mutate(share, framework = factor(framework, levels = named))

write_tsv(share, file = file.path(path, "parallel_soft_share_over_time.tsv"))

## Eight hues, fixed per framework, matching the per-framework figure where
## they overlap
share_colors <- c(
  "parallel"     = "#EDA100",
  "doParallel"   = "#008300",
  "RcppParallel" = "#EB6834",
  "mirai"        = "#1BAF7A",
  "parallelly"   = "#5B8DEF",
  "future"       = "#E34948",
  "future.apply" = "#E87BA4",
  "furrr"        = "#B85C00"
)

## Small multiples rather than eight lines in one panel: the colours are
## locked to the frameworks by the other figures, so they cannot be re-stepped
## to separate eight crossing lines under colour-vision deficiency.  One line
## per panel sidesteps that, and eight overlapping lines would be unreadable
## regardless.  Each panel carries the all-framework share as a grey
## reference, so the panels can be read against each other and not just
## against the axis.
reference <- data |>
  group_by(date, package) |>
  summarize(hard = any(kind == "hard"), .groups = "drop") |>
  group_by(date) |>
  summarize(soft_share = sum(!hard) / n(), .groups = "drop")

labels <- share |>
  group_by(framework) |>
  filter(date == max(date)) |>
  ungroup() |>
  mutate(label = sprintf("%.0f%%", 100 * soft_share))

caption2 <- paste0(
  "Of the packages depending on a framework at all, the share that only ",
  "suggest it. High means the framework is typically offered as an option; ",
  "low means it is typically made mandatory. Grey is the same share across ",
  "all frameworks together. A framework enters its panel once 20 packages ",
  "depend on it."
)
caption2 <- paste(strwrap(caption2, width = 132), collapse = "\n")

gg <- ggplot(share, aes(x = date, y = soft_share))
gg <- gg + geom_line(data = select(reference, -NULL), aes(x = date, y = soft_share),
                     colour = "#C9C7C1", linewidth = 0.9, inherit.aes = FALSE)
gg <- gg + geom_line(aes(colour = framework), linewidth = 1.2)
gg <- gg + geom_text(data = labels, aes(label = label, colour = framework),
                     hjust = 1, vjust = -0.6, size = 4.4, fontface = "bold",
                     show.legend = FALSE)
gg <- gg + scale_colour_manual(values = share_colors, guide = "none")
gg <- gg + facet_wrap(~ framework, nrow = 2)
gg <- gg + scale_x_date(
  breaks = seq(as.Date("2012-01-01"),
               as.Date(format(Sys.Date(), "%Y-01-01")), by = "6 years"),
  date_labels = "%Y", expand = expansion(mult = 0.04)
)
gg <- gg + scale_y_continuous(labels = scales::percent, limits = c(0, NA),
                              expand = expansion(mult = c(0, 0.12)))
gg <- gg + labs(
  x = NULL, y = "Share of dependents that only suggest it",
  title = "How often is each parallel framework offered rather than required?",
  caption = caption2
)
gg <- gg + theme_base()
gg <- gg + theme(
  strip.text = element_text(size = 14, colour = "#0B0B0B", face = "bold",
                            margin = margin(b = 4)),
  panel.spacing = unit(14, "pt")
)
pathname <- ggsave(gg, filename = "parallel_soft_share_over_time_on_CRAN.png",
                   width = image_dims[1], height = image_dims[2], dpi = 300,
                   bg = surface)
message("Wrote: ", pathname)


## ---------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------
message("\nMandatory vs optional, every second year:")
wide <- counts |>
  filter(format(date, "%m-%d") == "01-01" | date == max(date)) |>
  select(date, class, packages, total) |>
  tidyr::pivot_wider(names_from = class, values_from = packages) |>
  mutate(soft_share = `optional (soft only)` /
           (`mandatory (hard)` + `optional (soft only)`))
print(as.data.frame(wide), row.names = FALSE, digits = 3)

message("\nSoft share per framework, latest:")
latest <- share |>
  filter(date == max(date)) |>
  arrange(desc(soft_share)) |>
  select(framework, dependents = n, soft_only, soft_share)
print(as.data.frame(latest), row.names = FALSE, digits = 3)
