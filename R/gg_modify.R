#' @import ggplot2
#' @export
gg_modify <- function(gg, mode = getOption("ggmode", "website"), legend = c("upper-left", "lower-right", "none"), image_dims = attr(gg, "image_dims")) {
  mode <- match.arg(mode, choices = c("presentation", "website"))
  legend <- match.arg(legend)
  
  if (is.null(image_dims)) {
    image_dims <- c(7.5, 6.0)
    #image_dims <- 0.7*image_dims
  }

  ## Defaults
  gg <- gg + geom_line(linewidth = 1.2)
  gg <- gg + labs(x = "", y = "Number of reverse dependencies")

  gg <- gg + geom_line(linewidth = 2.0)
  gg <- gg + theme(
    axis.text       = element_text(size = 20, colour = "black"),
    axis.title      = element_text(size = 20, colour = "black",
                                   face = "bold"),
    legend.text     = element_text(size = 16, colour = "black"),
    legend.title    = element_text(size = 16, colour = "black"),
  )

  gg <- gg + guides(col = guide_legend(title = "Package:"))
  if (legend == "lower-right") {
    gg <- gg + theme(legend.position.inside = c(0.84, 0.15))
  } else if (legend == "upper-left") {
    gg <- gg + theme(legend.position.inside = c(0.15, 0.85))
  } else if (legend == "none") {
    gg <- gg + theme(legend.position.inside = "none")
  }

  if (mode == "presentation") {
    gg <- gg + geom_line(linewidth = 2.0)
    gg <- gg + theme(
      axis.text       = element_text(size = 20, colour = "black"),
      axis.title      = element_text(size = 20, colour = "black",
                                     face = "bold"),
      legend.text     = element_text(size = 16, colour = "black"),
      legend.title    = element_text(size = 16, colour = "black"),
    )
    if (legend == "lower-right") {
      gg <- gg + theme(legend.position.inside = c(0.84, 0.15))
    } else {
      gg <- gg + theme(legend.position.inside = c(0.14, 0.85))
    }
    image_dims <- 1.2 * image_dims
  }

  attr(gg, "image_dims") <- image_dims

  gg
}
