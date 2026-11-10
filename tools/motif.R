# Builds the contour motif used on the title and section slides.
#
# The motif is one realisation of a stationary Gaussian process with Matérn
# correlation (smoothness nu, scale phi), drawn with random Fourier features
# and shown as isolines, together with a handful of "sampling locations".
# The outputs are _extensions/gph/assets/motif.svg and motif-dark.svg, which
# the theme loads as background images on the title, section and closing
# slides.
#
# Run from the repository root:  Rscript tools/motif.R

set.seed(2026)

# Slide canvas in px and the domain used for the field (16 x 9 units)
width <- 1280
height <- 720
units_x <- 16
units_y <- 9

# Matérn field via random Fourier features. For the Matérn spectral measure,
# omega = z / (phi * sqrt(w)) with z ~ N(0, I) and w ~ chi-squared(2 nu).
nu <- 2.5
phi <- 1.1
n_features <- 3000
z <- matrix(rnorm(2 * n_features), ncol = 2)
w <- rchisq(n_features, df = 2 * nu)
omega <- z / (phi * sqrt(w))
b <- runif(n_features, 0, 2 * pi)

x <- seq(0, units_x, length.out = 321)
y <- seq(0, units_y, length.out = 181)
grid <- as.matrix(expand.grid(x = x, y = y))
field <- sqrt(2 / n_features) * cos(grid %*% t(omega) + rep(b, each = nrow(grid)))
field <- matrix(rowSums(field), nrow = length(x))

levels <- quantile(field, probs = seq(0.04, 0.96, length.out = 17))
lines <- contourLines(x, y, field, levels = levels)
accent_levels <- levels[c(13, 14)]

to_px <- function(u, v) {
  cbind(u / units_x * width, height - v / units_y * height)
}

path_d <- function(line) {
  p <- to_px(line$x, line$y)
  keep <- c(TRUE, rowSums(abs(diff(round(p)))) > 0)
  p <- round(p[keep, , drop = FALSE])
  if (nrow(p) < 4) return(NULL)
  paste0("M", p[1, 1], " ", p[1, 2], "L",
         paste(p[-1, 1], p[-1, 2], collapse = " "))
}

plain <- Filter(Negate(is.null), lapply(
  Filter(function(l) !(l$level %in% accent_levels), lines), path_d))
accent_paths <- Filter(Negate(is.null), lapply(
  Filter(function(l) l$level %in% accent_levels, lines), path_d))

# Sampling locations: a sparse, slightly inhibited point pattern
pts <- matrix(numeric(0), ncol = 2)
while (nrow(pts) < 26) {
  cand <- c(runif(1, 0.4, units_x - 0.4), runif(1, 0.4, units_y - 0.4))
  if (nrow(pts) == 0 || min(sqrt(colSums((t(pts) - cand)^2))) > 1.4) {
    pts <- rbind(pts, cand)
  }
}
pts_px <- round(to_px(pts[, 1], pts[, 2]), 1)

write_motif <- function(file, line, accent, point) {
  svg <- c(
    sprintf('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" preserveAspectRatio="xMidYMid slice">',
            width, height),
    sprintf('<path fill="none" stroke="%s" stroke-width="1.1" stroke-linejoin="round" d="%s"/>',
            line, paste(plain, collapse = " ")),
    sprintf('<path fill="none" stroke="%s" stroke-width="1.6" stroke-linejoin="round" d="%s"/>',
            accent, paste(accent_paths, collapse = " ")),
    sprintf('<g fill="%s">%s</g>', point,
            paste(sprintf('<circle cx="%s" cy="%s" r="3.2"/>', pts_px[, 1], pts_px[, 2]),
                  collapse = "")),
    "</svg>"
  )
  writeLines(svg, file, sep = "")
  cat(basename(file), file.size(file), "bytes\n")
}

# Light version for the usual slides and dark version for {.dark} slides
write_motif("_extensions/gph/assets/motif.svg",
            line = "#C9C9C9", accent = "#C59A00", point = "#1B1B1B")
write_motif("_extensions/gph/assets/motif-dark.svg",
            line = "#575757", accent = "#C59A00", point = "#FAFAFA")
