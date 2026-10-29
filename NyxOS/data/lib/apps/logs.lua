-- Logs: the system log (/var/log/nyxos.log) with crash details.
return {
    id = "logs",
    name = "Logs",
    system = true,
    multi = true,
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

        -- The log is drawn by hand (a slice of the lines) so that the arrow
        -- keys can move in all four directions: Up/Down, Left/Right,
        -- PageUp/PageDown, Home/End; the mouse wheel scrolls vertically.
        local box = area:addTextBox():setPosition(1, 2):setSize(aw, ah - 1)
            :setEditable(false):setBackground(palette.black):setForeground(palette.lightGray)
        box:addSyntaxPattern("%[ERROR%].*", palette.red)
        box:addSyntaxPattern("%[WARN %].*", palette.yellow)
        local view = ah - 1
        local lines, top, left = {}, 0, 0

        local function longest()
            local n = 0
            for _, l in ipairs(lines) do if #l > n then n = #l end end
            return n
        end
        local function render()
            local maxTop = math.max(0, #lines - view)
            local maxLeft = math.max(0, longest() - aw + 1)
            if top > maxTop then top = maxTop end
            if top < 0 then top = 0 end
            if left > maxLeft then left = maxLeft end
            if left < 0 then left = 0 end
            local out = {}
            for i = top + 1, math.min(#lines, top + view) do
                out[#out + 1] = lines[i]:sub(left + 1, left + aw)
            end
            box:setText(table.concat(out, "\n"))
            ctx.setTitle(t("Logs") .. " - " .. (mode == "errors" and t("errors") or t("all"))
                .. string.format("  (%d/%d)", math.min(#lines, top + view), #lines))
        end
        local function load()
            local okR, res = pcall(dofile, "/lib/resources.lua")
            local n = okR and res.budget().logView or 200
            lines = mode == "errors" and logger.errors(n) or logger.tail(n)
            if #lines == 0 then lines = { t("(log is empty)") } end
            top, left = math.max(0, #lines - view), 0
            render()
        end

        local function onKey(key)
            if key == keys.up then top = top - 1
            elseif key == keys.down then top = top + 1
            elseif key == keys.left then left = left - 8
            elseif key == keys.right then left = left + 8
            elseif key == keys.pageUp then top = top - view
            elseif key == keys.pageDown then top = top + view
            elseif key == keys.home then top, left = 0, 0
            elseif key == keys["end"] then top = #lines
            else return end
            render()
        end
        local function keyHook(key) if ctx.isActive() then onKey(key) end end
        local function scrollHook(dir) if ctx.isActive() then top = top + dir * 3 render() end end
        ctx.basalt.onEvent("key", keyHook)
        ctx.basalt.onEvent("mouse_scroll", scrollHook)
        ctx.onClose(function()
            ctx.basalt.removeEvent("key", keyHook)
            ctx.basalt.removeEvent("mouse_scroll", scrollHook)
        end)

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
