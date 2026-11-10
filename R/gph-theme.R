# ggplot2 theme and colour scales that match the GPH slides.
#
# Use it from a setup chunk:
#   source("R/gph-theme.R")
#   theme_set(theme_gph())
#
# Themes:      theme_gph(), theme_gph_map()
# Groups:      scale_colour_gph(), scale_fill_gph(),
#              scale_colour_gph_highlight(), scale_fill_gph_highlight()
# Continuous:  scale_colour_gph_c(), scale_fill_gph_c() with type and hue
# Classes:     scale_colour_gph_exceedance(), scale_fill_gph_exceedance()
# Colours:     gph_colours, gph_ramp(), gph_diverging_ramp(), gph_tint(),
#              gph_ink, gph_grey, gph_line, gph_paper, gph_gold
#
# Colours are the University of Birmingham secondary palette, which the
# brand reserves for data. The categorical order was checked for colour
# vision deficiency. The first four colours stay distinct for all common
# types. With five or more groups, label the lines or points directly, and
# beyond seven use facets instead of more colours.

library(ggplot2)

gph_colours <- c(
  turquoise = "#00ACA9",
  orange = "#F07F3C",
  purple = "#5E4F9C",
  red = "#E30513",
  blue = "#2581C4",
  green = "#3AAA35",
  pink = "#EA5284"
)

gph_ink <- "#1B1B1B"
gph_grey <- "#58595B"
gph_line <- "#D4D4D4"
gph_paper <- "#FAFAFA"
gph_gold <- "#C59A00"

# Light and deep swatches of each secondary colour
gph_swatches <- list(
  blue = c("#2581C4", "#0057BF"),
  turquoise = c("#00ACA9", "#00788E"),
  green = c("#3AAA35", "#007838"),
  purple = c("#5E4F9C", "#501D83"),
  red = c("#E30513", "#C20019"),
  pink = c("#EA5284", "#DB0661"),
  orange = c("#F07F3C", "#CF4527"),
  grey = c("#58595B", "#3C3C3B")
)

# A tint mixes a share p of the colour with white, as in the brand's 15%,
# 30%, 50% and 70% tints.
gph_tint <- function(colour, p) {
  rgb_value <- grDevices::col2rgb(colour)
  grDevices::rgb(t(round(p * rgb_value + (1 - p) * 255)), maxColorValue = 255)
}

# Sequential ramp for magnitudes such as prevalence, in one hue: the 15%,
# 30%, 50% and 70% tints, the light swatch and the deep swatch.
gph_ramp <- function(hue = "blue") {
  hue <- match.arg(hue, names(gph_swatches))
  swatch <- gph_swatches[[hue]]
  tints <- vapply(c(0.15, 0.3, 0.5, 0.7), function(p) gph_tint(swatch[1], p), character(1))
  c(tints, swatch)
}

# Diverging ramp for signed quantities such as residuals or differences:
# from the deep swatch of one hue to the deep swatch of another through a
# neutral grey. Low values are blue and high values orange by default.
gph_diverging_ramp <- function(low = "blue", high = "orange") {
  lo <- gph_swatches[[match.arg(low, names(gph_swatches))]]
  hi <- gph_swatches[[match.arg(high, names(gph_swatches))]]
  c(lo[2], lo[1], gph_tint(lo[1], 0.3), "#E8E8E8", gph_tint(hi[1], 0.3), hi[1], hi[2])
}

gph_sequential <- gph_ramp("blue")
gph_diverging <- gph_diverging_ramp()

# Register Manrope from the extension so that plots use the slide font.
# The search covers both _extensions/gph and _extensions/<owner>/gph.
gph_font <- local({
  family <- "sans"
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    # Without systemfonts the plots fall back to the default sans serif
  } else if ("Manrope" %in% systemfonts::system_fonts()$family) {
    family <- "Manrope"
  } else {
    files <- list.files("_extensions", pattern = "^Manrope-(Regular|Bold)\\.ttf$",
                        recursive = TRUE, full.names = TRUE)
    regular <- grep("Regular", files, value = TRUE)[1]
    bold <- grep("Bold", files, value = TRUE)[1]
    if (!is.na(regular) && !is.na(bold)) {
      systemfonts::register_font("Manrope", plain = regular, bold = bold)
      family <- "Manrope"
    }
  }
  family
})

# Fonts registered with systemfonts are seen by the ragg device, so use it
# for chunk output when it is installed. Transparent backgrounds let plots
# sit on the slide colour exactly.
if (requireNamespace("ragg", quietly = TRUE) && requireNamespace("knitr", quietly = TRUE)) {
  knitr::opts_chunk$set(dev = "ragg_png", dev.args = list(bg = "transparent"))
}

theme_gph <- function(base_size = 20, base_family = gph_font) {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      text = element_text(colour = gph_ink, family = base_family, size = base_size),
      plot.background = element_blank(),
      panel.background = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(colour = "#E4E4E4", linewidth = 0.4),
      panel.grid.minor = element_blank(),
      axis.line.x = element_line(colour = gph_grey, linewidth = 0.4),
      axis.ticks = element_blank(),
      axis.text = element_text(colour = gph_grey, size = rel(0.8)),
      axis.title = element_text(colour = gph_ink, size = rel(0.85)),
      axis.title.x = element_text(margin = margin(t = 10), size = rel(0.85)),
      axis.title.y = element_text(margin = margin(r = 10), angle = 90, size = rel(0.85)),
      legend.position = "top",
      legend.justification = "left",
      legend.title = element_text(size = rel(0.8), colour = gph_grey),
      legend.text = element_text(size = rel(0.8)),
      legend.key.size = unit(1.1, "lines"),
      strip.text = element_text(face = "bold", hjust = 0, size = rel(0.85),
                                margin = margin(b = 8)),
      plot.title = element_text(face = "bold", hjust = 0, size = rel(1),
                                margin = margin(b = 6)),
      plot.subtitle = element_text(colour = gph_grey, hjust = 0, size = rel(0.85),
                                   margin = margin(b = 12)),
      plot.caption = element_text(colour = gph_grey, hjust = 0, size = rel(0.7),
                                  margin = margin(t = 12)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.margin = margin(10, 14, 10, 10)
    )
}

