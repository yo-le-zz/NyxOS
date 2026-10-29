-- Code Editor: Lua/NyxScript syntax colouring, line numbers, open / save /
-- run, find. (Environment variables and virtual memory arrive in 1.4.0.)
return {
    id = "editor",
    name = "Code Editor",
    icon = {
        palette = { k = "#1c1c2c", g = "gray", c = "cyan", o = "orange", l = "lime", w = "lightGray" },
        pixels = {
            ".gggggggggggggg.",
            ".gkkkkkkkkkkkkg.",
            ".gkwkccckkkkkkg.",
            ".gkwkkkkoookkkg.",
            ".gkwkkllllkkkkg.",
            ".gkwkccckkkkkkg.",
            ".gkwkkkkoooolkg.",
            ".gkkkkkkkkkkkkg.",
            ".gggggggggggggg.",
        },
    },
    build = function(area, ctx, arg)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local aw, ah = area:getWidth(), area:getHeight()
        local state = { path = nil, dirty = false }

        local function updateTitle()
            local name = state.path or t("untitled")
            ctx.setTitle(t("Code Editor") .. " - " .. name .. (state.dirty and " *" or ""))
        end

        local gutterW = 5
        local box = area:addTextBox():setPosition(gutterW + 1, 2):setSize(aw - gutterW, ah - 2)
            :setBackground(palette.black):setForeground(palette.white)
        local gutter = area:addTextBox():setPosition(1, 2):setSize(gutterW, ah - 2)
            :setEditable(false):setBackground(palette.gray):setForeground(palette.lightGray)
        local status = area:addLabel():setText(""):setPosition(1, ah):setSize(aw, 1)
            :setBackground(palette.gray):setForeground(palette.white)

        -- syntax colouring (patterns are applied in order, the last one wins)
        local function pat(p, color) box:addSyntaxPattern(p, color) end
        for _, kw in ipairs({ "local", "function", "end", "if", "then", "else", "elseif",
            "for", "while", "do", "repeat", "until", "return", "break", "in", "and", "or", "not" }) do
            pat("%f[%w_]" .. kw .. "%f[^%w_]", palette.orange)
        end
        pat("%f[%w_]true%f[^%w_]", palette.purple)
        pat("%f[%w_]false%f[^%w_]", palette.purple)
        pat("%f[%w_]nil%f[^%w_]", palette.purple)
        pat("%f[%w_]%d+%.?%d*", palette.cyan)
        pat("%f[%w_]print%f[^%w_]", palette.lightBlue)
        pat("%f[%w_]require%f[^%w_]", palette.lightBlue)
        pat("\"[^\"]*\"", palette.lime)
        pat("'[^']*'", palette.lime)
        pat("%-%-.*$", palette.lightGray)

        local function lineCount()
            local ok, lines = pcall(function() return box:getLines() end)
            return ok and lines and #lines or 1
        end

        local lastScroll, lastCount = -1, -1
        local function syncGutter()
            local count = lineCount()
            local scroll = 0
            pcall(function() scroll = box:getScrollY() or 0 end)
            if count ~= lastCount then
                local numbers = {}
                for i = 1, math.max(count, ah) do
                    numbers[i] = i <= count and string.format("%" .. (gutterW - 1) .. "d", i) or ""
                end
                gutter:setText(table.concat(numbers, "\n"))
                lastCount = count
                lastScroll = -1
            end
            if scroll ~= lastScroll then
                pcall(function() gutter:setScrollY(scroll) end)
                lastScroll = scroll
            end
            local cx, cy = 1, 1
            pcall(function() cx, cy = box:getCursorX(), box:getCursorY() end)
            status:setText((" " .. t("Ln %d, Col %d", cy, cx) .. "   " .. t("%d lines", count)
                .. "   " .. (state.path or t("untitled"))):sub(1, aw))
        end

        local function markDirty()
            if not state.dirty then
                state.dirty = true
                updateTitle()
            end
        end
        pcall(function()
            box:onChar(markDirty)
            box:onKey(function(self, key)
                if key == keys.backspace or key == keys.delete or key == keys.enter
                    or key == keys.tab then
                    markDirty()
                end
            end)
        end)

        local function loadFile(path)
            local f = fs.open(path, "r")
            if not f then ctx.message(t("Error"), t("Cannot open %s", path)) return end
            local text = f.readAll() or ""
            f.close()
            box:setText(text)
            pcall(function() box:setCursorX(1); box:setCursorY(1); box:setScrollY(0) end)
            state.path, state.dirty = path, false
            lastCount = -1
            updateTitle()
            syncGutter()
        end
        local function saveTo(path)
            local f = fs.open(path, "w")
            if not f then ctx.message(t("Error"), t("Cannot write %s", path)) return false end
            f.write(box:getText())
            f.close()
            state.path, state.dirty = path, false
            updateTitle()
            return true
        end
        local function save(after)
            if state.path then
                if saveTo(state.path) and after then after() end
            else
                ctx.pickFile({ title = t("Save as"), mode = "save", dir = ctx.home, name = "new.lua" }, function(path)
                    if saveTo(path) and after then after() end
                end)
            end
        end
        local function guard(action)
            if state.dirty then
                ctx.confirm(t("Unsaved changes"), t("Discard the changes?"), action)
            else
                action()
            end
        end

        local function toolbar(x, bw, text, bg, fn)
            area:addButton():setText(text):setPosition(x, 1):setSize(bw, 1)
                :setBackground(bg):setForeground(palette.black):onClick(fn)
            return x + bw + 1
        end
        local x = 1
        x = toolbar(x, 5, t("New"), palette.lightGray, function()
            guard(function()
                box:setText("")
                state.path, state.dirty = nil, false
                lastCount = -1
                updateTitle()
            end)
        end)
        x = toolbar(x, 6, t("Open"), palette.lightGray, function()
            guard(function()
                ctx.pickFile({ title = t("Open"), mode = "open", dir = ctx.home }, loadFile)
            end)
        end)
        x = toolbar(x, 6, t("Save"), palette.lime, function() save() end)
        x = toolbar(x, 5, t("Run"), palette.orange, function()
            save(function()
                if state.path:match("%.lua$") then ctx.openTerminal(state.path)
                elseif state.path:match("%.nyx$") then ctx.openTerminal("nyx " .. state.path)
                else ctx.message(t("Run"), t("Only .lua and .nyx files can be run.")) end
            end)
        end)

        -- find
        local findInput = area:addInput():setPosition(x + 1, 1):setSize(math.max(6, aw - x - 8), 1)
            :setBackground(palette.gray):setForeground(palette.white):setPlaceholder(t("Find..."))
        local lastFind = { line = 1, col = 0 }
        local function find()
            local needle = findInput:getText() or ""
            if needle == "" then return end
            local ok, lines = pcall(function() return box:getLines() end)
            if not ok or not lines then return end
            local startLine, startCol = lastFind.line, lastFind.col + 1
            for pass = 1, 2 do
                for ln = startLine, #lines do
                    local from = (ln == startLine) and startCol or 1
                    local s = lines[ln]:find(needle, from, true)
                    if s then
                        lastFind = { line = ln, col = s }
                        pcall(function()
                            box:setCursorY(ln); box:setCursorX(s)
                            box:setScrollY(math.max(0, ln - math.floor((ah - 2) / 2)))
                        end)
                        syncGutter()
                        return
                    end
                end
                startLine, startCol = 1, 1 -- wrap around
            end
            status:setText((" " .. t("Not found")):sub(1, aw))
            lastFind = { line = 1, col = 0 }
        end
        findInput:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then find() end
        end)
        area:addButton():setText(t("Find")):setPosition(aw - 6, 1):setSize(6, 1)
            :setBackground(accent):setForeground(palette.black):onClick(find)

        updateTitle()
        if type(arg) == "string" and fs.exists(arg) and not fs.isDir(arg) then loadFile(arg) end
        syncGutter()
        ctx.focus(box)

        -- keeps the gutter and the cursor position in sync while the editor is shown
        ctx.basalt.schedule(function()
            while true do
                sleep(0.15)
                if not ctx.alive() then return end
                syncGutter()
            end
        end)
    end,
}
