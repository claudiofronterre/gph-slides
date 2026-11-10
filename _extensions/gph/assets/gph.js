// GPH slides: tidy printed pages.
//
// On screen, reveal.js shows the logo and footer as fixed elements. When the
// deck is printed to PDF (?print-pdf), Chrome would repeat them on every
// page, including the title, section, dark and photo pages. Instead, copy them onto
// each light content page and hide the fixed originals.
//
// Reveal also sizes stretched figures for the whole printed page, so a
// figure with a caption can run into the footer. Shrink any such figure
// until the slide content ends above the footer area.
(function () {
  var SAFE_BOTTOM = 660;

  function fitStretched(slide) {
    var img = slide.querySelector(":scope > img.r-stretch, :scope > .r-stretch");
    if (!img) return;
    var bottom = 0;
    Array.prototype.forEach.call(slide.children, function (child) {
      if (getComputedStyle(child).position === "absolute") return;
      bottom = Math.max(bottom, child.offsetTop + child.offsetHeight);
    });
    var excess = bottom - SAFE_BOTTOM;
    if (excess > 0) {
      img.style.height = Math.max(img.offsetHeight - excess, 120) + "px";
      img.style.width = "auto";
    }
  }

  function decorate() {
    var reveal = document.querySelector(".reveal");
    if (!reveal) return;
    var logo = reveal.querySelector(":scope > .slide-logo");
    var footer = reveal.querySelector(":scope > .footer");
    document.querySelectorAll(".reveal .pdf-page").forEach(function (page) {
      var slide = page.querySelector(":scope > section");
      if (!slide || slide.matches(".gph-title-slide, .gph-section")) return;
      fitStretched(slide);
      // The logo and footer are drawn for light pages, so dark slides
      // keep only their slide number.
      if (slide.matches(".dark, .photo")) return;
      if (logo && logo.getAttribute("src")) {
        var l = logo.cloneNode(true);
        l.className = "gph-pdf-logo";
        page.appendChild(l);
      }
      if (footer && !slide.matches(".closing")) {
        var f = footer.cloneNode(true);
        f.className = "gph-pdf-footer";
        page.appendChild(f);
      }
    });
    document.documentElement.classList.add("gph-pdf-ready");
  }

  function init() {
    if (typeof Reveal === "undefined" || !Reveal.isPrintView || !Reveal.isPrintView()) return;
    if (document.querySelector(".reveal .pdf-page")) {
      decorate();
    } else {
      Reveal.on("pdf-ready", decorate);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
