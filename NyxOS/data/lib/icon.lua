-- /lib/icon.lua : NyxOS icon renderer
--
-- Apps ship a small pixel image and NyxOS draws it (the same idea as
-- MineOS' OCIF icons). A pixel icon is a table:
--
--   {
--     palette = { r = "red", w = "white", k = "#202020", ... },
--     pixels  = { "....rrrr....", ... },   -- one string per pixel row
--   }
--
-- Every character of a row is one pixel; "." and " " are transparent.
-- Colours are CC colour names or "#rrggbb" (mapped to the nearest of the
-- 16 screen colours). Size: up to 16 x 9 pixels, which fills an 8 x 3
-- character cell (each cell is 2 x 3 pixels, drawn with the teletext
-- characters 128-159). Smaller images are centred.
--
-- Where an app can provide it:
--   * app.json  ->  "icon": { "palette": {...}, "pixels": [...] }   (kept in the manifest)
--   * a Lua file /etc/icons/<package>.lua returning the same table
--   * nyxapi.registerIcon(name, icon)
-- Old-style icons ({color = "red", art = {...}}) still work.

local icon = {}
local palette = colors or colours

icon.WIDTH, icon.HEIGHT = 16, 9
icon.CELLS_W, icon.CELLS_H = 8, 3

-- Default CC palette (r, g, b)
local RGB = {
    white = { 240, 240, 240 }, orange = { 242, 178, 51 }, magenta = { 229, 127, 216 },
    lightBlue = { 153, 178, 242 }, yellow = { 222, 222, 108 }, lime = { 127, 204, 25 },
    pink = { 242, 178, 204 }, gray = { 76, 76, 76 }, lightGray = { 153, 153, 153 },
    cyan = { 76, 153, 178 }, purple = { 178, 102, 229 }, blue = { 51, 102, 204 },
    brown = { 127, 102, 76 }, green = { 87, 166, 78 }, red = { 204, 76, 76 },
    black = { 17, 17, 17 },
}
local NAMES = {}
for name in pairs(RGB) do NAMES[#NAMES + 1] = name end
table.sort(NAMES)

local function dist(a, b)
    local dr, dg, db = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return dr * dr + dg * dg + db * db
end

local cache = {}
-- name or "#rrggbb" -> CC colour name (nearest) or nil
local function resolve(spec)
    if type(spec) ~= "string" then return nil end
    if cache[spec] ~= nil then return cache[spec] or nil end
    local out
    if RGB[spec] then
        out = spec
    elseif spec == "grey" then out = "gray"
    elseif spec == "lightGrey" then out = "lightGray"
    else
        local r, g, b = spec:match("^#?(%x%x)(%x%x)(%x%x)$")
        if r then
            local rgb = { tonumber(r, 16), tonumber(g, 16), tonumber(b, 16) }
            local best, bd = nil, math.huge
            for _, n in ipairs(NAMES) do
                local d = dist(rgb, RGB[n])
                if d < bd then best, bd = n, d end
            end
            out = best
        end
    end
    cache[spec] = out or false
    return out
end
icon.resolve = resolve

local function blitChar(name)
    return colors.toBlit(palette[name])
end

-- True when `def` is a pixel icon
function icon.isPixel(def)
    return type(def) == "table" and type(def.pixels) == "table" and type(def.palette) == "table"
end

-- Parses a pixel icon into a 16x9 grid of colour names (nil = transparent)
local function grid(def)
    local g = {}
    for y = 1, icon.HEIGHT do g[y] = {} end
    local rows = def.pixels
    local height = math.min(#rows, icon.HEIGHT)
    local width = 0
    for y = 1, height do width = math.max(width, math.min(#tostring(rows[y]), icon.WIDTH)) end
    local ox = math.floor((icon.WIDTH - width) / 2)
    local oy = math.floor((icon.HEIGHT - height) / 2)
    for y = 1, height do
        local row = tostring(rows[y])
        for x = 1, math.min(#row, icon.WIDTH) do
            local ch = row:sub(x, x)
            if ch ~= "." and ch ~= " " then
                g[y + oy][x + ox] = resolve(def.palette[ch])
            end
        end
    end
    return g
end

-- Renders a pixel icon as 3 blit rows over background colour `bgName`.
-- Returns { {text, fg, bg}, ... } (Basalt "bimg" frame format).
function icon.render(def, bgName)
    local transparent = (bgName == "transparent")
    if transparent then bgName = "black" end
    bgName = resolve(bgName) or "black"
    local g = grid(def)
    local rows = {}
    for cy = 1, icon.CELLS_H do
        local text, fgs, bgs = {}, {}, {}
        for cx = 1, icon.CELLS_W do
            -- the six pixels of this cell, top-left first
            local px = {}
            local solid = false
            for i = 0, 5 do
                local x = (cx - 1) * 2 + (i % 2) + 1
                local y = (cy - 1) * 3 + math.floor(i / 2) + 1
                if g[y][x] then solid = true end
                px[i + 1] = g[y][x] or bgName
            end
            -- two most representative colours: the most frequent one and
            -- the colour furthest from it
            local count, first = {}, nil
            for i = 1, 6 do
                count[px[i]] = (count[px[i]] or 0) + 1
            end
            local c1, n1 = nil, 0
            for i = 1, 6 do
                if count[px[i]] > n1 then c1, n1 = px[i], count[px[i]] end
            end
            local c2, d2 = nil, -1
            for i = 1, 6 do
                local d = dist(RGB[px[i]], RGB[c1])
                if d > d2 then c2, d2 = px[i], d end
            end
            if d2 <= 0 then c2 = c1 end
            local bits, ch = 0, 128
            for i = 1, 5 do
                if dist(RGB[px[i]], RGB[c2]) < dist(RGB[px[i]], RGB[c1]) then
                    bits = bits + 2 ^ (i - 1)
                end
            end
            local fg, bg = c2, c1
            -- the 6th pixel is the inverse of the character's bit 5: it
            -- always belongs to the background colour
            if dist(RGB[px[6]], RGB[c2]) < dist(RGB[px[6]], RGB[c1]) then
                -- swap roles: pixel 6 must be "background"
                fg, bg = c1, c2
                bits = 31 - bits
            end
            text[cx] = string.char(128 + bits)
            fgs[cx] = blitChar(fg)
            bgs[cx] = blitChar(bg)
            if transparent and not solid then bgs[cx] = "t" end
        end
        rows[cy] = { table.concat(text), table.concat(fgs), table.concat(bgs) }
    end
    return rows
end

-- Old-style icon ({ color, art }) -> pixel-free blit rows (rounded body)
function icon.renderLegacy(def, bgName)
    bgName = resolve(bgName) or "black"
    local body = resolve(def and def.color) or "green"
    local art = def and def.art or {}
    local bb, bgc, fgk = blitChar(body), blitChar(bgName), blitChar("black")
    local function pad(s)
        s = tostring(s or "")
        if #s > 6 then s = s:sub(1, 6) end
        local l = math.floor((6 - #s) / 2)
        return string.rep(" ", l) .. s .. string.rep(" ", 6 - #s - l)
    end
    local rows = {}
    for r = 1, 3 do
        rows[r] = { pad(art[r]), string.rep(fgk, 6), string.rep(bb, 6) }
    end
    -- rounded corners: 8 columns = 1 corner + 6 body + 1 corner
    local left = { "\159", "\128", "\130" }
    local right = { "\144", "\128", "\129" }
    for r = 1, 3 do
        local row = rows[r]
        local lc, rc = left[r], right[r]
        if r == 1 then
            row[1] = "\159" .. row[1] .. "\144"
            row[2] = bgc .. row[2] .. bgc
            row[3] = bb .. row[3] .. bb
            row[2] = bb .. row[2]:sub(2, 7) .. bb
            row[3] = bgc .. row[3]:sub(2, 7) .. bgc
        elseif r == 2 then
            row[1] = " " .. row[1] .. " "
            row[2] = fgk .. row[2] .. fgk
            row[3] = bb .. row[3] .. bb
        else
            row[1] = "\130" .. row[1] .. "\129"
            row[2] = bb .. row[2] .. bb
            row[3] = bgc .. row[3] .. bgc
        end
    end
    return rows
end

-- Anything an app may declare -> 3 blit rows
function icon.build(def, bgName, fallback)
    if icon.isPixel(def) then
        local ok, rows = pcall(icon.render, def, bgName)
        if ok then return rows end
    elseif type(def) == "table" and (def.color or def.art) then
        local ok, rows = pcall(icon.renderLegacy, def, bgName)
        if ok then return rows end
    end
    if fallback and fallback ~= def then return icon.build(fallback, bgName) end
    return icon.render(icon.builtin.package, bgName)
end

-- Loads /etc/icons/<name>.lua (an icon registered by a package)
function icon.load(name)
    local path = "/etc/icons/" .. tostring(name):gsub("[^%w_%-%.]", "_") .. ".lua"
    if not fs.exists(path) then return nil end
    local ok, def = pcall(dofile, path)
    if ok and icon.isPixel(def) then return def end
    return nil
end

function icon.save(name, def)
    if not icon.isPixel(def) then return false, "not a pixel icon" end
    if not fs.exists("/etc/icons") then fs.makeDir("/etc/icons") end
    local path = "/etc/icons/" .. tostring(name):gsub("[^%w_%-%.]", "_") .. ".lua"
    local f = fs.open(path, "w")
    if not f then return false, "cannot write " .. path end
    f.write("return " .. textutils.serialize({ palette = def.palette, pixels = def.pixels }))
    f.close()
    return true
end


------------------------------------------------------------------
-- Generated icons: every package gets its own icon, even when its
-- author did not draw one. The look is derived from the name (colours,
-- badge shape, decoration) and the first letter is drawn in the middle.
------------------------------------------------------------------
icon.font5x7 = {
    ["0"] = { "01110", "10011", "10101", "10101", "10101", "11001", "01110" },
    ["1"] = { "00100", "01100", "00100", "00100", "00100", "00100", "01110" },
    ["2"] = { "01110", "10001", "00001", "00110", "01000", "10000", "11111" },
    ["3"] = { "11110", "00001", "00001", "01110", "00001", "00001", "11110" },
    ["4"] = { "00010", "00110", "01010", "10010", "11111", "00010", "00010" },
    ["5"] = { "11111", "10000", "11110", "00001", "00001", "10001", "01110" },
    ["6"] = { "00110", "01000", "10000", "11110", "10001", "10001", "01110" },
    ["7"] = { "11111", "00001", "00010", "00100", "01000", "01000", "01000" },
    ["8"] = { "01110", "10001", "10001", "01110", "10001", "10001", "01110" },
    ["9"] = { "01110", "10001", "10001", "01111", "00001", "00010", "01100" },
    ["A"] = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
    ["B"] = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
    ["C"] = { "01111", "10000", "10000", "10000", "10000", "10000", "01111" },
    ["D"] = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
    ["E"] = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
    ["F"] = { "11111", "10000", "10000", "11110", "10000", "10000", "10000" },
    ["G"] = { "01111", "10000", "10000", "10111", "10001", "10001", "01110" },
    ["H"] = { "10001", "10001", "10001", "11111", "10001", "10001", "10001" },
    ["I"] = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
    ["J"] = { "00111", "00010", "00010", "00010", "00010", "10010", "01100" },
    ["K"] = { "10001", "10010", "10100", "11000", "10100", "10010", "10001" },
    ["L"] = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
    ["M"] = { "10001", "11011", "10101", "10101", "10001", "10001", "10001" },
    ["N"] = { "10001", "11001", "10101", "10011", "10001", "10001", "10001" },
    ["O"] = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
    ["P"] = { "11110", "10001", "10001", "11110", "10000", "10000", "10000" },
    ["Q"] = { "01110", "10001", "10001", "10001", "10101", "10010", "01101" },
    ["R"] = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
    ["S"] = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
    ["T"] = { "11111", "00100", "00100", "00100", "00100", "00100", "00100" },
    ["U"] = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
    ["V"] = { "10001", "10001", "10001", "10001", "10001", "01010", "00100" },
    ["W"] = { "10001", "10001", "10001", "10101", "10101", "11011", "10001" },
    ["X"] = { "10001", "10001", "01010", "00100", "01010", "10001", "10001" },
    ["Y"] = { "10001", "10001", "01010", "00100", "00100", "00100", "00100" },
    ["Z"] = { "11111", "00001", "00010", "00100", "01000", "10000", "11111" },
}

local SCHEMES = {
    { body = "blue", light = "lightBlue", dark = "gray", ink = "white" },
    { body = "green", light = "lime", dark = "gray", ink = "white" },
    { body = "red", light = "pink", dark = "brown", ink = "white" },
    { body = "orange", light = "yellow", dark = "brown", ink = "black" },
    { body = "purple", light = "magenta", dark = "gray", ink = "white" },
    { body = "cyan", light = "lightBlue", dark = "blue", ink = "white" },
    { body = "magenta", light = "pink", dark = "purple", ink = "white" },
    { body = "brown", light = "orange", dark = "black", ink = "white" },
    { body = "lime", light = "yellow", dark = "green", ink = "black" },
    { body = "gray", light = "lightGray", dark = "black", ink = "white" },
}

local function hashName(name)
    local h = 5381
    for i = 1, #name do h = (h * 33 + name:byte(i)) % 2147483647 end
    return h
end

function icon.generate(name)
    name = tostring(name or "?")
    local h = hashName(name:lower())
    local scheme = SCHEMES[h % #SCHEMES + 1]
    local shape = math.floor(h / 10) % 4        -- decoration
    local letter = name:upper():match("[A-Z0-9]") or "?"
    local glyph = icon.font5x7[letter] or icon.font5x7["?"] or icon.font5x7["O"]
    local W, H = 16, 9
    local g = {}
    for y = 1, H do g[y] = {} for x = 1, W do g[y][x] = "." end end
    -- rounded badge 14 x 9 (x 2..15)
    for y = 1, H do
        for x = 2, 15 do
            local corner = (y == 1 or y == H) and (x == 2 or x == 15)
            if not corner then g[y][x] = "b" end
        end
    end
    -- top light edge, bottom dark edge
    for x = 3, 14 do g[1][x] = "l" g[H][x] = "d" end
    -- decoration
    if shape == 0 then
        for y = 2, H - 1 do g[y][2] = "l" g[y][15] = "d" end
    elseif shape == 1 then
        for x = 3, 14, 2 do g[H - 1][x] = "l" end
    elseif shape == 2 then
        for y = 2, H - 1 do if (y % 2) == 0 then g[y][3] = "l" g[y][14] = "l" end end
    else
        for i = 0, 3 do g[2 + i][3 + i] = "l" end
    end
    -- the letter, 5 x 7 centred (x 6..10, y 2..8) -- one pixel row shorter at the bottom edge
    for r = 1, 7 do
        local row = glyph[r]
        for c = 1, 5 do
            if row:sub(c, c) == "1" then
                local y, x = r + 1 - ((r == 7 and 0) or 0), c + 5
                if y >= 1 and y <= H - 1 then g[y][x] = "i" end
            end
        end
    end
    local rows = {}
    for y = 1, H do rows[y] = table.concat(g[y]) end
    return { palette = { b = scheme.body, l = scheme.light, d = scheme.dark, i = scheme.ink }, pixels = rows }
end

------------------------------------------------------------------
-- Built-in icons (16 x 9 pixels)
------------------------------------------------------------------
icon.builtin = {
    folder = {
        palette = { y = "yellow", o = "orange", w = "#fff3a0" },
        pixels = {
            "................",
            "..yyyyyy........",
            ".yyyyyyyyyyyyyy.",
            ".ywwwwwwwwwwwwy.",
            ".yyyyyyyyyyyyyy.",
            ".yyyyyyyyyyyyyy.",
            ".yyyyyyyyyyyyyy.",
            ".oooooooooooooo.",
            "................",
        },
    },
    file = {
        palette = { w = "white", g = "lightGray", k = "gray" },
        pixels = {
            "....wwwwwwg.....",
            "....wwwwwwgg....",
            "....wwwwwwwwg...",
            "....wkkkkkkwg...",
            "....wwwwwwwwg...",
            "....wkkkkkkwg...",
            "....wwwwwwwwg...",
            "....wkkkkwwwg...",
            "....gggggggg....",
        },
    },
    terminal = {
        palette = { k = "black", g = "gray", l = "lime", w = "lightGray" },
        pixels = {
            "................",
            ".gggggggggggggg.",
            ".gkkkkkkkkkkkkg.",
            ".gkllkkkkkkkkkg.",
            ".gkkkllkkkkkkkg.",
            ".gkllkkkwwwkkkg.",
            ".gkkkkkkkkkkkkg.",
            ".gggggggggggggg.",
            "................",
        },
    },
    package = {
        palette = { b = "brown", o = "orange", t = "yellow", k = "#4a3a2a" },
        pixels = {
            "................",
            "....oooooooo....",
            "..oooottooooooo.",
            ".oooooottoooooo.",
            ".bbbbbbttbbbbbb.",
            ".bbbbbbttbbbbbb.",
            ".bbbbbbttbbbbbb.",
            ".kkkkkkkkkkkkkk.",
            "................",
        },
    },
    tasks = {
        palette = { k = "black", g = "gray", l = "lime", o = "orange", r = "red", w = "white" },
        pixels = {
            "................",
            ".gggggggggggggg.",
            ".gkkkkkkkkkkkkg.",
            ".gkkkkkkkkkkrkg.",
            ".gkkkkkkookrrkg.",
            ".gkkklkkookrrkg.",
            ".gkkllklookrrkg.",
            ".gggggggggggggg.",
            "................",
        },
    },
    settings = {
        palette = { g = "lightGray", d = "gray", k = "black", c = "cyan" },
        pixels = {
            "................",
            "......gggg......",
            "...g.gggggg.g...",
            "....gggddggg....",
            "...ggddkkddgg...",
            "...ggddkkddgg...",
            "....gggddggg....",
            "...g.gggggg.g...",
            "......gggg......",
        },
    },
}
icon.builtin.Files = icon.builtin.folder
icon.builtin.Terminal = icon.builtin.terminal
icon.builtin.Packages = icon.builtin.package
icon.builtin.Tasks = icon.builtin.tasks
icon.builtin.Settings = icon.builtin.settings

return icon
