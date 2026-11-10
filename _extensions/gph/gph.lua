-- GPH slides: fonts, section numbers, outlines, section labels, dark and
-- photo slides, people, papers and uncounted backup slides.

local section_numbers = true
local section_label = false

-- Background of {.dark} and {.photo} slides, the brand black. Keep in step
-- with $gph-dark-bg in gph.scss.
local dark_background = "#1B1B1B"

-- Fonts and the contour motif travel as an HTML dependency, so they are
-- found wherever Quarto installs the extension (_extensions/gph or
-- _extensions/<owner>/gph).
local function add_assets()
  quarto.doc.add_html_dependency({
    name = "gph-assets",
    version = "0.1.0",
    stylesheets = { "assets/gph-assets.css" },
    scripts = { "assets/gph.js" },
    resources = {
      "assets/motif.svg",
      "assets/motif-dark.svg",
      "fonts/Manrope-Regular.ttf",
      "fonts/Manrope-Bold.ttf",
      "fonts/Spectral-Regular.ttf",
      "fonts/Spectral-Italic.ttf",
      "fonts/Spectral-SemiBold.ttf",
    },
  })
end

local function option(meta, key)
  local value = meta[key]
  if value == nil then return nil end
  return pandoc.utils.stringify(value)
end

local function read_options(meta)
  if option(meta, "section-numbers") == "false" then
    section_numbers = false
  end
  if option(meta, "section-label") == "true" then
    section_label = true
  end
end

-- The first paragraph under a section heading, shown on the section slide
-- and in outlines.
local function section_text(blocks, i)
  for j = i + 1, #blocks do
    local b = blocks[j]
    if b.t == "Header" then return nil end
    if b.t == "Para" or b.t == "Plain" then return b.content end
  end
  return nil
end

local function outline_div(sections, current)
  local items = pandoc.List()
  for _, s in ipairs(sections) do
    local classes = { "gph-outline-item" }
    if current then
      table.insert(classes, s == current and "current" or "muted")
    end
    local inlines = pandoc.List()
    if s.number then
      inlines:insert(pandoc.Span(pandoc.Str(s.number), pandoc.Attr("", { "gph-outline-number" })))
    end
    inlines:insert(pandoc.Span(s.title:clone(), pandoc.Attr("", { "gph-outline-title" })))
    if s.text then
      inlines:insert(pandoc.Span(s.text:clone(), pandoc.Attr("", { "gph-outline-text" })))
    end
    items:insert(pandoc.Div(pandoc.Plain(inlines), pandoc.Attr("", classes)))
  end
  return pandoc.Div(items, pandoc.Attr("", { "gph-outline" }))
end

-- Slides whose layout has no room for the section label
local function takes_label(classes)
  for _, c in ipairs({ "statement", "closing", "photo", "outline", "no-title" }) do
    if classes:includes(c) then return false end
  end
  return true
end

