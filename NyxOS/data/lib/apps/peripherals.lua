-- Peripherals: attached devices (CC:Tweaked, Advanced Peripherals, Classic Peripherals)
return {
    id = "peripherals",
    name = "Peripherals",
    multi = false,
    size = { 46, 16 },
    icon = {
        palette = { g = "gray", k = "black", l = "lime", w = "lightGray", o = "orange" },
        pixels = {
            "................",
            ".gggggggggggggg.",
            ".gkkkkkkkkkkkkg.",
            ".gklkkkkkkwkwkg.",
            ".gkkkkkkkkkkkkg.",
            ".gkokkkkkkwkwkg.",
            ".gkkkkkkkkkkkkg.",
            ".gggggggggggggg.",
            "................",
        },
    },
    build = function(area, ctx)
        local palette = colors or colours
        local periph = dofile("/lib/periph.lua")
        local t = ctx.t or function(s) return s end
        local w, h = area:getWidth(), area:getHeight()
        local list = area:addList():setPosition(1, 2):setSize(math.floor(w * 0.45), h - 2)
        local detail = area:addLabel():setPosition(math.floor(w * 0.45) + 2, 2):setSize(w - math.floor(w * 0.45) - 2, h - 2)
            :setForeground(palette.white)
        local head = area:addLabel():setPosition(1, 1):setSize(w, 1):setForeground(palette.lightGray)
        local items = {}
        local function show(i)
            local p = items[i]
            if not p then detail:setText("") return end
            local m = periph.methods(p.name)
            local txt = p.label .. "\n" .. p.type .. "\n" .. p.pack .. "\n\n" .. p.hint .. "\n\n" .. #m .. " " .. t("methods")
            detail:setText(txt)
        end
        local function refresh()
            items = periph.scan()
            list:clear()
            for _, p in ipairs(items) do list:addItem(p.name .. "  " .. p.label) end
            head:setText(#items .. " " .. t("peripheral(s)"))
            show(1)
        end
        list:onSelect(function(_, idx) show(idx) end)
        area:addButton():setText(" " .. t("Refresh") .. " "):setPosition(w - 11, h):setSize(11, 1)
            :setBackground(palette.lightGray):setForeground(palette.black):onClick(refresh)
        refresh()
    end,
}
