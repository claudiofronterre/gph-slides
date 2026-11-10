-- QR code shortcode for GPH slides
--
--   {{< qr https://example.org >}}
--   {{< qr "https://example.org/?id=1" size="200px" >}}
--
-- The code is drawn at render time as inline SVG, so it needs no network,
-- no JavaScript and no extra software, and it appears in printed PDFs.
-- Quote addresses that contain "=", which Quarto would otherwise read as
-- an option.
--
-- The encoder follows ISO/IEC 18004 in byte mode at error correction level
-- M (about 15% of the code can be damaged), for versions 1 to 40. It is a
-- port of the steps in Project Nayuki's QR Code generator.

-- Error correction codewords per block and number of blocks at level M,
-- indexed by version.
local ECC_PER_BLOCK = {
  10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
  26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
}
local NUM_BLOCKS = {
  1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
  17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
}

-- Multiplication in GF(256) with the QR polynomial x^8 + x^4 + x^3 + x^2 + 1
local function gf_mul(x, y)
  local z = 0
  for i = 7, 0, -1 do
    z = (z << 1) ~ ((z >> 7) * 0x11D)
    z = z ~ (((y >> i) & 1) * x)
  end
  return z
end

local function rs_divisor(degree)
  local result = {}
  for i = 1, degree - 1 do result[i] = 0 end
  result[degree] = 1
  local root = 1
  for _ = 1, degree do
    for j = 1, degree do
      result[j] = gf_mul(result[j], root)
      if j < degree then result[j] = result[j] ~ result[j + 1] end
    end
    root = gf_mul(root, 2)
  end
  return result
end

local function rs_remainder(data, divisor)
  local n = #divisor
  local result = {}
  for i = 1, n do result[i] = 0 end
  for _, b in ipairs(data) do
    local factor = b ~ result[1]
    table.remove(result, 1)
    result[n] = 0
    for i = 1, n do
      result[i] = result[i] ~ gf_mul(divisor[i], factor)
    end
  end
  return result
end

-- Number of modules available for data and error correction
local function raw_modules(ver)
  local result = (16 * ver + 128) * ver + 64
  if ver >= 2 then
    local n = ver // 7 + 2
    result = result - ((25 * n - 10) * n - 55)
    if ver >= 7 then result = result - 36 end
  end
  return result
end

local function data_codewords(ver)
  return raw_modules(ver) // 8 - ECC_PER_BLOCK[ver] * NUM_BLOCKS[ver]
end

local function alignment_positions(ver)
  if ver == 1 then return {} end
  local n = ver // 7 + 2
  local step
  if ver == 32 then
    step = 26
  else
    local a, b = ver * 4 + 4, n * 2 - 2
    step = (a + b - 1) // b * 2
  end
  local result = { 6 }
  local pos = ver * 4 + 17 - 7
  while #result < n do
    table.insert(result, 2, pos)
    pos = pos - step
  end
  return result
end

local function choose_version(nbytes)
  for ver = 1, 40 do
    local count_bits = ver <= 9 and 8 or 16
    if 4 + count_bits + 8 * nbytes <= data_codewords(ver) * 8 then
      return ver
    end
  end
  return nil
end

-- Mode indicator, length, data, terminator and padding, as codewords
local function data_bits(bytes, ver)
  local bits = {}
  local function append(value, len)
    for i = len - 1, 0, -1 do bits[#bits + 1] = (value >> i) & 1 end
  end
  append(4, 4)
  append(#bytes, ver <= 9 and 8 or 16)
  for _, b in ipairs(bytes) do append(b, 8) end
  local capacity = data_codewords(ver) * 8
  append(0, math.min(4, capacity - #bits))
  append(0, (8 - #bits % 8) % 8)
  local pad = 0xEC
  while #bits < capacity do
    append(pad, 8)
    pad = pad ~ 0xEC ~ 0x11
  end
  local codewords = {}
  for i = 1, #bits, 8 do
    local v = 0
    for j = 0, 7 do v = (v << 1) | bits[i + j] end
    codewords[#codewords + 1] = v
  end
  return codewords
end

-- Split into blocks, add Reed-Solomon codewords and interleave
local function add_ecc(data, ver)
  local num_blocks = NUM_BLOCKS[ver]
  local ecc_len = ECC_PER_BLOCK[ver]
  local raw = raw_modules(ver) // 8
  local num_short = num_blocks - raw % num_blocks
  local short_len = raw // num_blocks
  local divisor = rs_divisor(ecc_len)
  local blocks = {}
  local k = 1
  for i = 0, num_blocks - 1 do
    local len = short_len - ecc_len + (i < num_short and 0 or 1)
    local dat = {}
    for j = 0, len - 1 do dat[#dat + 1] = data[k + j] end
    k = k + len
    local ecc = rs_remainder(dat, divisor)
    if i < num_short then dat[#dat + 1] = 0 end
    for _, e in ipairs(ecc) do dat[#dat + 1] = e end
    blocks[#blocks + 1] = dat
  end
  local result = {}
  for i = 1, #blocks[1] do
    for j, block in ipairs(blocks) do
      if i - 1 ~= short_len - ecc_len or j - 1 >= num_short then
        result[#result + 1] = block[i]
      end
    end
  end
  return result
end

-- Returns the module matrix (rows of booleans, 0-based) and its size.
-- `forced_mask` is only used by the tests.
local function encode(text, forced_mask)
  local bytes = { string.byte(text, 1, -1) }
  local ver = choose_version(#bytes)
  if not ver then return nil end
  local codewords = add_ecc(data_bits(bytes, ver), ver)
  local size = ver * 4 + 17

  local modules, is_func = {}, {}
  for y = 0, size - 1 do
    modules[y], is_func[y] = {}, {}
    for x = 0, size - 1 do
      modules[y][x], is_func[y][x] = false, false
    end
  end
  local function set_func(x, y, dark)
    modules[y][x] = dark
    is_func[y][x] = true
  end

  -- Timing patterns, finder patterns and alignment patterns
  for i = 0, size - 1 do
    set_func(6, i, i % 2 == 0)
    set_func(i, 6, i % 2 == 0)
  end
  local function finder(cx, cy)
    for dy = -4, 4 do
      for dx = -4, 4 do
        local d = math.max(math.abs(dx), math.abs(dy))
        local x, y = cx + dx, cy + dy
        if x >= 0 and x < size and y >= 0 and y < size then
          set_func(x, y, d ~= 2 and d ~= 4)
        end
      end
    end
  end
  finder(3, 3)
  finder(size - 4, 3)
  finder(3, size - 4)
  local align = alignment_positions(ver)
  local n = #align
  for i = 1, n do
    for j = 1, n do
      if not ((i == 1 and j == 1) or (i == 1 and j == n) or (i == n and j == 1)) then
        for dy = -2, 2 do
          for dx = -2, 2 do
            set_func(align[i] + dx, align[j] + dy,
                     math.max(math.abs(dx), math.abs(dy)) ~= 1)
          end
        end
      end
    end
  end

  -- Format information: level M (bits 00) and the mask, BCH coded
  local function draw_format(mask)
    local data = mask
    local rem = data
    for _ = 1, 10 do rem = (rem << 1) ~ ((rem >> 9) * 0x537) end
    local bits = ((data << 10) | rem) ~ 0x5412
    local function bit(i) return ((bits >> i) & 1) ~= 0 end
    for i = 0, 5 do set_func(8, i, bit(i)) end
    set_func(8, 7, bit(6))
    set_func(8, 8, bit(7))
    set_func(7, 8, bit(8))
    for i = 9, 14 do set_func(14 - i, 8, bit(i)) end
    for i = 0, 7 do set_func(size - 1 - i, 8, bit(i)) end
    for i = 8, 14 do set_func(8, size - 15 + i, bit(i)) end
    set_func(8, size - 8, true)
  end
  draw_format(0)

  -- Version information for versions 7 and above
  if ver >= 7 then
    local rem = ver
    for _ = 1, 12 do rem = (rem << 1) ~ ((rem >> 11) * 0x1F25) end
    local bits = (ver << 12) | rem
    for i = 0, 17 do
      local dark = ((bits >> i) & 1) ~= 0
      local a, b = size - 11 + i % 3, i // 3
      set_func(a, b, dark)
      set_func(b, a, dark)
    end
  end

  -- Codewords in the zigzag order, two columns at a time from the right
  local i, total = 0, #codewords * 8
  local right = size - 1
  while right >= 1 do
    if right == 6 then right = 5 end
    for vert = 0, size - 1 do
      for j = 0, 1 do
        local x = right - j
        local upward = ((right + 1) & 2) == 0
        local y = upward and (size - 1 - vert) or vert
        if not is_func[y][x] and i < total then
          local byte = codewords[(i >> 3) + 1]
          modules[y][x] = ((byte >> (7 - (i & 7))) & 1) ~= 0
          i = i + 1
        end
      end
    end
    right = right - 2
  end

  local function apply_mask(m)
    for y = 0, size - 1 do
      for x = 0, size - 1 do
        local invert
        if m == 0 then invert = (x + y) % 2 == 0
        elseif m == 1 then invert = y % 2 == 0
        elseif m == 2 then invert = x % 3 == 0
        elseif m == 3 then invert = (x + y) % 3 == 0
        elseif m == 4 then invert = (x // 3 + y // 2) % 2 == 0
        elseif m == 5 then invert = x * y % 2 + x * y % 3 == 0
        elseif m == 6 then invert = (x * y % 2 + x * y % 3) % 2 == 0
        else invert = ((x + y) % 2 + x * y % 3) % 2 == 0
        end
        if invert and not is_func[y][x] then
          modules[y][x] = not modules[y][x]
        end
      end
    end
  end

  -- Penalty score used to choose the mask
  local function penalty()
    local result = 0
    local function add_history(len, hist)
      if hist[1] == 0 then len = len + size end
      table.remove(hist)
      table.insert(hist, 1, len)
    end
    local function count_patterns(h)
      local m = h[2]
      local core = m > 0 and h[3] == m and h[4] == m * 3 and h[5] == m and h[6] == m
      return ((core and h[1] >= m * 4 and h[7] >= m) and 1 or 0)
        + ((core and h[7] >= m * 4 and h[1] >= m) and 1 or 0)
    end
    local function scan(get)
      for a = 0, size - 1 do
        local run_color, run = false, 0
        local hist = { 0, 0, 0, 0, 0, 0, 0 }
        for b = 0, size - 1 do
          local c = get(a, b)
          if c == run_color then
            run = run + 1
            if run == 5 then
              result = result + 3
            elseif run > 5 then
              result = result + 1
            end
          else
            add_history(run, hist)
            if not run_color then result = result + count_patterns(hist) * 40 end
            run_color, run = c, 1
          end
        end
        if run_color then
          add_history(run, hist)
          run = 0
        end
        add_history(run + size, hist)
        result = result + count_patterns(hist) * 40
      end
    end
    scan(function(a, b) return modules[a][b] end)
    scan(function(a, b) return modules[b][a] end)
    for y = 0, size - 2 do
      for x = 0, size - 2 do
        local c = modules[y][x]
        if c == modules[y][x + 1] and c == modules[y + 1][x] and c == modules[y + 1][x + 1] then
          result = result + 3
        end
      end
    end
    local dark = 0
    for y = 0, size - 1 do
      for x = 0, size - 1 do
        if modules[y][x] then dark = dark + 1 end
      end
    end
    local cells = size * size
    local diff = math.abs(dark * 20 - cells * 10)
    result = result + ((diff + cells - 1) // cells - 1) * 10
    return result
  end

  local mask = forced_mask
  if mask == nil then
    local best
    for m = 0, 7 do
      apply_mask(m)
      draw_format(m)
      local p = penalty()
      if best == nil or p < best then best, mask = p, m end
      apply_mask(m)
    end
  end
  apply_mask(mask)
  draw_format(mask)
  return modules, size, mask
end

local function escape_html(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

-- SVG with a quiet zone of four modules and one path for the dark modules
local function to_svg(modules, size, label)
  local border = 4
  local dim = size + 2 * border
  local parts = {}
  for y = 0, size - 1 do
    local x = 0
    while x < size do
      if modules[y][x] then
        local start = x
        while x < size and modules[y][x] do x = x + 1 end
        parts[#parts + 1] = string.format("M%d %dh%dv1h-%dz",
          start + border, y + border, x - start, x - start)
      else
        x = x + 1
      end
    end
  end
  return string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" role="img" '
      .. 'aria-label="QR code for %s" shape-rendering="crispEdges">'
      .. '<rect width="%d" height="%d" fill="#FAFAFA"/>'
      .. '<path fill="#1B1B1B" d="%s"/></svg>',
    dim, dim, escape_html(label), dim, dim, table.concat(parts))
end

if GPH_QR_TEST then
  return { encode = encode, to_svg = to_svg }
end

return {
  ["qr"] = function(args, kwargs, meta, raw_args, context)
    local text = args[1] and pandoc.utils.stringify(args[1]) or ""
    if text == "" then
      quarto.log.warning("The qr shortcode needs an address, as in {{< qr https://example.org >}}")
      return pandoc.Null()
    end
    if not quarto.doc.is_format("html") then
      return pandoc.Link(text, text)
    end
    local modules, size = encode(text)
    if not modules then
      quarto.log.warning("The text for the qr shortcode is too long: " .. text)
      return pandoc.Str(text)
    end
    local style = ""
    local width = kwargs["size"] and pandoc.utils.stringify(kwargs["size"]) or ""
    if width ~= "" then
      style = ' style="width: ' .. escape_html(width) .. '"'
    end
    local svg = to_svg(modules, size, text)
    if context == "block" then
      return pandoc.RawBlock("html", '<div class="gph-qr"' .. style .. ">" .. svg .. "</div>")
    end
    return pandoc.RawInline("html", '<span class="gph-qr"' .. style .. ">" .. svg .. "</span>")
  end,
}