-- Level-1 headings become section slides. Number them (01, 02, ...) unless
-- the heading is {.unnumbered}. A section marked {.appendix} or {.backup}
-- starts the backup slides: those and every later slide are left out of
-- the slide count, so the last counted slide is the real end of the talk.
-- Slides marked {.dark} or {.photo} get the brand black as background
-- colour, unless they set their own. With `section-label: true`, every
-- content slide carries the name of its section for a running head.
-- Slides marked {.outline} receive the list of sections. An outline that
-- comes after the first section highlights the section that follows it.
local function process_blocks(blocks)
  local number = 0
  local in_backup = false
  local label = nil
  local sections = {}
  local outlines = {}
  for i, block in ipairs(blocks) do
    if block.t == "Header" and block.level <= 2 then
      local classes = block.classes
      if block.level == 1 then
        if classes:includes("appendix") or classes:includes("backup") then
          in_backup = true
        end
        classes:insert("gph-section")
        local num = nil
        if section_numbers and not in_backup
          and not classes:includes("unnumbered") then
          number = number + 1
          num = string.format("%02d", number)
          block.attributes["data-gph-number"] = num
        end
        if not in_backup then
          table.insert(sections, {
            index = i,
            number = num,
            title = block.content,
            text = section_text(blocks, i),
          })
        end
        label = (num and (num .. "  ") or "") .. pandoc.utils.stringify(block.content)
      else
        if section_label and label and takes_label(classes) then
          block.attributes["data-gph-label"] = label
        end
        if classes:includes("outline") then
          table.insert(outlines, { index = i, after_section = #sections > 0 })
        end
      end
      if in_backup then
        block.attributes["visibility"] = "uncounted"
      end
      if (classes:includes("dark") or classes:includes("photo"))
        and block.attributes["background-color"] == nil then
        block.attributes["background-color"] = dark_background
      end
    end
  end

  if #outlines == 0 then return blocks end
  local insert_after = {}
  for _, o in ipairs(outlines) do
    local current = nil
    if o.after_section then
      for _, s in ipairs(sections) do
        if s.index > o.index then current = s; break end
      end
    end
    insert_after[o.index] = outline_div(sections, current)
  end
  local result = pandoc.Blocks({})
  for i, block in ipairs(blocks) do
    result:insert(block)
    if insert_after[i] then result:insert(insert_after[i]) end
  end
  return result
end

-- Pandoc turns a div that starts with a heading into a <section>, and
-- reveal.js would then treat each card as a slide. An empty raw block in
-- front of the heading keeps every card an ordinary div.
local function protect_cards(div)
  for _, child in ipairs(div.content) do
    if child.t == "Div" and #child.content > 0 and child.content[1].t == "Header" then
      child.content:insert(1, pandoc.RawBlock("html", "<!-- card -->"))
    end
  end
  return div
end

-- People: each list item is "![](photo.jpg) **Name** Role". Items without
-- a photo get the initials of the name instead.
local function initials(name)
  local words = {}
  for w in pandoc.utils.stringify(name):gmatch("%S+") do table.insert(words, w) end
  if #words == 0 then return "" end
  local first = pandoc.text.upper(pandoc.text.sub(words[1], 1, 1))
  if #words == 1 then return first end
  return first .. pandoc.text.upper(pandoc.text.sub(words[#words], 1, 1))
end

local function person(item)
  local inlines = pandoc.List()
  for _, b in ipairs(item) do
    if b.t == "Plain" or b.t == "Para" then
      if #inlines > 0 then inlines:insert(pandoc.Space()) end
      inlines:extend(b.content)
    end
  end
  local photo, name = nil, nil
  local rest = pandoc.List()
  for _, el in ipairs(inlines) do
    if el.t == "Image" and photo == nil and name == nil then
      photo = el
    elseif el.t == "Strong" and name == nil then
      name = el.content
    elseif photo ~= nil or name ~= nil then
      rest:insert(el)
    end
  end
  while #rest > 0 and (rest[1].t == "Space" or rest[1].t == "SoftBreak" or rest[1].t == "LineBreak") do
    rest:remove(1)
  end
  name = name or pandoc.Inlines({})
  local picture
  if photo then
    picture = pandoc.Span({ photo }, pandoc.Attr("", { "gph-person-photo" }))
  else
    picture = pandoc.Span(pandoc.Str(initials(name)),
      pandoc.Attr("", { "gph-person-photo", "gph-person-initials" }, { ["aria-hidden"] = "true" }))
  end
  return { pandoc.Plain({
    picture,
    pandoc.Span(name, pandoc.Attr("", { "gph-person-name" })),
    pandoc.Span(rest, pandoc.Attr("", { "gph-person-role" })),
  }) }
end

local function people(div)
  return div:walk({
    BulletList = function(list)
      for k, item in ipairs(list.content) do
        list.content[k] = person(item)
      end
      return list
    end,
  })
end

-- Papers: images of first pages, cropped to the top half (or .third, or
-- .full). A PDF is converted to a PNG of its first page the first time,
-- saved next to it as <name>-page1.png and reused after that.
local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

local function run(cmd, args)
  return pcall(pandoc.pipe, cmd, args, "")
end

local converted = {}

local function first_page_png(pdf)
  if converted[pdf] ~= nil then return converted[pdf] or nil end
  local png = pdf:gsub("%.[Pp][Dd][Ff]$", "-page1.png")
  local stem = png:gsub("%.png$", "")
  local r_code = string.format(
    "if (!requireNamespace('pdftools', quietly = TRUE)) quit(status = 1); "
      .. "pdftools::pdf_convert(%q, pages = 1, dpi = 150, filenames = %q, verbose = FALSE)",
    pdf, png)
  if file_exists(png)
    or (run("pdftoppm", { "-png", "-r", "150", "-f", "1", "-l", "1", "-singlefile", pdf, stem })
      and file_exists(png))
    or (run("Rscript", { "--vanilla", "-e", r_code }) and file_exists(png)) then
    converted[pdf] = png
    return png
  end
  quarto.log.warning("Could not convert " .. pdf .. " to an image. Install poppler "
    .. "(for pdftoppm) or the pdftools R package, or save the first page as "
    .. png .. " yourself.")
  converted[pdf] = false
  return nil
end

local function paper(image, caption)
  if image.src:match("%.[Pp][Dd][Ff]$") then
    local png = first_page_png(image.src)
    if png then image.src = png end
  end
  local content = { pandoc.Div(pandoc.Plain({ image }), pandoc.Attr("", { "gph-paper-page" })) }
  if caption and #caption > 0 then
    table.insert(content, pandoc.Div(pandoc.Plain(caption), pandoc.Attr("", { "gph-paper-caption" })))
  end
  return pandoc.Div(content, pandoc.Attr("", { "gph-paper" }))
end

local function papers(div)
  local result = pandoc.Blocks({})
  for _, block in ipairs(div.content) do
    if block.t == "Figure" then
      local image = nil
      block:walk({ Image = function(img) image = image or img end })
      if image then
        result:insert(paper(image, pandoc.utils.blocks_to_inlines(block.caption.long)))
      end
    elseif block.t == "Para" or block.t == "Plain" then
      for _, el in ipairs(block.content) do
        if el.t == "Image" then result:insert(paper(el, el.caption)) end
      end
    else
      result:insert(block)
    end
  end
  div.content = result
  return div
end

return {
  {
    Meta = function(meta)
      if quarto.doc.is_format("revealjs") then
        add_assets()
        read_options(meta)
      end
    end,
  },
  {
    Div = function(div)
      if not quarto.doc.is_format("revealjs") then return nil end
      if div.classes:includes("cards") then return protect_cards(div) end
      if div.classes:includes("people") then return people(div) end
      if div.classes:includes("papers") then return papers(div) end
    end,
  },
  {
    Pandoc = function(doc)
      if quarto.doc.is_format("revealjs") then
        doc.blocks = process_blocks(doc.blocks)
      end
      return doc
    end,
  },
}