# A variant for maps, without axes or grid lines. Use legend = "bottom" to
# put the colour bar under the map, for maps shown side by side.
theme_gph_map <- function(base_size = 20, base_family = gph_font,
                          legend = c("right", "bottom")) {
  legend <- match.arg(legend)
  bars <- if (legend == "right") {
    theme(legend.position = "right", legend.justification = "center",
          legend.key.height = unit(2.4, "lines"), legend.key.width = unit(0.9, "lines"))
  } else {
    theme(legend.position = "bottom", legend.justification = "center",
          legend.key.height = unit(0.8, "lines"), legend.key.width = unit(2.6, "lines"))
  }
  if (legend == "bottom" && utils::packageVersion("ggplot2") >= "3.5.0") {
    bars <- bars + theme(legend.title.position = "top")
  }
  theme_gph(base_size, base_family) %+replace%
    theme(
      axis.line.x = element_blank(),
      axis.text = element_blank(),
      axis.title = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_blank(),
      panel.grid.major.y = element_blank()
    ) +
    bars
}

gph_pal <- function(n) {
  if (n > length(gph_colours)) {
    stop("The GPH palette has ", length(gph_colours), " colours. ",
         "Use facets or group the smallest categories.", call. = FALSE)
  }
  unname(gph_colours[seq_len(n)])
}

scale_colour_gph <- function(...) {
  discrete_scale("colour", palette = gph_pal, ...)
}

scale_fill_gph <- function(...) {
  discrete_scale("fill", palette = gph_pal, ...)
}

# Continuous scales. `type = "sequential"` (the default) uses one hue, set
# with `hue`, so that maps of different quantities can be told apart at a
# glance, for example the predicted prevalence in blue and its standard
# deviation in purple. `type = "diverging"` takes two hues, low then high,
# and centres them on `midpoint`.
gph_gradient <- function(scale, type, hue, midpoint, ...) {
  if (type == "sequential") {
    if (is.null(hue)) hue <- "blue"
    return(scale(colours = gph_ramp(hue), ...))
  }
  if (is.null(hue)) hue <- c("blue", "orange")
  scale(colours = gph_diverging_ramp(hue[1], hue[2]),
        rescaler = function(x, ...) scales::rescale_mid(x, mid = midpoint), ...)
}

scale_fill_gph_c <- function(..., type = c("sequential", "diverging"), hue = NULL, midpoint = 0) {
  gph_gradient(scale_fill_gradientn, match.arg(type), hue, midpoint, ...)
}

scale_colour_gph_c <- function(..., type = c("sequential", "diverging"), hue = NULL, midpoint = 0) {
  gph_gradient(scale_colour_gradientn, match.arg(type), hue, midpoint, ...)
}

# Exceedance probabilities in classes, for maps of P(prevalence > threshold).
# With the default cut-offs the three classes read as unlikely (below 0.2),
# uncertain (0.2 to 0.8) and likely (above 0.8), in blue, grey and orange.
# Give other cut-offs for more classes. The legend shows the class limits.
gph_exceedance_colours <- function(n, hue = c("blue", "orange")) {
  lo <- gph_swatches[[hue[1]]]
  hi <- gph_swatches[[hue[2]]]
  if (n == 3) return(c(lo[1], "#D9D9D9", hi[1]))
  grDevices::colorRampPalette(c(lo[2], lo[1], "#D9D9D9", hi[1], hi[2]))(n)
}

gph_exceedance_scale <- function(aesthetics, name, cutoffs, hue, ...) {
  colours <- gph_exceedance_colours(length(cutoffs) + 1, hue)
  binned_scale(
    aesthetics,
    palette = function(x) colours[seq_along(x)],
    name = name,
    breaks = cutoffs,
    limits = c(0, 1),
    labels = scales::label_percent(),
    show.limits = TRUE,
    guide = guide_coloursteps(even.steps = TRUE),
    ...
  )
}

scale_fill_gph_exceedance <- function(name = "Probability", cutoffs = c(0.2, 0.8),
                                      hue = c("blue", "orange"), ...) {
  gph_exceedance_scale("fill", name, cutoffs, hue, ...)
}

scale_colour_gph_exceedance <- function(name = "Probability", cutoffs = c(0.2, 0.8),
                                        hue = c("blue", "orange"), ...) {
  gph_exceedance_scale("colour", name, cutoffs, hue, ...)
}

# Highlight a few groups in the categorical colours and draw the rest in
# light grey, for example scale_colour_gph_highlight("Forest"). Only the
# highlighted groups appear in the legend. Groups are drawn in the order of
# their factor levels, so put the highlighted ones last to draw them on top.
gph_highlight_scale <- function(scale, highlight, others, ...) {
  scale(values = stats::setNames(gph_pal(length(highlight)), highlight),
        limits = highlight, na.value = others, ...)
}

scale_colour_gph_highlight <- function(highlight, ..., others = "#C4C4C4") {
  gph_highlight_scale(scale_colour_manual, highlight, others, ...)
}

scale_fill_gph_highlight <- function(highlight, ..., others = "#C4C4C4") {
  gph_highlight_scale(scale_fill_manual, highlight, others, ...)
}
