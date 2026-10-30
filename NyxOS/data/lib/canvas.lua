-- /lib/canvas.lua : tiny character-cell canvas for Basalt Image elements
--   local c = dofile("/lib/canvas.lua").new(w, h, "f")   -- "f" = black (blit digit)
--   c:put(x, y, "text", fg, bg)   c:rect(x, y, w, h, bg)   c:bimg()  -- {frame}
local cv = {}
cv.__index = cv

function cv.new(w, h, bg)
    local self = setmetatable({ w = w, h = h, rows = {} }, cv)
    self:clear(bg or "f")
    return self
end

function cv:clear(bg)
    for y = 1, self.h do
        local r = { t = {}, f = {}, b = {} }
        for x = 1, self.w do r.t[x], r.f[x], r.b[x] = " ", "0", bg or "f" end
        self.rows[y] = r
    end
end

function cv:put(x, y, text, fg, bg)
    local r = self.rows[y]
    if not r then return end
    for i = 1, #text do
        local cx = x + i - 1
        if cx >= 1 and cx <= self.w then
            r.t[cx] = text:sub(i, i)
            if fg then r.f[cx] = fg end
            if bg then r.b[cx] = bg end
        end
    end
end

function cv:rect(x, y, w, h, bg, ch, fg)
    for yy = y, y + h - 1 do
        local r = self.rows[yy]
        if r then
            for xx = x, x + w - 1 do
                if xx >= 1 and xx <= self.w then
                    r.b[xx] = bg
                    r.t[xx] = ch or " "
                    if fg then r.f[xx] = fg end
                end
            end
        end
    end
end

function cv:bimg()
    local out = {}
    for y = 1, self.h do
        local r = self.rows[y]
        out[y] = { table.concat(r.t), table.concat(r.f), table.concat(r.b) }
    end
    return { out }
end

-- Blit digit of a colour name ("red" -> "e")
function cv.hex(name)
    return colors.toBlit(colors[name] or colors.black)
end

return cv
