# Builds the example images used by template.qmd:
#
#   assets/examples/map.png                a full-bleed map of simulated
#                                          prevalence, for the photo layout
#   assets/examples/paper-{1,2,3}.pdf      mock first pages of papers
#   assets/examples/paper-{1,2,3}-page1.png  their first pages as images, which
#                                          the papers layout would otherwise
#                                          create on the first render
#
# Everything here is made up, so the repository carries no third-party
# photos or papers. Needs ggplot2, ragg, pdflatex, pdfseparate and pdftoppm.
#
# Run from the repository root:  Rscript tools/examples.R

dir.create("assets/examples", showWarnings = FALSE, recursive = TRUE)

# Full-bleed map -----------------------------------------------------------------

source("R/gph-theme.R")
set.seed(51)

# A Matérn field from random Fourier features, as in tools/motif.R
matern_field <- function(x, y, phi, nu, n_features = 2500) {
  z <- matrix(rnorm(2 * n_features), ncol = 2)
  w <- rchisq(n_features, df = 2 * nu)
  omega <- z / (phi * sqrt(w))
  b <- runif(n_features, 0, 2 * pi)
  grid <- as.matrix(expand.grid(x = x, y = y))
  f <- sqrt(2 / n_features) * cos(grid %*% t(omega) + rep(b, each = nrow(grid)))
  rowSums(f)
}

x <- seq(0, 16, length.out = 400)
y <- seq(0, 9, length.out = 225)
grid <- expand.grid(x = x, y = y)
grid$prevalence <- plogis(-1.2 + 1.7 * matern_field(x, y, phi = 1.4, nu = 2.5))
sites <- data.frame(x = runif(160, 0.3, 15.7), y = runif(160, 0.3, 8.7))

map <- ggplot(grid, aes(x, y)) +
  geom_raster(aes(fill = prevalence), interpolate = TRUE) +
  geom_point(data = sites, shape = 21, size = 2.2, stroke = 0.5,
             fill = gph_paper, colour = gph_ink) +
  scale_fill_gph_c(guide = "none") +
  coord_equal(expand = FALSE) +
  theme_void()
ggsave("assets/examples/map.png", map, width = 16, height = 9, dpi = 100,
       device = ragg::agg_png)

# Mock papers -----------------------------------------------------------------

papers <- list(
  list(
    journal = "Journal of Example Statistics", colour = "0.10,0.20,0.45",
    volume = "Volume 12, 2026, pages 101--124",
    title = "Model-based geostatistics for mapping disease prevalence from incomplete surveys",
    abstract = paste(
      "National surveys rarely reach every community, yet control programmes need",
      "estimates for all of them. We describe a geostatistical model for prevalence",
      "data that borrows strength from nearby survey locations and from environmental",
      "covariates, and we show how its predictive distribution supports maps of the",
      "predicted prevalence, of its uncertainty and of the probability that a threshold",
      "is exceeded. In a simulation study the model reduced the mean squared error of",
      "predictions by a third compared with a non-spatial alternative. We discuss how",
      "to report these results so that they can be used by programme managers."
    ),
    keywords = "Gaussian process; prevalence mapping; spatial prediction; uncertainty"
  ),
  list(
    journal = "Example Spatial Health", colour = "0.45,0.10,0.15",
    volume = "Vol. 8, Article 34, 2025",
    title = "Choosing where to sample next: adaptive designs for prevalence surveys",
    abstract = paste(
      "Surveys are expensive, and the value of a new survey location depends on what",
      "is already known. We propose an adaptive design that selects the next batch of",
      "locations to reduce the predictive variance where decisions are most uncertain.",
      "Using data from repeated surveys we compare the adaptive design with random and",
      "regular designs of the same size. The adaptive design reached the target",
      "precision with fewer locations in every scenario we considered, and the gains",
      "were largest when prevalence was close to the intervention threshold."
    ),
    keywords = "adaptive sampling; geostatistical design; disease surveillance"
  ),
  list(
    journal = "Example Reports in Public Health", colour = "0.00,0.35,0.35",
    volume = "2024; 19(3): 211--229",
    title = "Exceedance probabilities as a basis for decisions in disease control",
    abstract = paste(
      "Maps of predicted prevalence are often read as if they were certain. We argue",
      "that decisions about where to intervene should instead rest on the probability",
      "that prevalence exceeds a policy threshold, and we show how to compute and",
      "communicate this probability from a fitted geostatistical model. Workshops with",
      "programme staff suggested that three classes of exceedance probability were",
      "easier to act on than a continuous scale. We provide software and a template",
      "for reporting."
    ),
    keywords = "decision making; exceedance probability; risk communication"
  )
)

