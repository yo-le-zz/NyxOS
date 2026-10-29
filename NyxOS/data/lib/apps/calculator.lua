-- Calculator: scientific, expression based, with history and memory.
return {
    id = "calculator",
    name = "Calculator",
    multi = true,
    size = { 37, 15 },
    icon = {
        palette = { g = "gray", k = "black", l = "lime", o = "orange", w = "lightGray" },
        pixels = {
            ".gggggggggggggg.",
            ".gkkkkkkkkkkllg.",
            ".gkkkkkkkkkkllg.",
            ".gggggggggggggg.",
            ".gwwgwwgwwgooog.",
            ".gggggggggggggg.",
            ".gwwgwwgwwgooog.",
            ".gggggggggggggg.",
            ".gwwgwwgwwgooog.",
        },
    },
    build = function(area, ctx)
        local t, palette, accent = ctx.t, ctx.palette, ctx.accent
        local math_ = dofile("/lib/mathexpr.lua")
        local aw, ah = area:getWidth(), area:getHeight()

        local padW = 34
        local expr = area:addInput():setPosition(2, 1):setSize(padW, 1)
            :setBackground(palette.gray):setForeground(palette.white)
            :setPlaceholder(t("Type or tap an expression"))
        local result = area:addLabel():setText("= 0"):setPosition(2, 2):setSize(padW, 1)
            :setBackground(palette.black):setForeground(palette.lime)

        local degrees, memory, ans = false, 0, 0
        local historyList, history = nil, {}
        local modeButton

        local function focus() ctx.focus(expr) end
        local function insert(text)
            local current = expr:getText() or ""
            expr:setText(current .. text)
            pcall(function() expr:setCursorPos(#current + #text + 1) end)
            focus()
        end
        local function show(text, color)
            result:setText(text:sub(1, padW)):setForeground(color or palette.lime)
        end
        local function evaluate()
            local src = expr:getText() or ""
            if src:match("^%s*$") then return end
            local value, err = math_.eval(src, { degrees = degrees, ans = ans })
            if value == nil then
                show(t("Error") .. ": " .. tostring(err), palette.red)
            else
                ans = value
                local text = math_.format(value)
                show("= " .. text)
                table.insert(history, 1, { src = src, value = text })
                if #history > 30 then table.remove(history) end
                if historyList then
                    historyList:clear()
                    for _, h in ipairs(history) do historyList:addItem(h.src .. " = " .. h.value) end
                end
                expr:setText("")
            end
            focus()
        end
        expr:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then evaluate() end
        end)

        -- keypad: { label, action, colour } ; action = text to insert or function
        local function clear() expr:setText(""); show("= 0"); focus() end
        local function back()
            local s = expr:getText() or ""
            expr:setText(s:sub(1, -2))
            pcall(function() expr:setCursorPos(#s) end)
            focus()
        end
        local num, op, fn, special = palette.lightGray, palette.orange, palette.cyan, palette.red
        local pad = {
            { { "sin", "sin(", fn }, { "cos", "cos(", fn }, { "tan", "tan(", fn }, { "(", "(", fn }, { ")", ")", fn } },
            { { "ln", "ln(", fn }, { "log", "log(", fn }, { "sqrt", "sqrt(", fn }, { "^", "^", op }, { "n!", "!", op } },
            { { "7", "7", num }, { "8", "8", num }, { "9", "9", num }, { "/", "/", op }, { "C", clear, special } },
            { { "4", "4", num }, { "5", "5", num }, { "6", "6", num }, { "*", "*", op }, { "<-", back, special } },
            { { "1", "1", num }, { "2", "2", num }, { "3", "3", num }, { "-", "-", op }, { "Ans", "ans", fn } },
            { { "0", "0", num }, { ".", ".", num }, { "pi", "pi", fn }, { "+", "+", op }, { "=", evaluate, palette.lime } },
        }
        for r, row in ipairs(pad) do
            for c, def in ipairs(row) do
                local x = 2 + (c - 1) * 7
                local y = 4 + (r - 1) * 2
                local action = def[2]
                area:addButton():setText(def[1]):setPosition(x, y):setSize(6, 1)
                    :setBackground(def[3]):setForeground(palette.black)
                    :onClick(function()
                        if type(action) == "function" then action() else insert(action) end
                    end)
            end
        end

        -- right side: history + memory + angle mode
        local rx = padW + 4
        local rw = aw - rx
        if rw >= 12 then
            area:addLabel():setText(t("History")):setPosition(rx, 1):setForeground(accent)
            historyList = area:addList():setPosition(rx, 2):setSize(rw, ah - 8)
                :setBackground(palette.gray):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            historyList:onSelect(function(self, index)
                local h = history[index]
                if h then insert(h.value) end
            end)
            local function memory_(label, x, fnc)
                area:addButton():setText(label):setPosition(rx + x, ah - 4):setSize(3, 1)
                    :setBackground(palette.purple):setForeground(palette.black)
                    :onClick(function() fnc(); focus() end)
            end
            local function current()
                local value = math_.eval(expr:getText() or "", { degrees = degrees, ans = ans })
                return value or ans
            end
            memory_("MC", 0, function() memory = 0; show("M = 0") end)
            memory_("MR", 3, function() insert(math_.format(memory)) end)
            memory_("M+", 6, function() memory = memory + current(); show("M = " .. math_.format(memory)) end)
            memory_("M-", 9, function() memory = memory - current(); show("M = " .. math_.format(memory)) end)
            modeButton = area:addButton():setText("RAD"):setPosition(rx, ah - 2):setSize(6, 1)
                :setBackground(palette.yellow):setForeground(palette.black)
                :onClick(function()
                    degrees = not degrees
                    modeButton:setText(degrees and "DEG" or "RAD")
                    focus()
                end)
            area:addButton():setText(t("Clear")):setPosition(rx + 7, ah - 2):setSize(math.max(5, rw - 7), 1)
                :setBackground(palette.gray):setForeground(palette.white)
                :onClick(function()
                    history = {}
                    historyList:clear()
                    focus()
                end)
        end
        focus()
    end,
}
