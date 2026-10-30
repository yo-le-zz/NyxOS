-- /lib/wallpaper.lua : desktop wallpapers (static and animated)
--
--   local wp = dofile("/lib/wallpaper.lua")
--   local obj = wp.new("globe", width, height)     -- height in character rows
--   obj.animated, obj.delay                        -- animation info
--   local rows = obj.frame(n)                      -- Basalt bimg frame (n = tick)
--
-- Everything is drawn on a 2x3 sub-pixel grid per character (teletext
-- characters), pixels are blit hex digits "0".."f".

local wp = {}

wp.styles = {
    { id = "none", name = "Solid colour" },
    { id = "gradient", name = "Night gradient" },
    { id = "stars", name = "Starfield" },
    { id = "globe", name = "Globe" },
    { id = "waves", name = "Ocean waves" },
    { id = "plasma", name = "Plasma" },
    { id = "matrix", name = "Matrix rain" },
    { id = "image", name = "Image (Paint)" },
}

local RGB = {
    ["0"] = { 240, 240, 240 }, ["1"] = { 242, 178, 51 }, ["2"] = { 229, 127, 216 }, ["3"] = { 153, 178, 242 },
    ["4"] = { 222, 222, 108 }, ["5"] = { 127, 204, 25 }, ["6"] = { 242, 178, 204 }, ["7"] = { 76, 76, 76 },
    ["8"] = { 153, 153, 153 }, ["9"] = { 76, 153, 178 }, ["a"] = { 178, 102, 229 }, ["b"] = { 51, 102, 204 },
    ["c"] = { 127, 102, 76 }, ["d"] = { 87, 166, 78 }, ["e"] = { 204, 76, 76 }, ["f"] = { 17, 17, 17 },
}
local DIGITS = "0123456789abcdef"
local D = {}
for i = 1, 16 do
    local a = DIGITS:sub(i, i)
    D[a] = {}
    for j = 1, 16 do
        local b = DIGITS:sub(j, j)
        local dr, dg, db = RGB[a][1] - RGB[b][1], RGB[a][2] - RGB[b][2], RGB[a][3] - RGB[b][3]
        D[a][b] = dr * dr + dg * dg + db * db
    end
end

-- Converts a sub-pixel picture (pix(x, y) -> hex digit, 1-based, size 2w x 3h)
-- to a Basalt bimg frame.
local function render(pix, w, h)
    local rows = {}
    local char, sub = string.char, string.sub
    for cy = 1, h do
        local text, fgs, bgs = {}, {}, {}
        for cx = 1, w do
            local px = {}
            for i = 0, 5 do
                px[i + 1] = pix((cx - 1) * 2 + (i % 2) + 1, (cy - 1) * 3 + math.floor(i / 2) + 1) or "f"
            end
            local count, c1, n1 = {}, nil, 0
            for i = 1, 6 do count[px[i]] = (count[px[i]] or 0) + 1 end
            for i = 1, 6 do
                if count[px[i]] > n1 then c1, n1 = px[i], count[px[i]] end
            end
            local c2, d2 = c1, 0
            for i = 1, 6 do
                local d = D[px[i]][c1]
                if d > d2 then c2, d2 = px[i], d end
            end
            local bits = 0
            if c2 ~= c1 then
                for i = 1, 5 do
                    if D[px[i]][c2] < D[px[i]][c1] then bits = bits + 2 ^ (i - 1) end
                end
            end
            local fg, bg = c2, c1
            if c2 ~= c1 and D[px[6]][c2] < D[px[6]][c1] then
                fg, bg = c1, c2
                bits = 31 - bits
            end
            text[cx] = char(128 + bits)
            fgs[cx] = fg
            bgs[cx] = bg
        end
        rows[cy] = { table.concat(text), table.concat(fgs), table.concat(bgs) }
    end
    return rows
end
wp.render = render

