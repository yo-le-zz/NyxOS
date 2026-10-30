-- System monitor: disk, windows, services, uptime, with a live graph.
return {
    id = "monitor",
    name = "System Monitor",
    multi = false,
    size = { 46, 15 },
    icon = {
        palette = { k = "black", g = "lime", d = "green", y = "yellow", r = "red", w = "lightGray" },
        pixels = {
            "wwwwwwwwwwwwwwww",
            "wkkkkkkkkkkkkkkw",
            "wkkkkkkkkkkgkkkw",
            "wkkkkgkkkkgdgkkw",
            "wkgkkdgkkgkkdkkw",
            "wkdgkdkdgdkkkkkw",
            "wkkdgkkkdkkkkkkw",
            "wkkkkkkkkkkkkkkw",
            "wwwwwwwwwwwwwwww",
        },
    },
    build = function(area, ctx)
        local t, palette = ctx.t, ctx.palette
        local cv = dofile("/lib/canvas.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local text = area:addLabel():setText(""):setPosition(2, 1):setSize(aw - 2, 5)
        local img = area:addImage():setPosition(2, 7):setSize(aw - 2, ah - 7)
        local history = {}
        local started = os.epoch("utc")
        local function bar(frac, width)
            local n = math.floor(math.max(0, math.min(1, frac)) * width + 0.5)
            return "[" .. string.rep("#", n) .. string.rep("-", width - n) .. "]"
        end
        local function update()
            local free, cap = 0, 0
            pcall(function() free = fs.getFreeSpace("/") cap = fs.getCapacity("/") or 0 end)
            if cap == 0 then cap = math.max(1, free) end
            local used = cap - free
            local wins = 0
            pcall(function() for _ in pairs(ctx.windows or {}) do wins = wins + 1 end end)
            local up = math.floor((os.epoch("utc") - started) / 1000)
            local tier = "?"
            pcall(function() local r = dofile("/lib/resources.lua") tier = r.tier and tostring(r.tier()) or tier end)
            text:setText(string.format("%s %s %d%%\n%s %d  KB %s %d KB\n%s %d  %s #%d\n%s %02d:%02d:%02d",
                t("Disk"), bar(used / cap, math.max(8, aw - 20)), math.floor(used / cap * 100),
                t("Used"), math.floor(used / 1024), t("free"), math.floor(free / 1024),
                t("Windows"), wins, "ID", os.getComputerID(),
                t("Session"), math.floor(up / 3600), math.floor(up / 60) % 60, up % 60))
            -- activity graph: free space variations + event-loop jitter
            history[#history + 1] = math.floor(free / 1024)
            while #history > aw - 2 do table.remove(history, 1) end
            local hi, lo = 0, math.huge
            for _, v in ipairs(history) do hi = math.max(hi, v) lo = math.min(lo, v) end
            local gh = ah - 7
            local c = cv.new(aw - 2, gh, "f")
            for i, v in ipairs(history) do
                local frac = (hi == lo) and 0.5 or (v - lo) / (hi - lo)
                local hgt = math.max(1, math.floor(frac * (gh - 1)) + 1)
                c:rect(i, gh - hgt + 1, 1, hgt, frac > 0.5 and "d" or "5")
            end
            c:put(1, 1, t("free space"), "8", "f")
            img:setBimg(c:bimg())
        end
        ctx.setTitle(t("System Monitor"))
        update()
        ctx.basalt.schedule(function()
            while true do
                sleep(1)
                if not ctx.alive() then return end
                update()
            end
        end)
    end,
}
