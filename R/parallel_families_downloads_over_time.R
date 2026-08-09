## CRAN download statistics per parallel ecosystem, over time - the download
## counterpart to R/parallel_families_over_time.R.
##
## Reuses the weekly all-CRAN download cache built by R/cran_stats.R, so it
## needs no new downloading.  Each weekly figure is the *median daily* download
## count for that package that week, which is what that cache stores.
##
## THREE THINGS TO KNOW BEFORE READING THESE FIGURES
##
##  1. Base R's 'parallel' is missing, and it is the largest family in the
##     dependency graphs.  It ships with R, is not on CRAN, and therefore has
##     no download record at all.  The ecosystem shares here are shares of the
##     families that *can* be measured, and are not comparable to the
##     dependency shares.
##
##  2. A download is an install, not a choice.  A package pulled in as someone
##     else's dependency counts the same as one somebody chose.  Nothing can be
##     done about that here.  What *is* corrected is the double counting it
##     causes within a family - see "Undo the dependency double counting"
##     below - so a family is no longer credited once per member for the same
##     install.
##
##  3. cranlogs covers the Posit/RStudio CDN only, and its counts include CI
##     runners and mirroring.  Treat the level as indicative and the *trend*
##     as the signal.

source("R/cran_snapshots.R")
source("R/parallel_families.R")   ## family map, families, colors, surface, image_dims

cran_path <- file.path("cranlogs", "per-week")
stopifnot(utils::file_test("-d", cran_path))


## ---------------------------------------------------------------------
## Weekly downloads for the framework packages, plus the all-CRAN total
## ---------------------------------------------------------------------
downloads <- local({
  pathname <- file.path(path, "family-downloads-per-week.tsv.gz")
  if (utils::file_test("-f", pathname)) {
    return(read_tsv(pathname, col_types = cols(week_of = col_date(),
                                               package = col_character(),
                                               count = col_double(),
                                               cran_total = col_double())))
  }

  pathnames <- sort(list.files(cran_path, pattern = "per-week[.]tsv[.]gz$",
                               full.names = TRUE))
  message("Reading ", length(pathnames), " weekly download files")
  pkgs <- names(family)
  col_types <- cols(week_of = col_date(), package = col_character(),
                    count = col_integer())

  p <- progressor(along = pathnames)
  weeks <- future_lapply(pathnames, FUN = function(pathname) {
    p()
    week <- read_tsv(pathname, col_types = col_types)
    ## The all-CRAN total has to be taken before filtering
    total <- sum(as.numeric(week$count), na.rm = TRUE)
    week <- filter(week, package %in% pkgs)
    mutate(week, cran_total = total)
  })
  data <- bind_rows(weeks)

  write_tsv(data, file = pathname)
  data
})

message("Weeks covered: ", format(min(downloads$week_of)), " .. ",
        format(max(downloads$week_of)))

## Drop base R's 'parallel' explicitly, so the omission is deliberate rather
## than incidental (it never appears in cranlogs anyway)
downloads <- filter(downloads, package != "parallel")

## The cache holds every framework package ever collected, which is a superset
## of the current family map - drop whatever the map no longer classifies
## (today: the excluded multi-threading packages), or it would still count
## towards the share denominator while being invisible in the stack
downloads <- mutate(downloads, family = unname(family[package]))
dropped <- sort(unique(downloads$package[is.na(downloads$family)]))
if (length(dropped) > 0) message("Not in a family, dropped: ",
                                 paste(dropped, collapse = ", "))
downloads <- filter(downloads, !is.na(family))

totals <- downloads |>
  distinct(week_of, cran_total)

## ---------------------------------------------------------------------
## Undo the dependency double counting
##
## Summing an ecosystem's packages inflates it: installing furrr fetches
## future, which fetches parallelly, and cranlogs counts all three.  The
## inflation scales with how deep a family's internal dependency chain is,
## which is why Futureverse (a chain nine deep) is flattered and foreach
## backends (five unrelated siblings) is not.
##
## So: build the dependency graph *among each family's own members*, split the
## family into connected components, and take the largest member of each
## component rather than the sum.  Within a component every install fetches
## the shared root, so the largest member is the best single estimate of
## distinct install events; across components nothing forces overlap, so those
## are summed.  The raw sum is kept as an explicit upper bound.
## ---------------------------------------------------------------------
components <- local({
  db <- available.packages(repos = "https://cloud.r-project.org")
  members <- split(names(family), unname(family))
  out <- lapply(names(members), FUN = function(fam) {
    m <- members[[fam]]
    deps <- tools::package_dependencies(m, which = kinds$hard, db = db)
    ## union-find over edges that stay inside the family
    parent <- setNames(m, m)
    root <- function(x) { while (parent[[x]] != x) x <- parent[[x]]; x }
    for (p in m) for (q in intersect(deps[[p]], m)) {
      rp <- root(p); rq <- root(q)
      if (rp != rq) parent[[rp]] <- rq
    }
    tibble(package = m, family = fam,
           component = vapply(m, FUN = root, FUN.VALUE = NA_character_))
  })
  bind_rows(out)
})
message("Dependency components within each family:")
print(components |> count(family, component, name = "members"), n = Inf)