body <- paste(
  "\\section{Introduction}",
  "Disease control programmes plan their work district by district, but the data",
  "that inform those plans come from a limited number of survey locations. Between",
  "the locations we must predict, and every prediction carries uncertainty that",
  "should travel with it into the decision.",
  "",
  "Geostatistical models treat the unobserved prevalence surface as a realisation",
  "of a stochastic process. The correlation between two locations decays with the",
  "distance between them at a rate set by the scale parameter of the correlation",
  "function. Locations close to a survey are predicted with more confidence than",
  "locations far from any survey, which is the behaviour a programme needs to see.",
  "",
  "In this paper we describe the model, explain how it is fitted and checked, and",
  "show how its output can be summarised for decision makers. Section 2 introduces",
  "the data and Section 3 the model. Section 4 reports a simulation study, and",
  "Section 5 discusses limitations and extensions.",
  "",
  "\\section{Data}",
  "The surveys recorded the number of people tested and the number who tested",
  "positive in each community, together with the geographical coordinates of the",
  "community and a set of environmental covariates derived from satellite images.",
  sep = "\n"
)

page <- function(p) {
  sprintf(paste(
    "\\begin{titlepage}\\thispagestyle{empty}\\setcounter{section}{0}",
    "\\definecolor{journal}{rgb}{%s}",
    "{\\color{journal}\\rule{\\textwidth}{3pt}}\\par\\vspace{4pt}",
    "{\\sffamily\\small\\color{journal}\\textbf{%s}\\hfill %s}\\par\\vspace{30pt}",
    "{\\LARGE\\bfseries %s\\par}\\vspace{16pt}",
    "{\\large First Author\\textsuperscript{1}, Second Author\\textsuperscript{2} and Third Author\\textsuperscript{1}}\\par\\vspace{6pt}",
    "{\\small\\textsuperscript{1}Department of Example Studies, Example University\\quad \\textsuperscript{2}Institute of Placeholder Research}\\par\\vspace{22pt}",
    "\\noindent\\colorbox{journal!6}{\\parbox{\\dimexpr\\textwidth-2\\fboxsep}{\\small\\textbf{Abstract.} %s\\par\\vspace{6pt}\\textbf{Keywords:} %s}}\\par\\vspace{20pt}",
    "\\begin{multicols}{2}\\small %s\\end{multicols}",
    "\\vfill{\\footnotesize\\color{gray} A mock first page made for the GPH slide template. The journal, authors and results are invented.}",
    "\\end{titlepage}",
    sep = "\n"),
    p$colour, p$journal, p$volume, p$title, p$abstract, p$keywords, body)
}

tex <- c(
  "\\documentclass[11pt]{article}",
  "\\usepackage[a4paper,margin=2cm]{geometry}",
  "\\usepackage{mathptmx}",
  "\\usepackage[T1]{fontenc}",
  "\\usepackage{xcolor,multicol}",
  "\\setlength{\\parindent}{1em}",
  "\\begin{document}",
  vapply(papers, page, character(1)),
  "\\end{document}"
)

build <- tempfile("papers")
dir.create(build)
writeLines(tex, file.path(build, "papers.tex"))
old <- setwd(build)
system2("pdflatex", c("-interaction=nonstopmode", "papers.tex"), stdout = FALSE)
setwd(old)
pdf <- file.path(build, "papers.pdf")
stopifnot(file.exists(pdf))

for (k in seq_along(papers)) {
  out <- sprintf("assets/examples/paper-%d.pdf", k)
  system2("pdfseparate", c("-f", k, "-l", k, pdf, out))
  system2("pdftoppm", c("-png", "-r", "150", "-singlefile", out,
                        sub("\\.pdf$", "-page1", out)))
}

cat("Wrote", list.files("assets/examples", full.names = TRUE), sep = "\n  ")