local function rnd(seed)
    local s = seed
    return function(n)
        s = (s * 1103515245 + 12345) % 2147483648
        return (s % n) + 1
    end
end

---------------------------------------------------------------- styles
local function gradient(w, h)
    local W, H = w * 2, h * 3
    local bands = { "f", "f", "7", "b", "b", "9", "9", "3" }
    local frame = render(function(x, y)
        local t = y / H
        local i = math.floor(t * #bands) + 1
        -- fine dither between the bands
        local j = math.min(#bands, i + (((x + y) % 2 == 0) and 1 or 0))
        if t < 0.15 then return "f" end
        return bands[math.max(1, math.min(#bands, math.floor((t - 0.15) / 0.85 * #bands) + 1 + (((x + y) % 2 == 0) and 0 or 0)))] or bands[j]
    end, w, h)
    return { animated = false, delay = 1, frame = function() return frame end }
end

local function stars(w, h)
    local W, H = w * 2, h * 3
    local r = rnd(42)
    local list = {}
    for i = 1, math.floor(W * H / 60) do
        list[i] = { x = r(W), y = r(H), phase = r(12), speed = r(3) }
    end
    local cols = { "f", "7", "8", "0", "8", "7" }
    return {
        animated = true, delay = 0.25,
        frame = function(n)
            local map = {}
            for _, s in ipairs(list) do
                local k = (math.floor(n / s.speed) + s.phase) % #cols + 1
                map[s.y * 4096 + s.x] = cols[k]
            end
            return render(function(x, y) return map[y * 4096 + x] or "f" end, w, h)
        end,
    }
end

local function waves(w, h)
    local W, H = w * 2, h * 3
    return {
        animated = true, delay = 0.2,
        frame = function(n)
            return render(function(x, y)
                local base = H * 0.45
                local ph = n * 0.35
                local y1 = base + math.sin(x * 0.12 + ph) * 3 + math.sin(x * 0.05 - ph * 0.6) * 4
                local y2 = base + 12 + math.sin(x * 0.09 - ph * 1.3) * 3 + math.sin(x * 0.2 + ph) * 1.5
                local y3 = base + 24 + math.sin(x * 0.07 + ph * 0.8) * 3
                if y < y1 - 1 then return (y < H * 0.18) and "f" or "7" end
                if y < y1 then return "0" end
                if y < y2 then return "3" end
                if y < y3 then return "b" end
                return "9"
            end, w, h)
        end,
    }
end

local function plasma(w, h)
    local seq = "bb93d5415e2ae2cb"
    local n = #seq
    return {
        animated = true, delay = 0.15,
        frame = function(t)
            local ph = t * 0.25
            return render(function(x, y)
                local v = math.sin(x * 0.11 + ph) + math.sin(y * 0.14 - ph * 0.7)
                    + math.sin((x + y) * 0.07 + ph * 0.5) + math.sin(math.sqrt(x * x * 0.5 + y * y) * 0.09 - ph)
                local k = math.floor((v + 4) / 8 * n) % n + 1
                return seq:sub(k, k)
            end, w, h)
        end,
    }
end

local function matrix(w, h)
    local W, H = w * 2, h * 3
    local r = rnd(7)
    local drops = {}
    for x = 1, W, 2 do
        drops[#drops + 1] = { x = x, y = r(H), len = 6 + r(14), speed = 1 + r(3) }
    end
    return {
        animated = true, delay = 0.12,
        frame = function(n)
            local map = {}
            for _, d in ipairs(drops) do
                local head = (d.y + n * d.speed) % (H + d.len)
                for k = 0, d.len - 1 do
                    local y = head - k
                    if y >= 1 and y <= H then
                        map[y * 4096 + d.x] = (k == 0 and "0") or (k < 3 and "5") or (k < d.len / 2 and "d") or "7"
                    end
                end
            end
            return render(function(x, y) return map[y * 4096 + x] or "f" end, w, h)
        end,
    }
end

-- Rough world map: lon0, lon1, lat0, lat1 boxes
local LAND = {
    { -168, -135, 55, 71 }, { -135, -55, 28, 70 }, { -125, -75, 15, 30 }, { -105, -80, 8, 20 },
    { -55, -20, 60, 82 }, { -80, -35, -20, 10 }, { -73, -50, -55, -20 }, { -8, 2, 50, 59 },
    { -10, 40, 36, 70 }, { 5, 30, 55, 71 }, { -18, 52, -5, 35 }, { 10, 40, -35, -5 }, { 42, 52, -25, -12 },
    { 40, 180, 30, 75 }, { 60, 140, 12, 30 }, { 68, 90, 8, 25 }, { 95, 120, -8, 20 }, { 112, 155, -9, -1 },
    { 114, 153, -39, -11 }, { 130, 145, 31, 44 }, { 166, 178, -46, -35 }, { -180, -168, 62, 70 },
    { -60, 180, -90, -70 },
}
local function isLand(lat, lon)
    for _, b in ipairs(LAND) do
        if lon >= b[1] and lon <= b[2] and lat >= b[3] and lat <= b[4] then return true end
    end
    return false
end

local function globe(w, h)
    local W, H = w * 2, h * 3
    local cx, cy = W / 2, H / 2
    local R = math.floor(math.min(H / 2 - 2, W / 3))
    local r = rnd(99)
    local stars = {}
    for i = 1, math.floor(W * H / 90) do stars[r(H) * 4096 + r(W)] = (r(3) == 1) and "0" or "8" end
    local deg = 180 / math.pi
    return {
        animated = true, delay = 0.2,
        frame = function(n)
            local rot = n * 6
            return render(function(x, y)
                local nx, ny = (x - cx) / R, (y - cy) / R
                local d2 = nx * nx + ny * ny
                if d2 > 1.12 then return stars[y * 4096 + x] or "f" end
                if d2 > 1 then return (d2 < 1.06) and "9" or "7" end
                local nz = math.sqrt(1 - d2)
                local lat = math.asin(-ny) * deg
                local lon = (math.atan2(nx, nz) * deg + rot) % 360 - 180
                -- light comes from the upper left
                local light = nz * 0.7 + (-nx * 0.5 - ny * 0.5) * 0.3 + 0.1
                local land = isLand(lat, lon)
                if lat > 78 or lat < -70 then return light > 0.3 and "0" or "8" end
                if land then
                    if light > 0.65 then return "5" elseif light > 0.3 then return "d" else return "c" end
                end
                if light > 0.7 then return "3" elseif light > 0.3 then return "b" else return "7" end
            end, w, h)
        end,
    }
end

-- Image file: lines of hex digits (NFP / Paint format), space = black
local function image(w, h, path)
    local W, H = w * 2, h * 3
    local lines = {}
    if path and fs.exists(path) and not fs.isDir(path) then
        local f = fs.open(path, "r")
        if f then
            for line in (f.readAll() or ""):gmatch("[^\r\n]+") do lines[#lines + 1] = line end
            f.close()
        end
    end
    local ih = #lines
    local iw = 0
    for _, l in ipairs(lines) do iw = math.max(iw, #l) end
    if ih == 0 or iw == 0 then return gradient(w, h) end
    local frame = render(function(x, y)
        local sx = math.floor((x - 1) * iw / W) + 1
        local sy = math.floor((y - 1) * ih / H) + 1
        local ch = lines[sy] and lines[sy]:sub(sx, sx) or " "
        if RGB[ch] then return ch end
        return "f"
    end, w, h)
    return { animated = false, delay = 1, frame = function() return frame end }
end

function wp.new(id, w, h, opts)
    opts = opts or {}
    local builders = { gradient = gradient, stars = stars, waves = waves, plasma = plasma, matrix = matrix, globe = globe }
    if id == "image" then return image(w, h, opts.path) end
    local b = builders[id]
    if not b then return nil end
    return b(w, h)
end

return wp