counts <- downloads |>
  left_join(select(components, package, component), by = "package") |>
  mutate(component = coalesce(component, package)) |>
  group_by(week_of, family, component) |>
  summarize(peak = max(count), total = sum(count), .groups = "drop_last") |>
  group_by(week_of, family) |>
  summarize(downloads = sum(peak), downloads_sum = sum(total), .groups = "drop") |>
  tidyr::complete(week_of, family, fill = list(downloads = 0, downloads_sum = 0)) |>
  arrange(family, week_of) |>
  group_by(family) |>
  mutate(across(c(downloads, downloads_sum),
                ~ zoo::rollmean(.x, k = 4, fill = NA, align = "center"))) |>
  ungroup() |>
  filter(!is.na(downloads)) |>
  left_join(totals, by = "week_of") |>
  group_by(week_of) |>
  mutate(share = downloads / sum(downloads)) |>
  ungroup() |>
  mutate(fraction = downloads / cran_total)

plot_families <- intersect(families, unique(counts$family))
counts <- mutate(counts, family = factor(family, levels = plot_families))
counts <- arrange(counts, week_of, family)

write_tsv(counts, file = file.path(path, "parallel_families_downloads_over_time.tsv"))


## ---------------------------------------------------------------------
## Plot
## ---------------------------------------------------------------------
caption_abs <- paste0(
  "Median daily downloads from the Posit CDN, taken as the ",
  "largest package per internal dependency component (not summed, which would ",
  "count future once for furrr, once for future.apply and once for itself), ",
  "and smoothed over 4 weeks. Multi-threading is excluded. Base R's ",
  "'parallel' is absent too: it ",
  "ships with R, so it has no CRAN download record."
)
caption_abs <- paste(strwrap(caption_abs, width = 132), collapse = "\n")

caption_rel <- paste0(
  "Downloads de-duplicated along each ecosystem's internal dependency graph, ",
  "so a family is not credited once per member for the same install. ",
  "Multi-threading is excluded, and base R's ",
  "'parallel' ships with R and has no CRAN download record, so it cannot ",
  "appear. A download is an install, including installs made on behalf of ",
  "some other package's dependencies, not a deliberate choice."
)
caption_rel <- paste(strwrap(caption_rel, width = 132), collapse = "\n")

label_at <- function(data, y, min_value, fmt) {
  data |>
    filter(week_of == max(week_of)) |>
    arrange(family) |>
    mutate(ypos = cumsum(.data[[y]]) - .data[[y]] / 2) |>
    filter(.data[[y]] >= min_value) |>
    mutate(label = fmt(family, .data[[y]]))
}

gg_base <- function(data, y, labels) {
  gg <- ggplot(data, aes(x = week_of, y = .data[[y]], fill = family))
  gg <- gg + geom_area(position = position_stack(reverse = TRUE),
                       colour = surface, linewidth = 0.15)
  gg <- gg + scale_fill_manual(values = colors, breaks = rev(plot_families))
  gg <- gg + scale_x_date(
    breaks = seq(as.Date("2016-01-01"),
                 as.Date(format(Sys.Date(), "%Y-01-01")), by = "2 years"),
    date_labels = "%Y", expand = expansion(mult = c(0, 0.34))
  )
  gg <- gg + ggrepel::geom_text_repel(
    data = labels, aes(x = max(data$week_of), y = ypos, label = label,
                       colour = family),
    hjust = 0, size = 3.9, fontface = "bold", direction = "y",
    nudge_x = 90, min.segment.length = 0.4, segment.size = 0.3,
    segment.colour = "#A8A6A0", box.padding = 0.12, seed = 1L,
    show.legend = FALSE, inherit.aes = FALSE
  )
  gg <- gg + scale_colour_manual(values = colors, guide = "none")
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

## Absolute downloads
gg <- gg_base(counts, "downloads",
              label_at(counts, "downloads", min_value = 3000,
                       fmt = function(f, v) sprintf("%s  %s", f,
                              scales::label_comma(accuracy = 1)(v))))
gg <- gg + scale_y_continuous(labels = scales::label_number(scale = 1e-3, suffix = "k"),
                              expand = expansion(0))
gg <- gg + labs(x = NULL, y = "Median daily downloads",
                title = "Downloads of the multi-process parallel ecosystems on CRAN",
                caption = caption_abs)
pathname <- ggsave(gg, filename = "parallel_families_downloads_over_time_on_CRAN.png",
                   width = image_dims[1], height = image_dims[2], dpi = 300,
                   bg = surface)
message("Wrote: ", pathname)

## Share of downloads across the measurable ecosystems
gg <- gg_base(counts, "share",
              label_at(counts, "share", min_value = 0.02,
                       fmt = function(f, v) sprintf("%s  %.1f%%", f, 100 * v)))
gg <- gg + scale_y_continuous(labels = scales::percent, expand = expansion(0),
                              breaks = seq(0, 1, by = 0.25))
gg <- gg + labs(x = NULL, y = "Share of ecosystem downloads",
                title = "Which multi-process parallel ecosystem is being downloaded?",
                caption = caption_rel)
pathname <- ggsave(gg, filename = "parallel_families_downloads_over_time_on_CRAN-relative.png",
                   width = image_dims[1], height = image_dims[2], dpi = 300,
                   bg = surface)
message("Wrote: ", pathname)


## ---------------------------------------------------------------------
## Summary
## ---------------------------------------------------------------------
message("\nMedian daily downloads per ecosystem, every second year:")
wide <- counts |>
  filter(format(week_of, "%m") == "01" & as.integer(format(week_of, "%d")) <= 7 |
           week_of == max(week_of)) |>
  distinct(year = format(week_of, "%Y"), family, .keep_all = TRUE) |>
  select(week_of, family, downloads) |>
  mutate(downloads = round(downloads)) |>
  tidyr::pivot_wider(names_from = family, values_from = downloads)
print(as.data.frame(wide), row.names = FALSE)
