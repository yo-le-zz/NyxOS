-- Code Editor: Lua/NyxScript syntax colouring, line numbers, open / save /
-- run, find. (Environment variables and virtual memory arrive in 1.4.0.)
return {
    id = "editor",
    name = "Code Editor",
    multi = true,
    profiles = { "classic" },
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
        local state = { path = nil, dirty = false, saved = "" }
        local history, histPos, lastSnap = { "" }, 1, ""

        local function updateTitle()
            local name = state.path or t("untitled")
            ctx.setTitle(t("Code Editor") .. " - " .. name .. (state.dirty and " *" or ""))
        end

        local gutterW = 5
        local sideW = 0           -- width of the folder sidebar (0 = hidden)
        local box = area:addTextBox():setPosition(gutterW + 1, 2):setSize(aw - gutterW, ah - 2)
            :setBackground(palette.black):setForeground(palette.white)
        local gutter = area:addTextBox():setPosition(1, 2):setSize(gutterW, ah - 2)
            :setEditable(false):setBackground(palette.gray):setForeground(palette.lightGray)
        local status = area:addLabel():setText(""):setPosition(1, ah):setSize(aw, 1)
            :setBackground(palette.gray):setForeground(palette.white)

        -- syntax colouring (patterns are applied in order, the last one wins);
        -- the language follows the file extension (lua, nyx, py, c/h/cpp)
        local LANGS = {
            lua = { kw = { "local", "function", "end", "if", "then", "else", "elseif", "for", "while", "do",
                "repeat", "until", "return", "break", "in", "and", "or", "not" },
                const = { "true", "false", "nil" }, fn = { "print", "require" },
                comment = "%-%-.*$", indent = { "then$", "do$", "else$", "repeat$", "function.*%)$", "{$" } },
            py = { kw = { "def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "as",
                "in", "not", "and", "or", "is", "try", "except", "finally", "with", "lambda", "pass", "break",
                "continue", "yield", "raise", "global" },
                const = { "None", "True", "False" }, fn = { "print", "len", "range", "input", "open" },
                comment = "#.*$", indent = { ":$" } },
            c = { kw = { "int", "char", "float", "double", "void", "if", "else", "for", "while", "do", "return",
                "struct", "typedef", "enum", "switch", "case", "break", "continue", "static", "const", "unsigned",
                "long", "short", "sizeof", "class", "public", "private" },
                const = { "NULL", "true", "false" }, fn = { "printf", "malloc", "free", "main" },
                comment = "//.*$", pre = "^%s*#%s*%w+", indent = { "{$" } },
        }
        LANGS.nyx = LANGS.lua
        local lang = "lua"
        local function setLang(name)
            local def = LANGS[name] or LANGS.lua
            lang = LANGS[name] and name or "lua"
            box:clearSyntaxPatterns()
            local function pat(p, color) box:addSyntaxPattern(p, color) end
            for _, kw in ipairs(def.kw) do pat("%f[%w_]" .. kw .. "%f[^%w_]", palette.orange) end
            for _, c in ipairs(def.const) do pat("%f[%w_]" .. c .. "%f[^%w_]", palette.purple) end
            pat("%f[%w_]%d+%.?%d*", palette.cyan)
            for _, f in ipairs(def.fn) do pat("%f[%w_]" .. f .. "%f[^%w_]", palette.lightBlue) end
            if def.pre then pat(def.pre, palette.magenta) end
            pat("\"[^\"]*\"", palette.lime)
            pat("'[^']*'", palette.lime)
            pat(def.comment, palette.lightGray)
        end
        local function langFor(path)
            local ext = tostring(path or ""):match("%.(%w+)$")
            ext = ext and ext:lower()
            if ext == "py" then return "py" end
            if ext == "c" or ext == "h" or ext == "cpp" or ext == "hpp" or ext == "cc" then return "c" end
            if ext == "nyx" then return "nyx" end
            return "lua"
        end
        setLang("lua")

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
                .. "   " .. (state.path or t("untitled"))
                .. (lastAuto and ("   " .. t("autosaved %s", lastAuto)) or "")):sub(1, aw))
        end

        -- The text is compared with what was last loaded/saved: this does not
        -- depend on which key events the text box reports.
        local function refreshDirty()
            local current = box:getText()
            local changed = current ~= state.saved
            if changed ~= state.dirty then
                state.dirty = changed
                updateTitle()
            end
            return changed
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
            state.path, state.dirty, state.saved = path, false, box:getText()
            setLang(langFor(path))
            history, histPos, lastSnap = { box:getText() }, 1, box:getText()
            lastCount = -1
            updateTitle()
            syncGutter()
        end
        local function saveTo(path)
            local f = fs.open(path, "w")
            if not f then ctx.message(t("Error"), t("Cannot write %s", path)) return false end
            local text = box:getText()
            f.write(text)
            f.close()
            state.path, state.dirty, state.saved = path, false, text
            setLang(langFor(path))
            updateTitle()
            return true
        end
        -- Autosave: the file itself when it has a name, else a backup in ~/.autosave
        local lastAuto = nil
        local function autosave()
            if not refreshDirty() then return end
            local target = state.path
            if not target then
                if not ctx.home or not fs.exists(ctx.home) then return end
                target = ctx.home .. "/.autosave/untitled.txt"
            end
            local dir = fs.getDir(target)
            if dir ~= "" and not fs.exists(dir) then ctx.safe("editor", fs.makeDir, dir) end
            local f = fs.open(target, "w")
            if not f then
                ctx.log("warn", "autosave failed: cannot write " .. target)
                return
            end
            local text = box:getText()
            f.write(text)
            f.close()
            if state.path then state.dirty, state.saved = false, text updateTitle() end
            lastAuto = os.date("%H:%M:%S")
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
            if refreshDirty() then
                ctx.confirm(t("Unsaved changes"), t("Discard the changes?"), action)
            else
                action()
            end
        end

        ---------------- undo / redo ----------------
        local histBytes = 0
        local function snapshot()
            local text = box:getText()
            if text == lastSnap then return end
            while #history > histPos do table.remove(history) end
            history[#history + 1] = text
            histPos = #history
            lastSnap = text
            -- bounded memory: at most 200 states / ~300 KB
            histBytes = histBytes + #text
            while #history > 200 or (histBytes > 300000 and #history > 2) do
                histBytes = histBytes - #history[1]
                table.remove(history, 1)
                histPos = histPos - 1
            end
        end
        local function restore(i)
            local text = history[i]
            if not text then return end
            local cx, cy = 1, 1
            pcall(function() cx, cy = box:getCursorX(), box:getCursorY() end)
            box:setText(text)
            pcall(function() box:setCursorY(cy); box:setCursorX(cx) end)
            histPos, lastSnap = i, text
            lastCount = -1
            refreshDirty()
        end
        local function undo() snapshot() if histPos > 1 then restore(histPos - 1) end end
        local function redo() if histPos < #history then restore(histPos + 1) end end

        ---------------- auto-indent ----------------
        local function autoIndent()
            local okL, lines = pcall(function() return box:getLines() end)
            if not okL or not lines then return end
            local cy = box:getCursorY()
            local prev, cur = lines[cy - 1], lines[cy]
            if not prev or (cur and cur:match("^%s")) then return end
            local n = #(prev:match("^[ \t]*") or "")
            local trimmed = prev:gsub("%s+$", "")
            for _, p in ipairs(LANGS[lang].indent) do
                if trimmed:match(p) then n = n + 2 break end
            end
            for _ = 1, n do os.queueEvent("char", " ") end
        end

        local ctrlDown = false
        local function keyHook(key)
            if key == keys.leftCtrl or key == keys.rightCtrl then ctrlDown = true return end
            if not ctx.isActive() then return end
            if ctrlDown and key == keys.z then undo()
            elseif ctrlDown and key == keys.y then redo()
            elseif ctrlDown and key == keys.s then save() end
        end
        local function keyUpHook(key)
            if key == keys.leftCtrl or key == keys.rightCtrl then ctrlDown = false end
        end
        ctx.basalt.onEvent("key", keyHook)
        ctx.basalt.onEvent("key_up", keyUpHook)
        ctx.onClose(function()
            ctx.basalt.removeEvent("key", keyHook)
            ctx.basalt.removeEvent("key_up", keyUpHook)
        end)
        pcall(function()
            box:onKey(function(self, key)
                if key == keys.enter or key == keys.numPadEnter then
                    ctx.basalt.schedule(function() sleep(0.05) pcall(autoIndent) end)
                end
            end)
        end)

        local function toolbar(x, bw, text, bg, fn)
            area:addButton():setText(text):setPosition(x, 1):setSize(bw, 1)
                :setBackground(bg):setForeground(palette.black):onClick(fn)
            return x + bw + 1
        end
        local x = 1
        x = toolbar(x, 5, t("New"), palette.lightGray, function()
            guard(function()
                box:setText("")
                state.path, state.dirty, state.saved = nil, false, box:getText()
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

        x = toolbar(x, 3, "<", palette.lightGray, undo)
        x = toolbar(x, 3, ">", palette.lightGray, redo)

        -- Folder sidebar: "Folder" picks a directory, its files are listed on the
        -- left, a click opens a file (asking before discarding changes).
        local side, sideEntries, folder = nil, {}, nil
        local function layoutBoxes()
            box:setPosition(sideW + gutterW + 1, 2):setSize(aw - sideW - gutterW, ah - 2)
            gutter:setPosition(sideW + 1, 2)
        end
        local refreshSide
        local function showFolder(dir)
            folder = dir
            sideW = math.max(10, math.min(18, math.floor(aw / 3)))
            if not side then
                side = area:addList():setPosition(1, 2):setSize(sideW, ah - 2)
                    :setBackground(palette.gray):setForeground(palette.white)
                    :setSelectedBackground(accent):setSelectedForeground(palette.black)
                side:onSelect(function(self, index)
                    local e = sideEntries[index]
                    if not e then return end
                    if e.kind == "close" then
                        side:setVisible(false)
                        sideW = 0
                        layoutBoxes()
                    elseif e.kind == "dir" then
                        folder = e.path
                        ctx.basalt.schedule(function() sleep(0.05) refreshSide() end)
                    else
                        guard(function() loadFile(e.path) end)
                    end
                end)
            end
            side:setVisible(true):setSize(sideW, ah - 2)
            refreshSide()
            layoutBoxes()
        end
        function refreshSide()
            side:clear()
            sideEntries = { { kind = "close" } }
            side:addItem({ text = "[x] " .. fs.getName(folder):sub(1, sideW - 5), fg = palette.cyan, selectedFg = palette.black })
            if folder ~= "/" then
                local parent = "/" .. fs.getDir(folder)
                if parent == "/" or fs.getDir(folder) == "" then parent = "/" end
                sideEntries[#sideEntries + 1] = { kind = "dir", path = parent }
                side:addItem({ text = "..", fg = palette.yellow, selectedFg = palette.black })
            end
            local names = fs.list(folder)
            table.sort(names, function(a, b)
                local da, db = fs.isDir(fs.combine(folder, a)), fs.isDir(fs.combine(folder, b))
                if da ~= db then return da end
                return a:lower() < b:lower()
            end)
            for _, name in ipairs(names) do
                local path = "/" .. fs.combine(folder, name)
                local isDir = fs.isDir(path)
                sideEntries[#sideEntries + 1] = { kind = isDir and "dir" or "file", path = path }
                side:addItem({ text = (isDir and name .. "/" or name):sub(1, sideW - 1),
                    fg = isDir and palette.yellow or palette.white, selectedFg = palette.black })
            end
        end
        x = toolbar(x, 8, t("Folder"), palette.cyan, function()
            ctx.pickFile({ title = t("Open folder"), mode = "dir", dir = folder or ctx.home }, showFolder)
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
        if type(ctx.restoreState) == "table" then
            local r = ctx.restoreState
            box:setText(r.text or "")
            state.path, state.saved = r.path, r.saved or ""
            state.dirty = box:getText() ~= state.saved
            setLang(langFor(r.path))
            history, histPos, lastSnap = { box:getText() }, 1, box:getText()
            pcall(function() box:setCursorX(r.cx or 1); box:setCursorY(r.cy or 1) end)
            updateTitle()
        elseif type(arg) == "string" and fs.exists(arg) and not fs.isDir(arg) then loadFile(arg) end
        ctx.setSaver(function()
            local cx, cy = 1, 1
            pcall(function() cx, cy = box:getCursorX(), box:getCursorY() end)
            return { text = box:getText(), path = state.path, saved = state.saved, cx = cx, cy = cy }
        end)
        -- closing with unsaved changes: Save / Discard / Cancel
        ctx.setGuard(function()
            if not refreshDirty() then return false end
            ctx.dialog({ title = t("Unsaved changes"), text = t("Save the changes before closing?"),
                ok = "Save", cancel = "Discard", third = "Cancel",
                onOk = function() save(function() ctx.closeWindow(true) end) end,
                onCancel = function() ctx.closeWindow(true) end })
            return true
        end)
        syncGutter()
        ctx.focus(box)

        -- keeps the gutter and the cursor position in sync while the editor is shown
        ctx.basalt.schedule(function()
            while true do
                sleep(0.15)
                if not ctx.alive() then return end
                syncGutter()
                refreshDirty()
                snapshot()
            end
        end)
        ctx.basalt.schedule(function()
            while true do
                local okR, res = pcall(dofile, "/lib/resources.lua")
                sleep(okR and res.budget().autosave or 30)
                if not ctx.alive() then return end
                local okA, errA = pcall(autosave)
                if not okA then ctx.log("warn", "autosave: " .. tostring(errA)) end
            end
        end)
    end,
}
