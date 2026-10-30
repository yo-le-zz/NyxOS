-- 2048: arrow keys slide the tiles, equal tiles merge.
return {
    id = "game2048",
    name = "2048",
    multi = true,
    size = { 30, 16 },
    icon = {
        palette = { o = "orange", y = "yellow", w = "white", b = "brown", g = "lightGray", r = "red" },
        pixels = {
            "................",
            ".bbbbbbbbbbbbbb.",
            ".byyybooobrrrbb.",
            ".byybbobobrbrbb.",
            ".bybybobobrrrbb.",
            ".byyybooobrbbbb.",
            ".bbbbbbbbbbbbbb.",
            "................",
            "................",
        },
    },
    build = function(area, ctx)
        local t = ctx.t
        local cv = dofile("/lib/canvas.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local TW, TH = math.max(5, math.min(7, math.floor((aw - 1) / 4))), 3
        local img = area:addImage():setPosition(1, 2):setSize(TW * 4 + 1, TH * 4 + 1)
        local info = area:addLabel():setText(""):setPosition(1, 1):setSize(aw, 1)
            :setBackground(ctx.palette.gray):setForeground(ctx.palette.white)
        local COL = { [0] = "7", [2] = "0", [4] = "8", [8] = "1", [16] = "1", [32] = "e", [64] = "e",
            [128] = "4", [256] = "4", [512] = "4", [1024] = "5", [2048] = "5" }
        local grid, score, best, over = {}, 0, 0, false
        local function empty()
            local list = {}
            for y = 1, 4 do for x = 1, 4 do if grid[y][x] == 0 then list[#list + 1] = { x, y } end end end
            return list
        end
        local function spawn()
            local e = empty()
            if #e == 0 then return end
            local p = e[math.random(#e)]
            grid[p[2]][p[1]] = math.random(10) == 1 and 4 or 2
        end
        local function reset()
            grid = {}
            for y = 1, 4 do grid[y] = { 0, 0, 0, 0 } end
            score, over = 0, false
            spawn() spawn()
        end
        local function draw()
            local c = cv.new(TW * 4 + 1, TH * 4 + 1, "8")
            for y = 1, 4 do
                for x = 1, 4 do
                    local v = grid[y][x]
                    local bg = COL[v] or "5"
                    local fgc = (v == 0 or v == 2 or v == 4) and "f" or "0"
                    c:rect((x - 1) * TW + 2, (y - 1) * TH + 2, TW - 1, TH - 1, bg)
                    if v > 0 then
                        local s = tostring(v)
                        c:put((x - 1) * TW + 2 + math.floor((TW - 1 - #s) / 2), (y - 1) * TH + 3, s, fgc, bg)
                    end
                end
            end
            if over then
                local m = " " .. t("Game over - Enter") .. " "
                c:put(2, TH * 2 + 1, m, "0", "e")
            end
            img:setBimg(c:bimg())
            info:setText(string.format(" %s %d  %s %d", t("Score"), score, t("Best"), best))
        end
        local function line(vals)
            local out, last = {}, nil
            for _, v in ipairs(vals) do
                if v ~= 0 then
                    if last and out[#out] == v and not last.merged then
                        out[#out] = v * 2
                        score = score + v * 2
                        last.merged = true
                    else
                        out[#out + 1] = v
                        last = { merged = false }
                    end
                end
            end
            while #out < 4 do out[#out + 1] = 0 end
            return out
        end
        local function move(dx, dy)
            local changed = false
            for i = 1, 4 do
                local vals, cells = {}, {}
                for j = 1, 4 do
                    local x, y
                    if dx ~= 0 then y = i; x = dx > 0 and 5 - j or j else x = i; y = dy > 0 and 5 - j or j end
                    cells[j] = { x, y }
                    vals[j] = grid[y][x]
                end
                local res = line(vals)
                for j = 1, 4 do
                    local c = cells[j]
                    if grid[c[2]][c[1]] ~= res[j] then changed = true end
                    grid[c[2]][c[1]] = res[j]
                end
            end
            if changed then
                spawn()
                best = math.max(best, score)
                if #empty() == 0 then
                    local stuck = true
                    for y = 1, 4 do for x = 1, 4 do
                        local v = grid[y][x]
                        if (x < 4 and grid[y][x + 1] == v) or (y < 4 and grid[y + 1][x] == v) then stuck = false end
                    end end
                    over = stuck
                end
            end
        end
        local function hook(key)
            if not ctx.isActive() then return end
            local k = keys.getName and keys.getName(key) or ""
            if over then
                if key == keys.enter then reset() end
            elseif key == keys.left or k == "a" then move(-1, 0)
            elseif key == keys.right or k == "d" then move(1, 0)
            elseif key == keys.up or k == "w" then move(0, -1)
            elseif key == keys.down or k == "s" then move(0, 1)
            elseif key == keys.enter then reset() end
            draw()
        end
        ctx.basalt.onEvent("key", hook)
        ctx.onClose(function() ctx.basalt.removeEvent("key", hook) end)
        ctx.setTitle("2048")
        reset()
        draw()
    end,
}
