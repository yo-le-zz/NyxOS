-- Logs: the system log (/var/log/nyxos.log) with crash details.
return {
    id = "logs",
    name = "Logs",
    system = true,
    color = "red",
    icon = {
        palette = { w = "white", g = "lightGray", k = "gray", r = "red", y = "yellow" },
        pixels = {
            "................",
            "..wwwwwwwwwwww..",
            "..wkkkkkkwwwgw..",
            "..wwwwwwwwwwgw..",
            "..wrrrkkkkwwgw..",
            "..wwwwwwwwwwgw..",
            "..wyyykkkkkkgw..",
            "..wwwwwwwwwwww..",
            "................",
        },
    },
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local logger = dofile("/lib/logger.lua")
        local aw, ah = area:getWidth(), area:getHeight()
        local mode = "all"

        local box = area:addTextBox():setPosition(1, 2):setSize(aw, ah - 1)
            :setEditable(false):setBackground(palette.black):setForeground(palette.lightGray)
        box:addSyntaxPattern("%[ERROR%].*", palette.red)
        box:addSyntaxPattern("%[WARN %].*", palette.yellow)

        local function load()
            local lines = mode == "errors" and logger.errors(200) or logger.tail(200)
            if #lines == 0 then lines = { t("(log is empty)") } end
            box:setText(table.concat(lines, "\n"))
            pcall(function() box:setScrollY(math.max(0, #lines - (ah - 1))) end)
            ctx.setTitle(t("Logs") .. " - " .. (mode == "errors" and t("errors") or t("all")))
        end

        local x = 1
        local function button(label, bg, fg, fn)
            label = " " .. t(label) .. " "
            area:addButton():setText(label):setPosition(x, 1):setSize(#label, 1)
                :setBackground(bg):setForeground(fg):onClick(fn)
            x = x + #label + 1
        end
        button("All", palette.lightGray, palette.black, function() mode = "all"; load() end)
        button("Errors", palette.red, palette.white, function() mode = "errors"; load() end)
        button("Refresh", palette.lightBlue, palette.black, load)
        button("Clear", palette.gray, palette.white, function()
            ctx.confirm("Clear", t("Clear the log?"), function() logger.clear(); load() end)
        end)
        load()
    end,
}
