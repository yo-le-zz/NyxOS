-- Globe: a rotating Earth (the same renderer as the Globe wallpaper).
return {
    id = "globe",
    name = "Globe",
    multi = true,
    size = { 44, 17 },
    icon = {
        palette = { b = "blue", l = "lightBlue", g = "green", k = "black", w = "white", c = "cyan" },
        pixels = {
            "kkkkkcccccckkkkk",
            "kkkcbbbbbbbckkkk",
            "kkcbbggbbbbbckkk",
            "kcbblgggbbbbbckk",
            "kcbbbggbbbggbckk",
            "kcbbbbbbbgggbckk",
            "kkcbbbbbbbggckkk",
            "kkkcccbbbcccckkk",
            "kkkkkkcccckkkkkk",
        },
    },
    build = function(area, ctx)
        local t, palette = ctx.t, ctx.palette
        local aw, ah = area:getWidth(), area:getHeight()
        local wp = dofile("/lib/wallpaper.lua")
        local gh = ah - 1
        local obj = wp.new("globe", aw, gh)
        local img = area:addImage():setPosition(1, 1):setSize(aw, gh)
        local info = area:addLabel():setText(""):setPosition(1, ah):setSize(aw, 1)
            :setBackground(palette.gray):setForeground(palette.white)
        local n, speed = 0, 1
        local function draw()
            img:setBimg({ obj.frame(n) })
            info:setText(string.format(" < > %s: %d   [Space] %s", t("speed"), speed, t("pause")))
        end
        local function hook(key)
            if not ctx.isActive() then return end
            if key == keys.right then speed = math.min(8, speed + 1)
            elseif key == keys.left then speed = math.max(-8, speed - 1)
            elseif key == keys.space then speed = (speed == 0) and 1 or 0 end
            draw()
        end
        ctx.basalt.onEvent("key", hook)
        ctx.onClose(function() ctx.basalt.removeEvent("key", hook) end)
        ctx.setTitle(t("Globe"))
        draw()
        ctx.basalt.schedule(function()
            while true do
                sleep(0.12)
                if not ctx.alive() then return end
                if speed ~= 0 and ctx.isActive() then
                    n = n + speed * 0.5
                    draw()
                end
            end
        end)
    end,
}
