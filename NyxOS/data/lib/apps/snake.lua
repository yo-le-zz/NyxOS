-- Snake: arrow keys / WASD, eat, grow, don't hit the walls or yourself.
return {
    id = "snake",
    name = "Snake",
    multi = true,
    size = { 40, 17 },
    icon = {
        palette = { g = "lime", d = "green", k = "black", r = "red", w = "white", b = "gray" },
        pixels = {
            "bbbbbbbbbbbbbbbb",
            "bkkkkkkkkkkkkkkb",
            "bkgggggggdkkkrkb",
            "bkkkkkkkkgkkkkkb",
            "bkgggggdgdkkkkkb",
            "bkgwkkkkkkkkkkkb",
            "bkgggggggggkkkkb",
            "bkkkkkkkkkkkkkkb",
            "bbbbbbbbbbbbbbbb",
        },
    },
    build = function(area, ctx)
        local t = ctx.t
        local cv = dofile("/lib/canvas.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local gw, gh = math.floor(aw / 2), ah - 1
        local img = area:addImage():setPosition(1, 2):setSize(gw * 2, gh)
        local info = area:addLabel():setText(""):setPosition(1, 1):setSize(aw, 1)
            :setBackground(ctx.palette.gray):setForeground(ctx.palette.white)
        local best = 0
        local snake, dir, nextDir, food, score, dead, paused
        local function newFood()
            repeat
                food = { x = math.random(gw), y = math.random(gh) }
                local clash = false
                for _, s in ipairs(snake) do if s.x == food.x and s.y == food.y then clash = true end end
            until not clash
        end
        local function reset()
            snake = { { x = math.floor(gw / 2), y = math.floor(gh / 2) } }
            for i = 1, 2 do snake[#snake + 1] = { x = snake[1].x - i, y = snake[1].y } end
            dir, nextDir = { 1, 0 }, { 1, 0 }
            score, dead, paused = 0, false, false
            newFood()
        end
        local function draw()
            local c = cv.new(gw * 2, gh, "f")
            c:rect(food.x * 2 - 1, food.y, 2, 1, "e", "o", "1")
            for i, s in ipairs(snake) do
                c:rect(s.x * 2 - 1, s.y, 2, 1, i == 1 and "5" or "d")
            end
            if dead then
                local msg = " " .. t("Game over - Enter to restart") .. " "
                c:put(math.max(1, math.floor((gw * 2 - #msg) / 2)), math.floor(gh / 2), msg, "f", "e")
            elseif paused then
                local msg = " " .. t("Paused") .. " "
                c:put(math.max(1, math.floor((gw * 2 - #msg) / 2)), math.floor(gh / 2), msg, "f", "4")
            end
            img:setBimg(c:bimg())
            info:setText(string.format(" %s %d   %s %d   [P] %s", t("Score"), score, t("Best"), best, t("pause")))
        end
        local function step()
            if dead or paused then return end
            dir = nextDir
            local h = snake[1]
            local nx, ny = h.x + dir[1], h.y + dir[2]
            if nx < 1 or ny < 1 or nx > gw or ny > gh then dead = true return end
            for i = 1, #snake - 1 do
                if snake[i].x == nx and snake[i].y == ny then dead = true return end
            end
            table.insert(snake, 1, { x = nx, y = ny })
            if nx == food.x and ny == food.y then
                score = score + 1
                best = math.max(best, score)
                newFood()
            else
                table.remove(snake)
            end
        end
        local function onKey(key)
            local k = keys.getName and keys.getName(key) or ""
            if (key == keys.up or k == "w") and dir[2] == 0 then nextDir = { 0, -1 }
            elseif (key == keys.down or k == "s") and dir[2] == 0 then nextDir = { 0, 1 }
            elseif (key == keys.left or k == "a") and dir[1] == 0 then nextDir = { -1, 0 }
            elseif (key == keys.right or k == "d") and dir[1] == 0 then nextDir = { 1, 0 }
            elseif k == "p" then paused = not paused
            elseif key == keys.enter and dead then reset() end
            draw()
        end
        local function hook(key) if ctx.isActive() then onKey(key) end end
        ctx.basalt.onEvent("key", hook)
        ctx.onClose(function() ctx.basalt.removeEvent("key", hook) end)
        ctx.setTitle("Snake")
        reset()
        draw()
        ctx.basalt.schedule(function()
            while true do
                sleep(math.max(0.06, 0.18 - score * 0.004))
                if not ctx.alive() then return end
                if ctx.isActive() then step() draw() end
            end
        end)
    end,
}
