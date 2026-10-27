-- /lib/desktop.lua : NyxOS graphical desktop
--
-- A Basalt-based desktop environment:
--   * icons you can move (click + drag) and launch (double click),
--     snapped to a grid, positions saved in ~/.desktop-layout; several
--     pages when there are many icons
--   * apps (Files, Terminal, Packages, Tasks, Settings), installed
--     packages (apt) and the contents of ~/Desktop all show up as icons
--   * right-click menus, pop-up dialogs (rename, new folder, confirm...)
--   * a taskbar with a Start menu, page switcher and clock
--
-- Apps fill the content area one at a time (there is no floating window
-- manager yet). Programs started from the desktop (package launch,
-- "Exit to shell") run on the real terminal; when they end the desktop
-- is rebuilt.

local desktop = {}
local palette = colors or colours

local function loadBasalt()
    local nyxlib = dofile("/lib/nyxlib.lua")
    return nyxlib.loadBasalt()
end

local function captureCommand(cmd)
    return dofile("/lib/capture.lua").run(cmd)
end

local function colorByName(name, fallback)
    if type(name) == "string" and palette[name] then return palette[name] end
    return fallback
end

local function center(text, width)
    text = tostring(text)
    if #text > width then text = text:sub(1, width - 1) .. "." end
    local left = math.floor((width - #text) / 2)
    return string.rep(" ", left) .. text .. string.rep(" ", width - #text - left)
end

local function trim(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function homeDir()
    local nyxlib = dofile("/lib/nyxlib.lua")
    local session = nyxlib.loadSession()
    if session and session.username then
        local ok, users = pcall(dofile, "/lib/users.lua")
        local user = ok and users.find(session.username)
        if user and user.home then return user.home, session.username end
        return "/home/" .. session.username, session.username
    end
    return "/home", nil
end

------------------------------------------------------------------
-- One run of the desktop. Returns ok, error, request where request is
-- nil (quit), { command = "..." } (run on the real terminal, then come
-- back) or { restart = true }.
------------------------------------------------------------------
local function runOnce()
    local basalt = loadBasalt()
    if not basalt then
        return false, "Basalt unavailable."
    end

    local theme = dofile("/lib/theme.lua")
    local iconlib = dofile("/lib/icon.lua")
    local accent = theme.accent()
    local nyxlib = dofile("/lib/nyxlib.lua")
    local config = nyxlib.loadTable("/etc/nyx-config.lua")
    local desktopBg = colorByName(config.desktopBg, palette.black)
    local home, username = homeDir()
    local request = nil

    pcall(function() dofile("/lib/services.lua").registerPseudo("desktop", "ui", "Graphical desktop (Basalt)") end)

    local ok, runErr = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()

        local content = main:addFrame()
            :setPosition(1, 1):setSize(w, h - 1):setBackground(desktopBg)

        local taskbar = main:addFrame()
            :setPosition(1, h):setSize(w, 1):setBackground(palette.gray)

        local startButton = taskbar:addButton()
            :setText(" Start "):setPosition(1, 1):setSize(8, 1)
            :setBackground(accent):setForeground(palette.black)

        local activeLabel = taskbar:addLabel()
            :setText("Desktop"):setForeground(palette.white):setPosition(10, 1)

        local clockLabel = taskbar:addLabel()
            :setText(""):setForeground(palette.white):setPosition(w - 8, 1)

        local function updateClock()
            clockLabel:setText(os.date("%H:%M:%S"))
        end
        updateClock()
        basalt.schedule(function()
            while true do
                sleep(1)
                updateClock()
            end
        end)

        ------------------------------------------------------------
        -- Frames are never destroyed in the middle of the click that
        -- replaces them: they are hidden at once and destroyed on the
        -- next switch.
        ------------------------------------------------------------
        local graveyard = {}
        local function retire(frame)
            if not frame then return end
            pcall(function() frame:setVisible(false) end)
            table.insert(graveyard, frame)
        end
        local function sweep()
            for _, old in ipairs(graveyard) do
                pcall(function() old:destroy() end)
            end
            graveyard = {}
        end

        ------------------------------------------------------------
        -- Dialogs (pop-ups)
        ------------------------------------------------------------
        local currentDialog = nil
        local function closeDialog()
            if currentDialog then
                retire(currentDialog)
                currentDialog = nil
            end
        end

        -- opts: title, text, input (default text -> shows a text field),
        --       mask, ok (label), cancel (label or false), onOk(value)
        local function openDialog(opts)
            closeDialog()
            sweep()
            local dw = math.min(w - 2, math.max(32, #(opts.text or "") + 4))
            local dh = opts.input and 9 or 7
            local dx, dy = math.floor((w - dw) / 2) + 1, math.floor((h - dh) / 2)
            local d = main:addFrame()
                :setPosition(dx, math.max(1, dy)):setSize(dw, dh)
                :setBackground(palette.gray)
            currentDialog = d
            d:addLabel():setText(center(opts.title or "", dw))
                :setPosition(1, 1):setSize(dw, 1)
                :setBackground(accent):setForeground(palette.black)
            d:addLabel():setText((opts.text or ""):sub(1, dw - 2))
                :setPosition(2, 3):setForeground(palette.white)
            local inputBox
            if opts.input then
                inputBox = d:addInput():setPosition(2, 5):setSize(dw - 2, 1)
                    :setBackground(palette.black):setForeground(palette.white)
                    :setText(opts.input)
                if opts.mask then pcall(function() inputBox:setReplaceChar("*") end) end
                pcall(function() inputBox:setFocused(true) end)
            end
            local function accept()
                local value = inputBox and inputBox:getText() or true
                closeDialog()
                if opts.onOk then opts.onOk(value) end
            end
            local by = dh - 1
            d:addButton():setText(opts.ok or "OK"):setPosition(2, by):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(accept)
            if opts.cancel ~= false then
                d:addButton():setText(opts.cancel or "Cancel"):setPosition(14, by):setSize(10, 1)
                    :setBackground(palette.lightGray):setForeground(palette.black)
                    :onClick(closeDialog)
            end
            if inputBox then
                inputBox:onKey(function(self, key)
                    if key == keys.enter or key == keys.numPadEnter then accept() end
                end)
            end
        end

        local function message(title, text) openDialog({ title = title, text = text, cancel = false }) end
        local function confirm(title, text, onYes)
            openDialog({ title = title, text = text, ok = "Yes", cancel = "No", onOk = onYes })
        end

        -- Context menu: entries = { { "Label", function } ... } at x, y
        local currentMenu = nil
        local function closeMenu()
            if currentMenu then retire(currentMenu); currentMenu = nil end
        end
        local function openMenu(x, y, entries)
            closeMenu()
            local mw = 4
            for _, e in ipairs(entries) do mw = math.max(mw, #e[1] + 3) end
            local mh = #entries
            x = math.max(1, math.min(x, w - mw + 1))
            y = math.max(1, math.min(y, h - mh))
            local m = main:addFrame():setPosition(x, y):setSize(mw, mh):setBackground(palette.lightGray)
            currentMenu = m
            for i, e in ipairs(entries) do
                m:addButton():setText(" " .. e[1]):setPosition(1, i):setSize(mw, 1)
                    :setBackground(palette.lightGray):setForeground(palette.black)
                    :onClick(function()
                        closeMenu()
                        e[2]()
                    end)
            end
        end

        ------------------------------------------------------------
        -- Screens: the desktop or one app at a time
        ------------------------------------------------------------
        local apps = {}
        local currentPanel = nil
        local showDesktop -- forward declaration

        local function newPanel()
            closeMenu()
            sweep()
            if currentPanel then
                retire(currentPanel)
            end
            local panel = content:addFrame()
                :setPosition(1, 1):setSize(w, h - 1):setBackground(desktopBg)
            currentPanel = panel
            return panel
        end

        -- Asks the main loop to run `command` on the real terminal, then
        -- bring the desktop back.
        local function runOnTerminal(command)
            request = { command = command }
            basalt.stop()
        end

        local function launchApp(name, arg)
            for _, a in ipairs(apps) do
                if a.name == name then a.launch(arg) return end
            end
        end
        local function openTerminal(command) launchApp("Terminal", command) end

        local function registerApp(name, color, builder)
            table.insert(apps, {
                name = name,
                color = color,
                launch = function(arg)
                    local area = newPanel()
                    activeLabel:setText(name)
                    builder(area, arg)
                end,
            })
        end

        ------------------------------------------------------------
        -- Desktop: icons, drag & drop, pages
        ------------------------------------------------------------
        local GW, GH = 12, 5                       -- grid cell
        local COLS = math.max(1, math.floor((w - 1) / GW))
        local ROWS = math.max(1, math.floor((h - 2) / GH))
        local layoutPath = home .. "/.desktop-layout"
        local layout = fs.exists(home) and nyxlib.loadTable(layoutPath) or {}
        local page = 1
        local pages = 1
        local selectedId = nil
        local lastClick = { id = nil, at = 0 }
        local drag = nil
        local pageLabel
        local currentItems = {}

        local function saveLayout()
            if fs.exists(home) then pcall(nyxlib.saveTable, layoutPath, layout) end
        end

        local function cellX(col) return (col - 1) * GW + 2 end
        local function cellY(row) return (row - 1) * GH + 2 end

        -- Everything that gets an icon
        local function collectItems()
            local items = {}
            for _, a in ipairs(apps) do
                table.insert(items, {
                    id = "app:" .. a.name, name = a.name, icon = iconlib.builtin[a.name],
                    open = function() a.launch() end, kind = "app",
                })
            end
            local manifest = nyxlib.loadManifest()
            local names = {}
            for name, entry in pairs(manifest) do
                if entry.launch and not entry.removed then table.insert(names, name) end
            end
            table.sort(names)
            for _, name in ipairs(names) do
                local entry = manifest[name]
                table.insert(items, {
                    id = "pkg:" .. name, name = name, kind = "pkg", package = name,
                    icon = (iconlib.isPixel(entry.icon) and entry.icon) or iconlib.load(name)
                        or (type(entry.icon) == "table" and (entry.icon.color or entry.icon.art) and entry.icon)
                        or iconlib.builtin.package,
                    open = function() runOnTerminal(entry.launch) end,
                })
            end
            local deskDir = home .. "/Desktop"
            if fs.exists(deskDir) and fs.isDir(deskDir) then
                local listing = fs.list(deskDir)
                table.sort(listing)
                for _, name in ipairs(listing) do
                    if name:sub(1, 1) ~= "." then
                        local full = "/" .. fs.combine(deskDir, name)
                        local isDir = fs.isDir(full)
                        table.insert(items, {
                            id = "fs:" .. full, name = name, kind = "fs", path = full, dir = isDir,
                            icon = isDir and iconlib.builtin.folder or iconlib.builtin.file,
                            open = function()
                                if isDir then
                                    launchApp("Files", full)
                                elseif name:match("%.lua$") then
                                    openTerminal(full)
                                elseif name:match("%.nyx$") then
                                    openTerminal("nyx " .. full)
                                else
                                    launchApp("Files", "/" .. fs.getDir(full))
                                end
                            end,
                        })
                    end
                end
            end
            return items
        end

        -- Gives every item a position { page, col, row }, keeping saved ones
        local function assignCells(items)
            local taken = {}
            local function key(p, c, r) return p .. ":" .. c .. ":" .. r end
            local seen = {}
            for _, it in ipairs(items) do
                local pos = layout[it.id]
                if type(pos) == "table" and pos.page and pos.col and pos.row
                    and pos.col >= 1 and pos.col <= COLS and pos.row >= 1 and pos.row <= ROWS
                    and not taken[key(pos.page, pos.col, pos.row)] then
                    taken[key(pos.page, pos.col, pos.row)] = it
                    it.pos = pos
                end
                seen[it.id] = true
            end
            for id in pairs(layout) do
                if not seen[id] then layout[id] = nil end
            end
            for _, it in ipairs(items) do
                if not it.pos then
                    local p = 1
                    while not it.pos do
                        for c = 1, COLS do
                            for r = 1, ROWS do
                                if not it.pos and not taken[key(p, c, r)] then
                                    it.pos = { page = p, col = c, row = r }
                                    taken[key(p, c, r)] = it
                                end
                            end
                        end
                        p = p + 1
                    end
                    layout[it.id] = it.pos
                end
            end
            pages = 1
            for _, it in ipairs(items) do pages = math.max(pages, it.pos.page) end
        end

        local function updatePageLabel()
            if pageLabel then
                pageLabel:setText(pages > 1 and ("< " .. page .. "/" .. pages .. " >") or "")
            end
        end

        local function validName(value)
            value = trim(value)
            if value == "" or value:find("/", 1, true) then return nil end
            return value
        end

        local function deleteItem(it)
            if it.kind == "fs" then
                confirm("Delete", "Delete " .. it.name .. " ?", function()
                    local okDel, errDel = pcall(fs.delete, it.path)
                    if not okDel then message("Error", tostring(errDel)) end
                    showDesktop()
                end)
            elseif it.kind == "pkg" then
                confirm("Uninstall", "Uninstall " .. it.package .. " ?", function()
                    openTerminal("apt remove " .. it.package)
                end)
            else
                message("Info", it.name .. " is a system app.")
            end
        end

        local function renameItem(it)
            if it.kind ~= "fs" then
                message("Info", "Only desktop files can be renamed.")
                return
            end
            openDialog({ title = "Rename", text = "New name for " .. it.name, input = it.name,
                onOk = function(value)
                    value = validName(value)
                    if not value then message("Error", "Invalid name.") return end
                    local dest = fs.combine(fs.getDir(it.path), value)
                    if fs.exists(dest) then message("Error", value .. " already exists.") return end
                    local okMv, errMv = pcall(fs.move, it.path, dest)
                    if not okMv then message("Error", tostring(errMv)) return end
                    showDesktop()
                end })
        end

        local function newDesktopEntry(isDir)
            local deskDir = home .. "/Desktop"
            openDialog({ title = isDir and "New folder" or "New file", text = "Name:",
                input = isDir and "New Folder" or "new.txt",
                onOk = function(value)
                    value = validName(value)
                    if not value then message("Error", "Invalid name.") return end
                    if not fs.exists(deskDir) then pcall(fs.makeDir, deskDir) end
                    local dest = fs.combine(deskDir, value)
                    if fs.exists(dest) then message("Error", value .. " already exists.") return end
                    if isDir then
                        pcall(fs.makeDir, dest)
                    else
                        local f = fs.open(dest, "w")
                        if f then f.close() end
                    end
                    showDesktop()
                end })
        end

        local function iconMenu(it, x, y)
            local entries = { { "Open", it.open } }
            if it.kind == "fs" then
                table.insert(entries, { "Rename", function() renameItem(it) end })
                table.insert(entries, { "Delete", function() deleteItem(it) end })
            elseif it.kind == "pkg" then
                table.insert(entries, { "Uninstall", function() deleteItem(it) end })
            end
            openMenu(x, y, entries)
        end

        -- One icon = a frame: pixel image (see /lib/icon.lua) + name
        local function buildIcon(panel, it, x, y)
            local f = panel:addFrame():setPosition(x, y):setSize(10, 4):setBackground(desktopBg)
            it.frame = f
            local rows = iconlib.build(it.icon, config.desktopBg or "black")
            f:addImage():setPosition(2, 1):setSize(8, 3):setBimg({ rows })
            it.nameLabel = f:addLabel():setText(center(it.name, 10)):setPosition(1, 4)
                :setSize(10, 1):setBackground(desktopBg):setForeground(palette.white)
            return f
        end

        local function highlight()
            for _, it in ipairs(currentItems) do
                if it.nameLabel then
                    local sel = (it.id == selectedId)
                    pcall(function()
                        it.nameLabel:setBackground(sel and accent or desktopBg)
                        it.nameLabel:setForeground(sel and palette.black or palette.white)
                    end)
                end
            end
        end

        function showDesktop()
            local panel = newPanel()
            activeLabel:setText("Desktop")
            drag = nil
            currentItems = collectItems()
            assignCells(currentItems)
            if page > pages then page = pages end
            updatePageLabel()

            for _, it in ipairs(currentItems) do
                if it.pos.page == page then
                    local f = buildIcon(panel, it, cellX(it.pos.col), cellY(it.pos.row))
                    f:onClick(function(self, btn, rx, ry)
                        closeMenu()
                        selectedId = it.id
                        highlight()
                        if btn == 2 then
                            iconMenu(it, f:getX() + rx - 1, f:getY() + ry - 1)
                            return
                        end
                        local now = os.epoch("utc")
                        if lastClick.id == it.id and now - lastClick.at < 700 then
                            lastClick = { id = nil, at = 0 }
                            drag = nil
                            it.open()
                            return
                        end
                        lastClick = { id = it.id, at = now }
                        drag = { item = it, offx = rx, offy = ry, moved = false }
                    end)
                end
            end

            -- Drag & drop is tracked on the panel, which sees every drag
            -- event even after the pointer leaves the icon.
            panel:onDrag(function(self, btn, x, y)
                if not drag then return end
                local f = drag.item.frame
                local nx = math.max(1, math.min(w - 9, x - drag.offx + 1))
                local ny = math.max(1, math.min(h - 4, y - drag.offy + 1))
                if nx ~= f:getX() or ny ~= f:getY() then
                    drag.moved = true
                    f:setPosition(nx, ny)
                end
            end)
            panel:onClickUp(function(self, btn, x, y)
                if not drag then return end
                local d = drag
                drag = nil
                if not d.moved then return end
                local f = d.item.frame
                -- nearest grid cell to the icon's centre
                local col = math.max(1, math.min(COLS, math.floor((f:getX() + 4 - 2) / GW + 1.5)))
                local row = math.max(1, math.min(ROWS, math.floor((f:getY() + 1 - 2) / GH + 1.5)))
                local target
                for _, other in ipairs(currentItems) do
                    if other ~= d.item and other.pos.page == page and other.pos.col == col and other.pos.row == row then
                        target = other
                    end
                end
                local old = { page = d.item.pos.page, col = d.item.pos.col, row = d.item.pos.row }
                if target then layout[target.id] = old end
                layout[d.item.id] = { page = page, col = col, row = row }
                saveLayout()
                showDesktop()
            end)
            panel:onClick(function(self, btn, rx, ry)
                closeMenu()
                if selectedId then selectedId = nil; highlight() end
                if btn == 2 then
                    openMenu(rx, ry, {
                        { "New folder", function() newDesktopEntry(true) end },
                        { "New file", function() newDesktopEntry(false) end },
                        { "Refresh", function() showDesktop() end },
                    })
                end
            end)
            highlight()
        end

        ------------------------------------------------------------
        -- App: Files
        ------------------------------------------------------------
        registerApp("Files", palette.yellow, function(area, startDir)
            local currentDir = "/"
            if type(startDir) == "string" and fs.isDir(startDir) then
                currentDir = "/" .. fs.combine("", startDir)
            end
            local entries, selectedIndex = {}, nil
            local lastSel = { index = nil, at = 0 }

            local pathLabel = area:addLabel():setText(""):setPosition(1, 1):setSize(w, 1)
                :setBackground(accent):setForeground(palette.black)
            local list = area:addList():setPosition(1, 3):setSize(w, h - 6)
                :setBackground(palette.gray):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            local status = area:addLabel():setText(""):setForeground(palette.lightGray)
                :setPosition(2, h - 2)

            local function selectedEntry()
                local e = selectedIndex and entries[selectedIndex]
                if not e or e.name == ".." then return nil end
                return e
            end

            local function typeColor(e)
                if e.dir then return palette.yellow end
                if e.name:match("%.lua$") then return palette.lime end
                if e.name:match("%.nyx$") then return palette.cyan end
                if e.name:match("%.json$") or e.name:match("%.txt$") or e.name:match("%.md$") then return palette.lightBlue end
                return palette.white
            end

            local function refresh()
                list:clear()
                entries = {}
                selectedIndex = nil
                if currentDir ~= "/" then
                    table.insert(entries, { name = "..", dir = true })
                end
                local names = fs.list(currentDir)
                table.sort(names, function(a, b)
                    local da, db = fs.isDir(fs.combine(currentDir, a)), fs.isDir(fs.combine(currentDir, b))
                    if da ~= db then return da end
                    return a:lower() < b:lower()
                end)
                for _, name in ipairs(names) do
                    local full = "/" .. fs.combine(currentDir, name)
                    table.insert(entries, { name = name, dir = fs.isDir(full), full = full })
                end
                for _, e in ipairs(entries) do
                    local label = e.name == ".." and "  ..  (up)" or ((e.dir and " [DIR]  " or "        ") .. e.name)
                    if e.full and not e.dir then
                        label = label .. "  " .. nyxlib.formatSize(fs.getSize(e.full))
                    end
                    list:addItem({ text = label, fg = e.name == ".." and palette.lightGray or typeColor(e),
                        selectedFg = palette.black })
                end
                pathLabel:setText(" " .. currentDir)
                status:setText(#names .. " item(s)")
            end

            local function goUp()
                currentDir = "/" .. fs.getDir(currentDir)
                currentDir = "/" .. fs.combine("", currentDir)
                refresh()
            end

            local function openEntry(e)
                if e.name == ".." then goUp()
                elseif e.dir then currentDir = e.full; refresh()
                elseif e.name:match("%.lua$") then openTerminal(e.full)
                elseif e.name:match("%.nyx$") then openTerminal("nyx " .. e.full)
                else status:setText(e.full .. " (" .. nyxlib.formatSize(fs.getSize(e.full)) .. ")") end
            end

            -- one click selects, a second click on the same row opens it
            list:onSelect(function(self, index)
                selectedIndex = index
                local e = entries[index]
                if not e then return end
                local now = os.epoch("utc")
                if lastSel.index == index and now - lastSel.at < 700 then
                    lastSel = { index = nil, at = 0 }
                    openEntry(e)
                    return
                end
                lastSel = { index = index, at = now }
                status:setText(e.full or e.name)
            end)

            local function button(x, bw, text, bg, fg, fn)
                area:addButton():setText(text):setPosition(x, 2):setSize(bw, 1)
                    :setBackground(bg):setForeground(fg):onClick(fn)
            end
            local tb = palette.lightGray
            button(1, 6, " Up", tb, palette.black, goUp)
            button(8, 8, " Open", tb, palette.black, function()
                local e = selectedEntry(); if e then openEntry(e) end
            end)
            button(17, 7, " +Dir", palette.green, palette.black, function()
                openDialog({ title = "New folder", text = "Name:", input = "New Folder", onOk = function(v)
                    v = validName(v)
                    if not v then message("Error", "Invalid name.") return end
                    local dest = fs.combine(currentDir, v)
                    if fs.exists(dest) then message("Error", v .. " already exists.") return end
                    local okMk, errMk = pcall(fs.makeDir, dest)
                    if not okMk then message("Error", tostring(errMk)) end
                    refresh()
                end })
            end)
            button(25, 8, " +File", palette.green, palette.black, function()
                openDialog({ title = "New file", text = "Name:", input = "new.txt", onOk = function(v)
                    v = validName(v)
                    if not v then message("Error", "Invalid name.") return end
                    local dest = fs.combine(currentDir, v)
                    if fs.exists(dest) then message("Error", v .. " already exists.") return end
                    local f = fs.open(dest, "w")
                    if f then f.close() else message("Error", "Cannot create " .. v) end
                    refresh()
                end })
            end)
            button(34, 8, " Rename", palette.orange, palette.black, function()
                local e = selectedEntry()
                if not e then status:setText("Select a file or folder first.") return end
                openDialog({ title = "Rename", text = "New name for " .. e.name, input = e.name, onOk = function(v)
                    v = validName(v)
                    if not v then message("Error", "Invalid name.") return end
                    local dest = fs.combine(fs.getDir(e.full), v)
                    if fs.exists(dest) then message("Error", v .. " already exists.") return end
                    local okMv, errMv = pcall(fs.move, e.full, dest)
                    if not okMv then message("Error", tostring(errMv)) end
                    refresh()
                end })
            end)
            button(43, 8, " Delete", palette.red, palette.white, function()
                local e = selectedEntry()
                if not e then status:setText("Select a file or folder first.") return end
                confirm("Delete", "Delete " .. e.name .. " ?", function()
                    local okDel, errDel = pcall(fs.delete, e.full)
                    if not okDel then message("Error", tostring(errDel)) end
                    refresh()
                end)
            end)

            area:addButton():setText(" Home"):setPosition(w - 20, h - 2):setSize(7, 1)
                :setBackground(palette.lightBlue):setForeground(palette.black)
                :onClick(function() currentDir = fs.exists(home) and home or "/"; refresh() end)
            area:addButton():setText(" Desktop"):setPosition(w - 12, h - 2):setSize(10, 1)
                :setBackground(palette.lightBlue):setForeground(palette.black)
                :onClick(function()
                    local d = home .. "/Desktop"
                    if not fs.exists(d) then pcall(fs.makeDir, d) end
                    currentDir = d
                    refresh()
                end)
            refresh()
        end)

        ------------------------------------------------------------
        -- App: Terminal (the graphical shell, smaller)
        ------------------------------------------------------------
        registerApp("Terminal", palette.cyan, function(area, initialCommand)
            local shellui = dofile("/lib/shellui.lua")
            local controller = shellui.mount(basalt, area, {
                header = false,
                onExit = function() showDesktop() end,
            })
            if type(initialCommand) == "string" and initialCommand ~= "" and controller then
                controller.execute(initialCommand)
            end
        end)

        ------------------------------------------------------------
        -- App: Packages
        ------------------------------------------------------------
        registerApp("Packages", palette.green, function(area)
            local pgs, tabButtons = {}, {}
            local function newPage()
                local f = area:addFrame():setPosition(1, 3):setSize(w, h - 3):setBackground(desktopBg)
                f:setVisible(false)
                table.insert(pgs, f)
                return f
            end
            local function showPage(i)
                for j, f in ipairs(pgs) do f:setVisible(j == i) end
                for j, b in ipairs(tabButtons) do
                    b:setBackground(j == i and accent or palette.gray)
                    b:setForeground(j == i and palette.black or palette.white)
                end
            end
            area:addLabel():setText(" Packages"):setPosition(1, 1):setSize(w, 1)
                :setBackground(accent):setForeground(palette.black)
            for i, name in ipairs({ "Installed", "Browse registry" }) do
                local b = area:addButton():setText(" " .. name .. " ")
                    :setPosition(i == 1 and 2 or 14, 2):setSize(#name + 2, 1)
                b:onClick(function() showPage(i) end)
                tabButtons[i] = b
            end

            -------- installed
            local ip = newPage()
            local names, selectedName = {}, nil
            local list = ip:addList():setPosition(2, 1):setSize(w - 2, h - 10)
                :setBackground(palette.gray):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            local info = ip:addTextBox():setPosition(2, h - 8):setSize(w - 2, 3)
                :setEditable(false):setBackground(palette.black):setForeground(palette.lightGray)

            local function refresh()
                list:clear()
                names = {}
                selectedName = nil
                local manifest = nyxlib.loadManifest()
                for name in pairs(manifest) do table.insert(names, name) end
                table.sort(names)
                for _, name in ipairs(names) do
                    local e = manifest[name]
                    local tag = e.removed and " (removed)" or (e.launch and "" or " (no launcher)")
                    list:addItem({ text = name .. "  v" .. tostring(e.version or "?") .. "  " .. tostring(e.variant or "") .. tag,
                        fg = e.removed and palette.lightGray or palette.white })
                end
                info:setText(#names == 0 and "No package installed yet. Open the Browse tab." or "Select a package.")
            end
            list:onSelect(function(self, index)
                selectedName = names[index]
                local e = selectedName and nyxlib.loadManifest()[selectedName]
                if e then
                    info:setText((e.description or "") .. "\nLaunch: " .. tostring(e.launch or "-") ..
                        "   Service: " .. tostring(e.service or "-"))
                end
            end)
            refresh()

            local function need()
                if not selectedName then info:setText("Select a package first.") end
                return selectedName
            end
            local by = h - 5
            ip:addButton():setText(" Launch"):setPosition(2, by):setSize(9, 1)
                :setBackground(palette.green):setForeground(palette.black)
                :onClick(function()
                    local name = need(); if not name then return end
                    local e = nyxlib.loadManifest()[name]
                    if e and e.launch then runOnTerminal(e.launch)
                    elseif e and e.service then openTerminal("service start " .. e.service)
                    else info:setText(name .. " has no launcher (it is a library).") end
                end)
            ip:addButton():setText(" Update"):setPosition(12, by):setSize(9, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function() local n = need(); if n then openTerminal("apt update " .. n) end end)
            ip:addButton():setText(" Remove"):setPosition(22, by):setSize(9, 1)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function()
                    local n = need(); if not n then return end
                    confirm("Remove", "Remove " .. n .. " ?", function() openTerminal("apt remove " .. n) end)
                end)
            ip:addButton():setText(" Purge"):setPosition(32, by):setSize(8, 1)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function()
                    local n = need(); if not n then return end
                    confirm("Purge", "Delete " .. n .. " and its config?", function() openTerminal("apt purge " .. n) end)
                end)
            ip:addButton():setText(" Refresh"):setPosition(2, by + 1):setSize(10, 1)
                :setBackground(palette.lightBlue):setForeground(palette.black)
                :onClick(refresh)

            -------- browse
            local bp = newPage()
            bp:addLabel():setText("Search:"):setForeground(palette.white):setPosition(2, 1)
            local searchInput = bp:addInput():setPosition(10, 1):setSize(w - 22, 1)
                :setBackground(palette.gray):setForeground(palette.white):setText("")
            local results, pick = {}, nil
            local blist = bp:addList():setPosition(2, 3):setSize(w - 2, h - 9)
                :setBackground(palette.gray):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            local bstatus = bp:addLabel():setText("Type a name (empty = everything), then Search."):setForeground(palette.lightGray)
                :setPosition(2, h - 5)
            blist:onSelect(function(self, index) pick = results[index] end)

            local searching = false
            local function search()
                if searching then return end
                searching = true
                bstatus:setText("Searching the registry...")
                local q = trim(searchInput:getText())
                basalt.schedule(function()
                    local out, err = captureCommand("apt search " .. (q ~= "" and q or "*"))
                    searching = false
                    blist:clear()
                    results, pick = {}, nil
                    for line in (out or ""):gmatch("[^\n]+") do
                        local name = line:match("^(%S+) v")
                        if name then
                            table.insert(results, name)
                            blist:addItem(line)
                        end
                    end
                    if #results > 0 then
                        bstatus:setText(#results .. " package(s). Select one, then Install.")
                    else
                        bstatus:setText((err and tostring(err) or ((out and out ~= "") and out or "No result.")):sub(1, w - 4))
                    end
                end)
            end
            bp:addButton():setText(" Search"):setPosition(w - 11, 1):setSize(9, 1)
                :setBackground(accent):setForeground(palette.black):onClick(search)
            bp:addButton():setText(" Install"):setPosition(2, h - 4):setSize(10, 1)
                :setBackground(palette.green):setForeground(palette.black)
                :onClick(function()
                    if pick then openTerminal("apt install " .. pick)
                    else bstatus:setText("Select a package first.") end
                end)

            showPage(1)
        end)

        ------------------------------------------------------------
        -- App: Task Manager
        ------------------------------------------------------------
        registerApp("Tasks", palette.orange, function(area)
            local servicesOk, services = pcall(dofile, "/lib/services.lua")
            local specs = dofile("/lib/specs.lua")
            local procui = dofile("/lib/procui.lua")
            local aw, ah = area:getWidth(), area:getHeight()

            local pgs = {}
            local function newPage()
                local f = area:addFrame():setPosition(1, 3):setSize(aw, ah - 2):setBackground(desktopBg)
                f:setVisible(false)
                table.insert(pgs, f)
                return f
            end
            local tabButtons = {}
            local function showPage(i)
                for j, f in ipairs(pgs) do f:setVisible(j == i) end
                for j, b in ipairs(tabButtons) do
                    b:setBackground(j == i and accent or palette.gray)
                    b:setForeground(j == i and palette.black or palette.white)
                end
            end
            area:addLabel():setText(" Task Manager"):setPosition(1, 1):setSize(aw, 1)
                :setBackground(accent):setForeground(palette.black)
            local tx = 2
            for i, name in ipairs({ "Processes", "Specs", "Power" }) do
                local b = area:addButton():setText(" " .. name .. " "):setPosition(tx, 2):setSize(#name + 2, 1)
                b:onClick(function() showPage(i) end)
                tabButtons[i] = b
                tx = tx + #name + 3
            end

            ---------------- Processes ----------------
            local pp = newPage()
            local list = pp:addList():setPosition(2, 1):setSize(aw - 2, ah - 7)
                :setBackground(palette.gray):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            local info = pp:addLabel():setText(""):setForeground(palette.lightGray):setPosition(2, ah - 5)

            local rows, selected = {}, nil
            local kindColor = { shell = palette.cyan, service = palette.lime, job = palette.yellow,
                system = palette.lightGray, ui = palette.pink }
            local function refresh()
                list:clear()
                rows = {}
                if not (servicesOk and services) then return end
                local running = {}
                for _, p in ipairs(services.processes()) do
                    table.insert(rows, p)
                    if p.kind == "service" then running[p.name] = true end
                end
                for _, def in ipairs(services.list()) do
                    if not running[def.name] then
                        table.insert(rows, { pid = 0, name = def.name, kind = "service", state = "stopped",
                            user = "root", killable = false, description = def.description })
                    end
                end
                for _, p in ipairs(rows) do
                    list:addItem({
                        text = string.format("%-4s %-13s %-8s %s",
                            p.pid > 0 and p.pid or "-", tostring(p.name):sub(1, 13), p.kind, p.state),
                        fg = p.state == "stopped" and palette.lightGray or (kindColor[p.kind] or palette.white),
                    })
                end
            end
            refresh()

            list:onSelect(function(self, index)
                selected = rows[index]
                if selected then
                    info:setText(((selected.description or selected.cmd or "")):sub(1, aw - 4))
                end
            end)

            local function act(fn)
                if not selected then info:setText("Select a row first."); return end
                local okAct, msg = pcall(fn, selected)
                info:setText(tostring(okAct and msg or ("Error: " .. tostring(msg))):sub(1, aw - 4))
                refresh()
            end
            local by = ah - 3
            pp:addButton():setText("Kill"):setPosition(2, by):setSize(7, 1)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function()
                    act(function(p)
                        if not p.killable then return p.name .. " cannot be killed here." end
                        local _, msg = procui.killPid(p.pid)
                        return msg
                    end)
                end)
            pp:addButton():setText("Start"):setPosition(10, by):setSize(8, 1)
                :setBackground(palette.green):setForeground(palette.black)
                :onClick(function()
                    act(function(p)
                        if p.kind ~= "service" then return "Only services can be started." end
                        local pid, err = services.start(p.name)
                        return pid and ("started " .. p.name .. " (pid " .. pid .. ")") or tostring(err)
                    end)
                end)
            pp:addButton():setText("Stop"):setPosition(19, by):setSize(7, 1)
                :setBackground(palette.orange):setForeground(palette.black)
                :onClick(function()
                    act(function(p)
                        if p.kind ~= "service" or p.pid == 0 then return "Not a running service." end
                        local _, msg = procui.killPid(p.pid)
                        return msg
                    end)
                end)
            pp:addButton():setText("Enable"):setPosition(27, by):setSize(8, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    act(function(p)
                        if p.kind ~= "service" then return "Only services have autostart." end
                        services.setAutostart(p.name, true)
                        return p.name .. ": autostart on"
                    end)
                end)
            pp:addButton():setText("Disable"):setPosition(36, by):setSize(9, 1)
                :setBackground(palette.gray):setForeground(palette.white)
                :onClick(function()
                    act(function(p)
                        if p.kind ~= "service" then return "Only services have autostart." end
                        services.setAutostart(p.name, false)
                        return p.name .. ": autostart off"
                    end)
                end)
            pp:addButton():setText("Refresh"):setPosition(2, by + 1):setSize(9, 1)
                :setBackground(palette.lightBlue):setForeground(palette.black)
                :onClick(function() refresh(); info:setText("Refreshed.") end)

            ---------------- Specs ----------------
            local sp = newPage()
            local specBox = sp:addTextBox():setPosition(2, 1):setSize(aw - 2, ah - 4)
                :setEditable(false):setBackground(palette.black):setForeground(palette.white)
            local function loadSpecs()
                local lines = {}
                for _, row in ipairs(specs.collect()) do
                    lines[#lines + 1] = string.format("%-14s %s", row[1], row[2])
                end
                specBox:setText(table.concat(lines, "\n"))
            end
            loadSpecs()
            sp:addButton():setText("Refresh"):setPosition(2, ah - 3):setSize(9, 1)
                :setBackground(palette.lightBlue):setForeground(palette.black)
                :onClick(loadSpecs)

            ---------------- Power ----------------
            local pw = newPage()
            pw:addLabel():setText("Power"):setForeground(accent):setPosition(2, 2)
            pw:addButton():setText(" Reboot "):setPosition(2, 4):setSize(12, 3)
                :setBackground(palette.orange):setForeground(palette.black)
                :onClick(function() runOnTerminal("reboot") end)
            pw:addButton():setText(" Shutdown "):setPosition(16, 4):setSize(14, 3)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function() runOnTerminal("shutdown") end)

            showPage(1)
        end)

        ------------------------------------------------------------
        -- App: Settings (centered, four pages)
        ------------------------------------------------------------
        registerApp("Settings", palette.purple, function(area)
            local aw, ah = area:getWidth(), area:getHeight()
            local cw = math.min(aw - 2, 42)
            local cx = math.floor((aw - cw) / 2) + 1

            area:addLabel():setText(center("Settings", aw)):setPosition(1, 1):setSize(aw, 1)
                :setBackground(accent):setForeground(palette.black)

            local pgs, tabButtons = {}, {}
            local function newPage()
                local f = area:addFrame():setPosition(cx, 4):setSize(cw, ah - 4):setBackground(desktopBg)
                f:setVisible(false)
                table.insert(pgs, f)
                return f
            end
            local function showPage(i)
                for j, f in ipairs(pgs) do f:setVisible(j == i) end
                for j, b in ipairs(tabButtons) do
                    b:setBackground(j == i and accent or palette.gray)
                    b:setForeground(j == i and palette.black or palette.white)
                end
            end
            local tabNames = { "General", "Account", "Look", "System" }
            local tabW = math.floor(cw / #tabNames)
            for i, name in ipairs(tabNames) do
                local b = area:addButton():setText(center(name, tabW)):setPosition(cx + (i - 1) * tabW, 2):setSize(tabW, 1)
                b:onClick(function() showPage(i) end)
                tabButtons[i] = b
            end

            local function section(parent, y, text, color)
                parent:addLabel():setText(center(text, cw)):setPosition(1, y):setSize(cw, 1)
                    :setBackground(color or palette.gray):setForeground(palette.black)
            end
            local function field(parent, y, label, text, masked)
                parent:addLabel():setText(label):setForeground(palette.white):setPosition(1, y)
                local input = parent:addInput():setPosition(1, y + 1):setSize(cw, 1)
                    :setBackground(palette.gray):setForeground(palette.white):setText(text or "")
                if masked then pcall(function() input:setReplaceChar("*") end) end
                return input
            end

            ---------------- General ----------------
            local gp = newPage()
            section(gp, 1, "Computer", palette.cyan)
            local hostInput = field(gp, 3, "Hostname", nyxlib.getHostname())
            section(gp, 6, "Interface at boot", palette.lime)
            local mode = config.uiMode or "shell"
            local modeLabel = gp:addLabel():setText(""):setForeground(palette.white):setPosition(1, 8)
            local function setModeLabel()
                modeLabel:setText(("Current: " .. mode):sub(1, cw))
            end
            setModeLabel()
            gp:addLabel():setText("shell: graphical shell  desktop: this"):setForeground(palette.lightGray):setPosition(1, 9)
            gp:addLabel():setText("server: text shell + services"):setForeground(palette.lightGray):setPosition(1, 10)
            local mx = 1
            for _, m in ipairs({ "shell", "desktop", "server" }) do
                gp:addButton():setText(" " .. m .. " "):setPosition(mx, 12):setSize(#m + 2, 1)
                    :setBackground(palette.lightGray):setForeground(palette.black)
                    :onClick(function() mode = m; setModeLabel() end)
                mx = mx + #m + 3
            end
            local gstatus = gp:addLabel():setText(""):setForeground(palette.lightGray):setPosition(1, 15)
            gp:addButton():setText(center("Save", 12)):setPosition(1, 14):setSize(12, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    local okHost = pcall(nyxlib.setHostname, hostInput:getText())
                    local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
                    cfg.uiMode = mode
                    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
                    gstatus:setText(okHost and "Saved. Boot mode applies at next reboot." or "Could not save the hostname.")
                end)

            ---------------- Account ----------------
            local ap = newPage()
            section(ap, 1, "Change password" .. (username and (" - " .. username) or ""), palette.orange)
            local oldInput = field(ap, 3, "Current password", "", true)
            local newInput = field(ap, 6, "New password (empty = none)", "", true)
            local confInput = field(ap, 9, "Confirm new password", "", true)
            local astatus = ap:addLabel():setText(""):setForeground(palette.lightGray):setPosition(1, 14)
            ap:addButton():setText(center("Change password", 20)):setPosition(1, 12):setSize(20, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    if not username then astatus:setText("No active session."); return end
                    local users = dofile("/lib/users.lua")
                    if not users.checkPassword(username, oldInput:getText()) then
                        astatus:setForeground(palette.red); astatus:setText("Current password is wrong."); return
                    end
                    local newPass = newInput:getText()
                    if newPass ~= confInput:getText() then
                        astatus:setForeground(palette.red); astatus:setText("The two passwords differ."); return
                    end
                    users.setPassword(username, newPass)
                    oldInput:setText(""); newInput:setText(""); confInput:setText("")
                    astatus:setForeground(palette.lime)
                    astatus:setText(newPass == "" and "Password removed." or "Password changed.")
                end)

            ---------------- Look ----------------
            local lp = newPage()
            section(lp, 1, "Accent colour", palette.magenta)
            local shown = math.min(#theme.presets, 5)
            local themeList = lp:addList():setPosition(1, 2):setSize(cw, shown)
                :setBackground(palette.gray):setForeground(palette.black)
                :setSelectedBackground(palette.white):setSelectedForeground(palette.black)
            for _, p in ipairs(theme.presets) do
                themeList:addItem({ text = "  " .. p.name, bg = p.accent, fg = palette.black,
                    selectedBg = p.accent, selectedFg = palette.white })
            end
            local chosen = nil
            themeList:onSelect(function(self, index) chosen = theme.presets[index] end)

            local bgOptions = {
                { "Black", "black" }, { "Gray", "gray" }, { "Blue", "blue" }, { "Green", "green" },
                { "Purple", "purple" }, { "Brown", "brown" },
            }
            local lrow = 2 + shown + 1
            section(lp, lrow, "Desktop background", palette.lightBlue)
            local bgChoice = config.desktopBg or "black"
            local bgLabel = lp:addLabel():setText("Current: " .. bgChoice):setForeground(palette.white):setPosition(1, lrow + 1)
            local bx, by2 = 1, lrow + 2
            for _, opt in ipairs(bgOptions) do
                local bw = #opt[1] + 2
                if bx + bw > cw then bx = 1; by2 = by2 + 1 end
                lp:addButton():setText(" " .. opt[1] .. " "):setPosition(bx, by2):setSize(bw, 1)
                    :setBackground(palette[opt[2]] or palette.gray)
                    :setForeground(opt[2] == "black" and palette.white or palette.black)
                    :onClick(function() bgChoice = opt[2]; bgLabel:setText("Current: " .. bgChoice) end)
                bx = bx + bw + 1
            end
            lp:addButton():setText(center("Apply", 10)):setPosition(1, by2 + 2):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    if chosen then theme.save({ name = chosen.name, accent = chosen.accent }) end
                    local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
                    cfg.desktopBg = bgChoice
                    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
                    request = { restart = true }
                    basalt.stop()
                end)

            ---------------- System ----------------
            local syp = newPage()
            section(syp, 1, "About", palette.yellow)
            local release = "NyxOS"
            if fs.exists("/etc/nyx-release") then
                local f = fs.open("/etc/nyx-release", "r")
                release = f.readLine() or release
                f.close()
            end
            local lines = {
                release,
                "Hostname : " .. nyxlib.getHostname(),
                "User     : " .. tostring(username or "-"),
                "Home     : " .. home,
                "HTTP     : " .. (http and "enabled" or "disabled"),
                "Boot UI  : " .. (config.uiMode or "shell"),
            }
            for i, line in ipairs(lines) do
                syp:addLabel():setText(line:sub(1, cw)):setForeground(palette.white):setPosition(1, 2 + i)
            end
            syp:addButton():setText(center("Task Manager", 16)):setPosition(1, 10):setSize(16, 1)
                :setBackground(palette.orange):setForeground(palette.black)
                :onClick(function() launchApp("Tasks") end)
            syp:addButton():setText(center("Packages", 12)):setPosition(19, 10):setSize(12, 1)
                :setBackground(palette.green):setForeground(palette.black)
                :onClick(function() launchApp("Packages") end)

            showPage(1)
        end)

        ------------------------------------------------------------
        -- Taskbar: page switcher + Start menu
        ------------------------------------------------------------
        pageLabel = taskbar:addLabel():setText(""):setForeground(palette.white):setPosition(w - 20, 1)
        pageLabel:onClick(function(self, btn, rx)
            if pages > 1 then
                if rx <= 3 then page = page - 1 else page = page + 1 end
                if page < 1 then page = pages end
                if page > pages then page = 1 end
                showDesktop()
            end
        end)

        local startMenu = nil
        startButton:onClick(function()
            if startMenu then
                startMenu:setVisible(not startMenu:getVisible())
                return
            end
            local entries = { { "Desktop", function() showDesktop() end } }
            for _, a in ipairs(apps) do
                table.insert(entries, { a.name, function() a.launch() end })
            end
            table.insert(entries, { "Exit to shell", function() runOnTerminal("shell") end })
            table.insert(entries, { "Reboot", function() runOnTerminal("reboot") end })
            table.insert(entries, { "Shutdown", function() runOnTerminal("shutdown") end })
            local mw, mh = 16, #entries
            local menu = main:addFrame():setSize(mw, mh):setPosition(1, h - mh):setBackground(palette.gray)
            for i, e in ipairs(entries) do
                local bg, fg = palette.gray, palette.white
                if i == 1 then bg, fg = accent, palette.black end
                if e[1] == "Reboot" then bg, fg = palette.orange, palette.black end
                if e[1] == "Shutdown" then bg, fg = palette.red, palette.white end
                menu:addButton():setText(" " .. e[1]):setPosition(1, i):setSize(mw, 1)
                    :setBackground(bg):setForeground(fg)
                    :onClick(function() menu:setVisible(false); e[2]() end)
            end
            startMenu = menu
        end)

        showDesktop()
        basalt.run()
    end)

    pcall(function() dofile("/lib/services.lua").unregisterPseudo("desktop") end)
    return ok, runErr, request
end

------------------------------------------------------------------
-- desktop.run(): runs the desktop, and re-runs it after programs that
-- were started from it (package launch, "Exit to shell"...).
------------------------------------------------------------------
function desktop.run()
    while true do
        local ok, err, request = runOnce()
        if not ok then
            print("Error while starting the desktop: " .. tostring(err))
            return false
        end
        if request and request.command then
            term.setBackgroundColor(palette.black)
            term.setTextColor(palette.white)
            term.clear()
            term.setCursorPos(1, 1)
            local okRun = pcall(shell.run, request.command)
            if request.command ~= "shell" and request.command ~= "reboot" and request.command ~= "shutdown" then
                print("")
                print("Press any key to return to the desktop...")
                os.pullEvent("key")
            end
            if not okRun then
                print("The program stopped with an error.")
                sleep(1)
            end
        elseif not (request and request.restart) then
            return true
        end
    end
end

return desktop
