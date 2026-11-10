# Maintaining GPH slides

The extension lives in `_extensions/gph/`. `template.qmd` is both the example deck and the file that `quarto use template` copies into new talks, so every feature should appear there with a comment explaining its syntax.

Brand rules from the University of Birmingham guidelines apply. Black and white dominate, gold is only for rules and block graphics, and secondary colours are for data, never for running text.

Never refer to `_extensions/gph/` by path from a document. Quarto installs the extension under `_extensions/<owner>/gph/` when it comes from GitHub. Fonts and the motif load through the HTML dependency in `gph.lua`, and anything a document references directly (logos, R helpers) lives at the repository root.

Check every change in presentation mode and in a printed PDF (`template.html?print-pdf` in Chrome). Reveal's print styles remove slide padding and height and measure slides before wrapping them in pages, which is why the print rules at the end of `gph.scss` target the slides themselves. Chrome drops the text of list items with a bottom border from printed PDFs, so separators in lists are drawn as background lines. Headless Chrome sometimes prints before reveal or MathJax have finished, giving a one-page PDF or broken equations, so check the page count and retry.

Keep the content of every example slide above 660px, the top of the footer area. When a slide runs past the page, Chrome can drop the text of lists from the printed PDF altogether. The slide-height check in the browser console (each non-stack section's lowest child) is the quickest test after changing sizes.

Pandoc writes `[text]{.mark}` as a `<mark>` element and drops the class, so rules for marks must match `mark` as well as `.mark`. The background of `.dark` slides is set in `gph.lua` and has to match `$gph-dark-bg` in `gph.scss`. `tools/motif.R` writes both the light and the dark motif from the same field.

Printed pages are larger than the slides (1331 by 748 pixels for 1280 by 720) because reveal adds its margin around each slide, so anything on a slide stops short of the page edges. Effects that must reach the edges, such as the gradient of photo slides, go on the slide's background layer: reveal copies the slide's classes to `.slide-background`, which fills the window on screen and the page in print. Never let a slide overflow in print, since reveal then prints it on two pages.

`qr.lua` is a QR encoder written for the extension. It was checked module by module against the `qrcode` LaTeX package for versions 1 to 15 at the same mask. The mask chosen by the penalty rules can differ from LaTeX's, and both are valid. `tools/examples.R` makes the mock papers and the map used by the example deck, so the repository holds no third-party images.

Do not set `display` on slide sections. Reveal hides slides through their inline display style, and a forced display keeps hidden slides visible.
