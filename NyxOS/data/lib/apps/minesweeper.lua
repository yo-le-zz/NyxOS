-- Minesweeper: click = reveal, right click = flag.
return {
    id = "minesweeper",
    name = "Minesweeper",
    multi = true,
    size = { 24, 14 },
    icon = {
        palette = { g = "lightGray", d = "gray", k = "black", r = "red", w = "white", b = "blue" },
        pixels = {
            "dddddddddddddddd",
            "dgggggdgggggdggd",
            "dgbbgggkggrrgggd",
            "dgbbgdgkkkrrgggd",
            "dgggggdkkkggdggd",
            "dgdgwggkgkgggggd",
            "dgggdgggggdgggdd",
            "dddddddddddddddd",
            "................",
        },
    },
    build = function(area, ctx)
        local t = ctx.t
        local cv = dofile("/lib/canvas.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local N, M = 9, 10
        local img = area:addImage():setPosition(2, 2):setSize(N * 2, N)
        local info = area:addLabel():setText(""):setPosition(1, 1):setSize(aw, 1)
            :setBackground(ctx.palette.gray):setForeground(ctx.palette.white)
        local mine, open, flag, state, flags
        local NUMCOL = { "b", "d", "e", "a", "c", "9", "f", "7" }
        local function reset()
            mine, open, flag = {}, {}, {}
            for y = 1, N do mine[y], open[y], flag[y] = {}, {}, {} end
            local placed = 0
            while placed < M do
                local x, y = math.random(N), math.random(N)
                if not mine[y][x] then mine[y][x] = true placed = placed + 1 end
            end
            state, flags = "play", 0
        end
        local function count(x, y)
            local n = 0
            for dy = -1, 1 do for dx = -1, 1 do
                if mine[y + dy] and mine[y + dy][x + dx] then n = n + 1 end
            end end
            return n
        end
        local function flood(x, y)
            if x < 1 or y < 1 or x > N or y > N or open[y][x] or flag[y][x] then return end
            open[y][x] = true
            if count(x, y) == 0 then
                for dy = -1, 1 do for dx = -1, 1 do flood(x + dx, y + dy) end end
            end
        end
        local function checkWin()
            for y = 1, N do for x = 1, N do
                if not mine[y][x] and not open[y][x] then return end
            end end
            state = "won"
        end
        local function draw()
            local c = cv.new(N * 2, N, "8")
            for y = 1, N do
                for x = 1, N do
                    local px = x * 2 - 1
                    if open[y][x] then
                        c:rect(px, y, 2, 1, "7")
                        if mine[y][x] then c:put(px, y, "*", "e", "7")
                        else
                            local n = count(x, y)
                            if n > 0 then c:put(px, y, tostring(n), NUMCOL[n], "7") end
                        end
                    else
                        c:rect(px, y, 2, 1, "8")
                        c:put(px, y, " ", "0", "8")
                        if flag[y][x] then c:put(px, y, "F", "e", "8") end
                        if state == "lost" and mine[y][x] then c:put(px, y, "*", "f", "e") end
                    end
                end
            end
            img:setBimg(c:bimg())
            local msg = state == "won" and t("You win!") or state == "lost" and t("Boom!") or ""
            info:setText(string.format(" %s %d  %s  [R] %s", t("Mines"), M - flags, msg, t("restart")))
        end
        img:onClick(function(self, btn, rx, ry)
            local x, y = math.floor((rx - 1) / 2) + 1, ry
            if state ~= "play" or x < 1 or y < 1 or x > N or y > N then return end
            if btn == 2 then
                if not open[y][x] then
                    flag[y][x] = not flag[y][x] or nil
                    flags = flags + (flag[y][x] and 1 or -1)
                end
            elseif not flag[y][x] then
                if mine[y][x] then
                    state = "lost"
                    for yy = 1, N do for xx = 1, N do if mine[yy][xx] then open[yy][xx] = false end end end
                    open[y][x] = true
                else
                    flood(x, y)
                    checkWin()
                end
            end
            draw()
        end)
        local function hook(key)
            if ctx.isActive() and keys.getName and keys.getName(key) == "r" then reset() draw() end
        end
        ctx.basalt.onEvent("key", hook)
        ctx.onClose(function() ctx.basalt.removeEvent("key", hook) end)
        ctx.setTitle(t("Minesweeper"))
        local rb = " " .. t("New") .. " "
        area:addButton():setText(rb):setPosition(aw - #rb, ah):setSize(#rb, 1)
            :setBackground(ctx.accent):setForeground(ctx.palette.black):onClick(function() reset() draw() end)
        reset()
        draw()
    end,
}
