-- Clock: big digital clock, stopwatch with laps, countdown timer.
local FONT = {
    ["0"] = { "###", "#.#", "#.#", "#.#", "###" },
    ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
    ["2"] = { "###", "..#", "###", "#..", "###" },
    ["3"] = { "###", "..#", "###", "..#", "###" },
    ["4"] = { "#.#", "#.#", "###", "..#", "..#" },
    ["5"] = { "###", "#..", "###", "..#", "###" },
    ["6"] = { "###", "#..", "###", "#.#", "###" },
    ["7"] = { "###", "..#", "..#", ".#.", ".#." },
    ["8"] = { "###", "#.#", "###", "#.#", "###" },
    ["9"] = { "###", "#.#", "###", "..#", "###" },
    [":"] = { ".", "#", ".", "#", "." },
    ["."] = { ".", ".", ".", ".", "#" },
    [" "] = { ".", ".", ".", ".", "." },
}

return {
    id = "clock",
    name = "Clock",
    size = { 40, 12 },
    icon = {
        palette = { w = "white", k = "black", g = "lightGray", r = "red", b = "blue" },
        pixels = {
            "......gggg......",
            "....gwwwwwwg....",
            "...gwwwkwwwwg...",
            "..gwwwwkwwwwwg..",
            "..gwwwwkkkkwwg..",
            "..gwwwwwwwwwwg..",
            "...gwwwwwwwwg...",
            "....gwwwwwwg....",
            "......gggg......",
        },
    },
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local aw, ah = area:getWidth(), area:getHeight()
        local blit = colors.toBlit

        local pgs, tabs = {}, {}
        local function newPage()
            local f = area:addFrame():setPosition(1, 2):setSize(aw, ah - 1):setBackground(palette.black)
            f:setVisible(false)
            pgs[#pgs + 1] = f
            return f
        end
        local current = 1
        local function showPage(i)
            current = i
            for j, f in ipairs(pgs) do f:setVisible(j == i) end
            for j, b in ipairs(tabs) do
                b:setBackground(j == i and accent or palette.gray)
                b:setForeground(j == i and palette.black or palette.white)
            end
        end
        local x = 2
        for i, name in ipairs({ "Clock", "Stopwatch", "Timer" }) do
            local label = " " .. t(name) .. " "
            local b = area:addButton():setText(label):setPosition(x, 1):setSize(#label, 1)
            b:onClick(function() showPage(i) end)
            tabs[i] = b
            x = x + #label + 1
        end

        -- big text as a Basalt image: rows of { text, fg, bg }
        local function bigRows(str, on, off)
            local rows = { {}, {}, {}, {}, {} }
            for r = 1, 5 do rows[r] = { "", "", "" } end
            for i = 1, #str do
                local glyph = FONT[str:sub(i, i)] or FONT[" "]
                for r = 1, 5 do
                    local line = glyph[r]
                    for c = 1, #line do
                        local lit = line:sub(c, c) == "#"
                        rows[r][1] = rows[r][1] .. " "
                        rows[r][2] = rows[r][2] .. blit(palette.black)
                        rows[r][3] = rows[r][3] .. blit(lit and on or off)
                    end
                    rows[r][1] = rows[r][1] .. " "
                    rows[r][2] = rows[r][2] .. blit(palette.black)
                    rows[r][3] = rows[r][3] .. blit(off)
                end
            end
            return rows
        end
        local function bigWidth(str)
            local n = 0
            for i = 1, #str do n = n + #(FONT[str:sub(i, i)] or FONT[" "])[1] + 1 end
            return n
        end
        local function bigImage(parent, y, width)
            local img = parent:addImage():setPosition(1, y):setSize(width, 5)
            return img
        end
        local function setBig(img, str, on, centerW)
            local w2 = bigWidth(str)
            img:setSize(w2, 5):setPosition(math.max(1, math.floor((centerW - w2) / 2) + 1), img:getY())
            img:setBimg({ bigRows(str, on, palette.black) })
        end

        ---------------- Clock ----------------
        local cp = newPage()
        local clockImg = bigImage(cp, 2, 20)
        local dateLabel = cp:addLabel():setText(""):setPosition(1, 8):setSize(aw, 1)
            :setBackground(palette.black):setForeground(palette.lightGray)

        ---------------- Stopwatch ----------------
        local sp = newPage()
        local swImg = bigImage(sp, 2, 20)
        local running, startedAt, elapsed, laps = false, 0, 0, {}
        local lapList = sp:addList():setPosition(2, 7):setSize(aw - 2, math.max(2, ah - 11))
            :setBackground(palette.gray):setForeground(palette.white)
        local function fmt(ms)
            local total = math.floor(ms / 10)
            local cs, s = total % 100, math.floor(total / 100)
            return string.format("%02d:%02d.%02d", math.floor(s / 60), s % 60, cs)
        end
        local function swNow()
            return running and (elapsed + os.epoch("utc") - startedAt) or elapsed
        end
        local startBtn
        startBtn = sp:addButton():setText(t("Start")):setPosition(2, ah - 3):setSize(9, 1)
            :setBackground(palette.lime):setForeground(palette.black)
            :onClick(function()
                if running then
                    elapsed = swNow(); running = false
                    startBtn:setText(t("Start")):setBackground(palette.lime)
                else
                    startedAt = os.epoch("utc"); running = true
                    startBtn:setText(t("Stop")):setBackground(palette.red)
                end
            end)
        sp:addButton():setText(t("Lap")):setPosition(12, ah - 3):setSize(7, 1)
            :setBackground(accent):setForeground(palette.black)
            :onClick(function()
                if running or elapsed > 0 then
                    table.insert(laps, 1, fmt(swNow()))
                    lapList:clear()
                    for i, l in ipairs(laps) do lapList:addItem(string.format("#%d  %s", #laps - i + 1, l)) end
                end
            end)
        sp:addButton():setText(t("Reset")):setPosition(20, ah - 3):setSize(8, 1)
            :setBackground(palette.gray):setForeground(palette.white)
            :onClick(function()
                running, elapsed, laps = false, 0, {}
                startBtn:setText(t("Start")):setBackground(palette.lime)
                lapList:clear()
            end)

        ---------------- Timer ----------------
        local tp = newPage()
        local tmImg = bigImage(tp, 2, 20)
        local tmRunning, tmEnd, tmLeft, tmSet = false, 0, 0, 300000
        local tmStatus = tp:addLabel():setText(""):setPosition(2, 7):setSize(aw - 2, 1)
            :setBackground(palette.black):setForeground(palette.yellow)
        local function tmShow(ms)
            local s = math.max(0, math.ceil(ms / 1000))
            return string.format("%02d:%02d", math.floor(s / 60), s % 60)
        end
        local presets = { 60, 180, 300, 600, 900, 1800 }
        local px = 2
        for _, secs in ipairs(presets) do
            local label = (secs >= 60 and (secs / 60) .. "m" or secs .. "s")
            tp:addButton():setText(label):setPosition(px, 8):setSize(#label + 2, 1)
                :setBackground(palette.lightGray):setForeground(palette.black)
                :onClick(function()
                    tmSet = secs * 1000; tmLeft = tmSet; tmRunning = false
                    tmStatus:setText("")
                end)
            px = px + #label + 3
        end
        tp:addButton():setText("-1m"):setPosition(2, 9):setSize(5, 1)
            :setBackground(palette.gray):setForeground(palette.white)
            :onClick(function() tmSet = math.max(1000, tmSet - 60000); if not tmRunning then tmLeft = tmSet end end)
        tp:addButton():setText("+1m"):setPosition(8, 9):setSize(5, 1)
            :setBackground(palette.gray):setForeground(palette.white)
            :onClick(function() tmSet = tmSet + 60000; if not tmRunning then tmLeft = tmSet end end)
        local tmStart
        tmStart = tp:addButton():setText(t("Start")):setPosition(2, ah - 1):setSize(9, 1)
            :setBackground(palette.lime):setForeground(palette.black)
            :onClick(function()
                if tmRunning then
                    tmLeft = math.max(0, tmEnd - os.epoch("utc")); tmRunning = false
                    tmStart:setText(t("Start")):setBackground(palette.lime)
                else
                    if tmLeft <= 0 then tmLeft = tmSet end
                    tmEnd = os.epoch("utc") + tmLeft; tmRunning = true
                    tmStatus:setText("")
                    tmStart:setText(t("Pause")):setBackground(palette.orange)
                end
            end)
        tp:addButton():setText(t("Reset")):setPosition(12, ah - 1):setSize(8, 1)
            :setBackground(palette.gray):setForeground(palette.white)
            :onClick(function()
                tmRunning = false; tmLeft = tmSet
                tmStatus:setText("")
                tmStart:setText(t("Start")):setBackground(palette.lime)
            end)
        tmLeft = tmSet

        local function beep()
            pcall(function()
                local speaker = peripheral.find("speaker")
                if speaker then
                    for i = 1, 3 do speaker.playNote("bell", 2, 18) sleep(0.25) end
                end
            end)
        end

        local function tick()
            local clockStr = os.date("%H:%M:%S")
            setBig(clockImg, clockStr, accent, aw)
            dateLabel:setText(ctx.center(os.date("%d/%m/%Y"), aw))
            setBig(swImg, fmt(swNow()):sub(1, 5) .. "." .. fmt(swNow()):sub(7), palette.lime, aw)
            if tmRunning then
                tmLeft = math.max(0, tmEnd - os.epoch("utc"))
                if tmLeft == 0 then
                    tmRunning = false
                    tmStart:setText(t("Start")):setBackground(palette.lime)
                    tmStatus:setText(ctx.center(t("Time is up!"), aw - 2))
                    ctx.basalt.schedule(beep)
                end
            end
            setBig(tmImg, tmShow(tmLeft), tmLeft == 0 and palette.red or palette.cyan, aw)
        end
        ctx.setTitle(t("Clock"))
        tick()
        showPage(1)
        ctx.basalt.schedule(function()
            while true do
                sleep(0.1)
                if not ctx.alive() then return end
                tick()
            end
        end)
    end,
}
