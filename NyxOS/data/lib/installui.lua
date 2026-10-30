-- /lib/installui.lua : animated screens of the NyxOS installer
--
-- Plain terminal drawing (no Basalt), so it works before anything is
-- installed. Used by install.lua:
--
--   local ui = dofile(dataDir .. "/lib/installui.lua")
--   ui.splash(version)
--   local code = ui.chooseLanguage(dataDir)          -- "en", "fr", ...
--   local apps = ui.chooseApps(dataDir, t)           -- { calculator = true, ... }
--   local p = ui.progress(total, t("Installing files..."))
--   p.step("bin/apt.lua") ... p.finish()

local ui = {}
local palette = colors or colours

local function size() return term.getSize() end

local function clear(bg)
    term.setBackgroundColor(bg or palette.black)
    term.setTextColor(palette.white)
    term.clear()
    term.setCursorPos(1, 1)
end

local function put(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.write(text)
end

local function center(y, text, fg, bg)
    local w = size()
    put(math.max(1, math.floor((w - #text) / 2) + 1), y, text, fg, bg)
end

local function pause(seconds)
    if sleep then sleep(seconds) end
end

-- Globe animation (shares the renderer of the desktop wallpapers)
local function globeSource(w, h)
    if not ui.dataDir then return nil end
    local path = fs.combine(ui.dataDir, "lib/wallpaper.lua")
    if not fs.exists(path) then return nil end
    local ok, wp = pcall(dofile, path)
    if not ok or type(wp) ~= "table" then return nil end
    local ok2, obj = pcall(wp.new, "globe", w, h)
    if ok2 then return obj end
end

local function blitFrame(rows, x0, y0)
    for i, r in ipairs(rows) do
        term.setCursorPos(x0, y0 + i - 1)
        term.blit(r[1], r[2], r[3])
    end
end

local LOGO = {
    " _   _            ___  ____  ",
    "| \\ | |_   ___  _/ _ \\/ ___| ",
    "|  \\| | | | \\ \\/ / | | \\___ \\ ",
    "| |\\  | |_| |>  <| |_| |___) |",
    "|_| \\_|\\__, /_/\\_\\\\___/|____/ ",
    "       |___/                  ",
}

local GRADIENT = { palette.blue, palette.cyan, palette.lightBlue, palette.white }

-- Animated logo: it is drawn column by column with a colour wave, then
-- a loading bar fills under it.
function ui.splash(version)
    local w, h = size()
    clear()
    local g = globeSource(w, h)
    if g then
        for n = 0, 24 do
            local ok, rows = pcall(g.frame, n * 1.5)
            if not ok then break end
            blitFrame(rows, 1, 1)
            pause(0.05)
        end
        clear()
    end
    local lw = #LOGO[1]
    local x0 = math.max(1, math.floor((w - lw) / 2) + 1)
    local y0 = math.max(1, math.floor(h / 2) - 5)
    for col = 1, lw + 3, 2 do
        for row, line in ipairs(LOGO) do
            for c = math.max(1, col - 3), math.min(lw, col + 1) do
                local ch = line:sub(c, c)
                if ch ~= " " then
                    local age = col + 1 - c
                    local colour = GRADIENT[math.max(1, math.min(#GRADIENT, age + 1))]
                    put(x0 + c - 1, y0 + row - 1, ch, colour, palette.black)
                end
            end
        end
        pause(0.03)
    end
    center(y0 + #LOGO + 1, "Version " .. tostring(version), palette.lightGray, palette.black)
    local bw = math.min(30, w - 4)
    local bx = math.floor((w - bw) / 2) + 1
    local by = y0 + #LOGO + 3
    put(bx, by, string.rep(" ", bw), palette.white, palette.gray)
    for i = 1, bw do
        put(bx, by, string.rep(" ", i), palette.white, palette.cyan)
        pause(0.02)
    end
    pause(0.2)
end

local function readLangs(dataDir)
    local list = { { code = "en", name = "English" } }
    local dir = fs.combine(dataDir, "etc/lang")
    if fs.exists(dir) and fs.isDir(dir) then
        local files = fs.list(dir)
        table.sort(files)
        for _, file in ipairs(files) do
            local code = file:match("^([%w_%-]+)%.lua$")
            if code and code ~= "en" then
                local ok, pack = pcall(dofile, fs.combine(dir, file))
                list[#list + 1] = { code = code, name = (ok and type(pack) == "table" and pack._name) or code }
            end
        end
    end
    return list
end

-- Generic vertical menu with keyboard + mouse. `rows` = { { label=..., ... } }
-- `toggle` = true makes Space/click flip row.on. Returns the chosen index
-- (or nil for the "done" action when toggle is on).
local function menu(title, subtitle, rows, opts)
    opts = opts or {}
    local w, h = size()
    local sel = opts.start or 1
    local top = 6
    local visible = math.max(3, h - top - 3)
    local scroll = 0
    local frame = 0
    local timer = os.startTimer(0.15)

    local function draw()
        clear()
        center(2, title, palette.cyan, palette.black)
        if subtitle then center(3, subtitle, palette.lightGray, palette.black) end
        put(1, 4, string.rep("\140", w), palette.gray, palette.black)
        for i = 1, visible do
            local idx = i + scroll
            local row = rows[idx]
            local y = top + i - 1
            if row then
                local active = idx == sel
                local mark = ""
                if opts.toggle then mark = row.on and "[x] " or "[ ] " end
                local text = " " .. mark .. row.label
                if active then
                    local pulse = (frame % 4 < 2) and palette.cyan or palette.lightBlue
                    put(3, y, text .. string.rep(" ", math.max(0, w - 4 - #text)), palette.black, pulse)
                else
                    put(3, y, text .. string.rep(" ", math.max(0, w - 4 - #text)), row.fg or palette.white, palette.black)
                end
            end
        end
        if #rows > visible then
            put(w, top, "\30", palette.gray, palette.black)
            put(w, top + visible - 1, "\31", palette.gray, palette.black)
        end
        put(1, h, string.rep(" ", w), palette.white, palette.gray)
        put(2, h, opts.help or "Up/Down + Enter", palette.white, palette.gray)
        if opts.toggle then
            put(w - 8, h - 1, " [ OK ] ", palette.black, palette.lime)
        end
    end

    local function clamp()
        if sel < 1 then sel = #rows end
        if sel > #rows then sel = 1 end
        if sel <= scroll then scroll = sel - 1 end
        if sel > scroll + visible then scroll = sel - visible end
    end

    draw()
    while true do
        local e, a, b, c = os.pullEvent()
        if e == "timer" and a == timer then
            frame = frame + 1
            timer = os.startTimer(0.15)
            draw()
        elseif e == "key" then
            if a == keys.up then sel = sel - 1; clamp(); draw()
            elseif a == keys.down then sel = sel + 1; clamp(); draw()
            elseif a == keys.space and opts.toggle then
                local row = rows[sel]
                if not row.locked then row.on = not row.on end
                draw()
            elseif a == keys.enter or a == keys.numPadEnter then
                if opts.toggle then return nil end
                return sel
            end
        elseif e == "mouse_click" then
            local x, y = b, c
            if opts.toggle and y == h - 1 and x >= w - 8 then return nil end
            local idx = y - top + 1 + scroll
            if y >= top and y < top + visible and rows[idx] then
                if sel == idx and not opts.toggle then return idx end
                sel = idx
                if opts.toggle then
                    local row = rows[idx]
                    if not row.locked then row.on = not row.on end
                end
                draw()
            end
        elseif e == "mouse_scroll" then
            sel = sel + a; clamp(); draw()
        end
    end
end

-- Returns the language code chosen by the user.
function ui.chooseLanguage(dataDir)
    local langs = readLangs(dataDir)
    if #langs == 1 then return "en" end
    local rows = {}
    for _, l in ipairs(langs) do rows[#rows + 1] = { label = l.name .. "  (" .. l.code .. ")" } end
    local idx = menu("Language / Langue / Idioma / Sprache", "Choose your language", rows,
        { help = "Up/Down + Enter" })
    return langs[idx].code
end

-- Which optional apps to install. Returns { id = bool }.
function ui.chooseApps(dataDir, t)
    t = t or function(s) return s end
    local rows = {}
    local dir = fs.combine(dataDir, "lib/apps")
    if fs.exists(dir) and fs.isDir(dir) then
        local files = fs.list(dir)
        table.sort(files)
        for _, file in ipairs(files) do
            if file:match("%.lua$") then
                local ok, mod = pcall(dofile, fs.combine(dir, file))
                if ok and type(mod) == "table" and mod.id and mod.name then
                    rows[#rows + 1] = {
                        id = mod.id, system = mod.system and true or false,
                        label = t(mod.name) .. (mod.system and ("  (" .. t("system") .. ")") or ""),
                        on = true, locked = mod.system and true or false,
                        fg = mod.system and palette.lightGray or palette.white,
                    }
                end
            end
        end
    end
    if #rows == 0 then return {} end
    -- system apps first
    table.sort(rows, function(a, b)
        if a.system ~= b.system then return a.system end
        return a.id < b.id
    end)
    menu(t("Default apps"), t("Space = on/off, Enter = continue"), rows,
        { toggle = true, help = t("Space = on/off, Enter = continue") })
    local result = {}
    for _, r in ipairs(rows) do
        if not r.system then result[r.id] = r.on end
    end
    return result
end

-- Animated progress screen. total = number of steps (files).
function ui.progress(total, title)
    local w, h = size()
    local done, frame = 0, 0
    local lastLines = {}
    local gw, gh = 20, 10
    local globe = (w >= 50 and h >= 14) and globeSource(gw, gh) or nil
    local textW = globe and (w - gw - 3) or (w - 4)
    local function draw(current)
        clear()
        center(2, title or "Installing...", palette.cyan, palette.black)
        local bw = math.min(40, w - 6)
        local bx = math.floor((w - bw) / 2) + 1
        local filled = math.floor(bw * (done / math.max(1, total)))
        put(bx, 5, string.rep(" ", bw), palette.white, palette.gray)
        if filled > 0 then put(bx, 5, string.rep(" ", filled), palette.white, palette.lime) end
        -- shimmer
        local sx = bx + (frame % math.max(1, filled))
        if filled > 0 and sx <= bx + filled - 1 then put(sx, 5, " ", palette.white, palette.green) end
        center(6, string.format("%d%%", math.floor(100 * done / math.max(1, total))), palette.white, palette.black)
        local spin = ({ "|", "/", "-", "\\" })[frame % 4 + 1]
        center(8, spin .. " " .. (current or ""):sub(1, w - 8), palette.lightGray, palette.black)
        for i, line in ipairs(lastLines) do
            put(3, 10 + i - 1, line:sub(1, textW), palette.gray, palette.black)
        end
        if globe then
            local ok, rows = pcall(globe.frame, frame * 1.2)
            if ok then blitFrame(rows, w - gw, h - gh) end
        end
    end
    local p = {}
    function p.step(name)
        done = done + 1
        frame = frame + 1
        lastLines[#lastLines + 1] = "+ " .. tostring(name)
        while #lastLines > math.max(1, h - 11) do table.remove(lastLines, 1) end
        draw(name)
    end
    function p.finish()
        done = total
        draw("")
        pause(0.4)
    end
    draw("")
    return p
end

-- Counts the files below a folder (for the progress bar)
function ui.countFiles(path)
    if not fs.exists(path) then return 0 end
    if not fs.isDir(path) then return 1 end
    local n = 0
    for _, name in ipairs(fs.list(path)) do n = n + ui.countFiles(fs.combine(path, name)) end
    return n
end

return ui
