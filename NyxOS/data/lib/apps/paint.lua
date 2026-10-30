-- Paint: draw pixel pictures (16 colours), save them as .nfp files and use
-- them as the desktop wallpaper.
return {
    id = "paint",
    name = "Paint",
    multi = true,
    size = { 50, 17 },
    icon = {
        palette = { w = "white", r = "red", b = "blue", y = "yellow", g = "lime", k = "gray", o = "orange", p = "magenta" },
        pixels = {
            "kkkkkkkkkkkkkkkk",
            "kwwwwwwwwwwwwwwk",
            "kwrrrwwwwwwbbbwk",
            "kwrrrwwyyywbbbwk",
            "kwwwwwyyyyywwwwk",
            "kwggggwyyywooowk",
            "kwggggwwwwwooowk",
            "kwwwwwwwwwwwwwwk",
            "kkkkkkkkkkkkkkkk",
        },
    },
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local cv = dofile("/lib/canvas.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local PW, PH = aw, ah - 3           -- picture size (1 pixel = 1 cell)
        local DIGITS = "0123456789abcdef"
        local pic = {}
        local function blank(fill)
            for y = 1, PH do
                pic[y] = {}
                for x = 1, PW do pic[y][x] = fill or "f" end
            end
        end
        blank("f")
        local color, tool = "0", "pen"
        local img = area:addImage():setPosition(1, 2):setSize(PW, PH)
        local function draw()
            local c = cv.new(PW, PH, "f")
            for y = 1, PH do for x = 1, PW do c.rows[y].b[x] = pic[y][x] end end
            img:setBimg(c:bimg())
        end
        local function fill(x, y, to)
            local from = pic[y][x]
            if from == to then return end
            local stack = { { x, y } }
            while #stack > 0 do
                local p = table.remove(stack)
                local px, py = p[1], p[2]
                if px >= 1 and py >= 1 and px <= PW and py <= PH and pic[py][px] == from then
                    pic[py][px] = to
                    stack[#stack + 1] = { px + 1, py } stack[#stack + 1] = { px - 1, py }
                    stack[#stack + 1] = { px, py + 1 } stack[#stack + 1] = { px, py - 1 }
                end
            end
        end
        local last
        local function paintAt(rx, ry, btn)
            if rx < 1 or ry < 1 or rx > PW or ry > PH then return end
            local c = (btn == 2) and "f" or color
            if tool == "fill" then fill(rx, ry, c) draw() return end
            -- line from the previous point so fast drags leave no holes
            local x0, y0 = last and last[1] or rx, last and last[2] or ry
            local steps = math.max(math.abs(rx - x0), math.abs(ry - y0), 1)
            for i = 0, steps do
                local x = math.floor(x0 + (rx - x0) * i / steps + 0.5)
                local y = math.floor(y0 + (ry - y0) * i / steps + 0.5)
                if pic[y] and pic[y][x] then pic[y][x] = (tool == "eraser") and "f" or c end
            end
            last = { rx, ry }
            draw()
        end
        img:onClick(function(self, btn, rx, ry) last = nil paintAt(rx, ry, btn) end)
        img:onDrag(function(self, btn, rx, ry) paintAt(rx, ry, btn) end)
        img:onClickUp(function() last = nil end)

        -- palette + tools
        local bar = area:addFrame():setPosition(1, 1):setSize(aw, 1):setBackground(palette.gray)
        local swatches = {}
        local function paintBar()
            for i, b in ipairs(swatches) do
                local d = DIGITS:sub(i, i)
                b:setText(d == color and "x" or " ")
            end
        end
        local sx = 1
        for i = 1, 16 do
            local d = DIGITS:sub(i, i)
            local b = bar:addButton():setText(" "):setPosition(sx, 1):setSize(2, 1)
                :setBackground(2 ^ (i - 1)):setForeground(i == 16 and palette.white or palette.black)
            b:onClick(function() color = d tool = (tool == "eraser") and "pen" or tool paintBar() end)
            swatches[i] = b
            sx = sx + 2
        end
        paintBar()
        local tx = sx + 1
        local toolButtons = {}
        local function paintTools()
            for id, b in pairs(toolButtons) do
                b:setBackground(tool == id and accent or palette.lightGray):setForeground(palette.black)
            end
        end
        for _, def in ipairs({ { "pen", "Pen" }, { "fill", "Fill" }, { "eraser", "Eraser" } }) do
            local label = " " .. t(def[2]) .. " "
            if tx + #label <= aw then
                local b = bar:addButton():setText(label):setPosition(tx, 1):setSize(#label, 1)
                b:onClick(function() tool = def[1] paintTools() end)
                toolButtons[def[1]] = b
                tx = tx + #label
            end
        end
        paintTools()

        -- file bar
        local fb = area:addFrame():setPosition(1, ah):setSize(aw, 1):setBackground(palette.gray)
        local path = fb:addInput():setPosition(1, 1):setSize(math.max(8, aw - 38), 1)
            :setBackground(palette.black):setForeground(palette.white):setText(ctx.home .. "/pic.nfp")
        local msg = area:addLabel():setText(""):setPosition(1, ah - 1):setSize(aw, 1)
            :setBackground(ctx.bg):setForeground(palette.lightGray)
        local function save(to)
            local ok, err = pcall(function()
                local lines = {}
                for y = 1, PH do lines[y] = table.concat(pic[y]) end
                local f = assert(fs.open(to, "w"))
                f.write(table.concat(lines, "\n"))
                f.close()
            end)
            msg:setText(ok and (t("Saved: %s", to)) or tostring(err):sub(1, aw))
            return ok
        end
        local function load(from)
            if not fs.exists(from) or fs.isDir(from) then msg:setText(t("File not found.")) return end
            local f = fs.open(from, "r")
            local lines = {}
            for line in f.readAll():gmatch("[^\r\n]+") do lines[#lines + 1] = line end
            f.close()
            blank("f")
            for y = 1, math.min(PH, #lines) do
                for x = 1, math.min(PW, #lines[y]) do
                    local ch = lines[y]:sub(x, x)
                    if DIGITS:find(ch, 1, true) then pic[y][x] = ch end
                end
            end
            draw()
            msg:setText(t("Opened: %s", from))
        end
        local fx = math.max(8, aw - 38) + 2
        local function fbtn(label, bg, fn)
            label = " " .. t(label) .. " "
            if fx + #label - 1 <= aw then
                fb:addButton():setText(label):setPosition(fx, 1):setSize(#label, 1)
                    :setBackground(bg):setForeground(palette.black):onClick(fn)
                fx = fx + #label + 1
            end
        end
        fbtn("Save", palette.lime, function() save(ctx.trim(path:getText())) end)
        fbtn("Open", accent, function() load(ctx.trim(path:getText())) end)
        fbtn("Clear", palette.orange, function() blank("f") draw() end)
        fbtn("Wallpaper", palette.magenta, function()
            local wp = ctx.home .. "/.wallpaper.nfp"
            if save(wp) then
                local nyxlib = dofile("/lib/nyxlib.lua")
                local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
                cfg.wallpaper, cfg.wallpaperImage = "image", wp
                nyxlib.saveTable("/etc/nyx-config.lua", cfg)
                ctx.restart()
            end
        end)
        ctx.setTitle("Paint")
        draw()
    end,
}
