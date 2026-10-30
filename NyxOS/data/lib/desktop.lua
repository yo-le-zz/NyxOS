-- /lib/desktop.lua : NyxOS graphical desktop
--
--   * icons you can move (drag, or click an icon then click where it goes),
--     launch (double click) and act on (a single click shows a small menu);
--     positions are saved in ~/.desktop-layout; several pages
--   * floating windows: title bar with Move / Hide / Full screen / Close,
--     overlapping, brought to front when clicked, listed in the taskbar
--   * the apps are modules in /lib/apps/<id>.lua (see ctx below) -- the
--     system ones (Files, Terminal, Packages, Tasks, Settings, Logs) and the
--     default ones (Calculator, Code Editor, Calendar, Clock, Notes)
--   * installed packages and the contents of ~/Desktop get icons too
--   * every error is written to the system log (/var/log/nyxos.log)
--
-- Programs started from the desktop that need the real terminal (a package's
-- launch command, reboot...) run there; the desktop comes back afterwards.

local desktop = {}
local palette = colors or colours

local function loadBasalt()
    local nyxlib = dofile("/lib/nyxlib.lua")
    return nyxlib.loadBasalt()
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

local function validName(value)
    value = trim(value or "")
    if value == "" or value:find("/", 1, true) then return nil end
    return value
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

local SYSTEM_ORDER = { "files", "terminal", "packages", "tasks", "settings", "logs" }

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
    local i18n = dofile("/lib/i18n.lua")
    i18n.load()
    local t = i18n.t
    local logger = dofile("/lib/logger.lua")
    local accent = theme.accent()
    local nyxlib = dofile("/lib/nyxlib.lua")
    local config = nyxlib.loadTable("/etc/nyx-config.lua")
    local desktopBg = colorByName(config.desktopBg, palette.black)
    local home, username = homeDir()
    local request = nil

    pcall(function() dofile("/lib/services.lua").registerPseudo("desktop", "ui", "Graphical desktop (Basalt)") end)
    logger.info("desktop", "desktop started (user " .. tostring(username) .. ")")

    local errorFlash = nil
    -- An error inside any handler no longer kills the desktop: it is
    -- written to the system log (with traceback) and the desktop goes on.
    if basalt.setErrorHandler then
        basalt.setErrorHandler(function(err)
            logger.crash("basalt", err)
            errorFlash = os.epoch("utc")
        end, true)
    end

    local ok, runErr = xpcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()

        local content = main:addFrame()
            :setPosition(1, 1):setSize(w, h - 1):setBackground(desktopBg)

        local taskbar = main:addFrame()
            :setPosition(1, h):setSize(w, 1):setBackground(palette.gray):setZ(800)

        local startButton = taskbar:addButton()
            :setText(" Start "):setPosition(1, 1):setSize(8, 1)
            :setBackground(accent):setForeground(palette.black)

        local clockLabel = taskbar:addLabel()
            :setText(""):setForeground(palette.white):setPosition(w - 8, 1):setSize(8, 1)
        local errorLabel = taskbar:addLabel()
            :setText(""):setForeground(palette.red):setPosition(w - 12, 1):setSize(3, 1)

        -- Storage watch: limits follow the real capacity (it may grow after the
        -- install); when space runs low, caches and temporary files are freed.
        basalt.schedule(function()
            local lastPressure = "ok"
            while true do
                local okR, res = pcall(dofile, "/lib/resources.lua")
                if okR then
                    local b = res.budget(true)
                    if b.pressure ~= "ok" then
                        local freed = res.cleanup(b.pressure == "critical")
                        logger.warn("resources", string.format("storage %s (%d bytes free): cleanup freed %d bytes",
                            b.pressure, res.free(), freed))
                        if b.pressure == "critical" and lastPressure ~= "critical" then
                            errorFlash = os.epoch("utc")
                        end
                    end
                    lastPressure = b.pressure
                end
                sleep(120)
            end
        end)

        -- Update notice (checked in the background, see /lib/updater.lua)
        local updateInfo = nil
        local updateButton = taskbar:addButton()
            :setText(" Update! "):setPosition(w - 30, 1):setSize(9, 1)
            :setBackground(palette.orange):setForeground(palette.black)
        updateButton:setVisible(false)
        updateButton:onClick(function()
            if not updateInfo then return end
            openDialog({ title = "Update", ok = "Yes", cancel = "No",
                text = t("NyxOS %s is available (you have %s). Install now?", updateInfo.latest, updateInfo.current),
                onOk = function() request = { command = "nyxupdate install" } basalt.stop() end })
        end)
        basalt.schedule(function()
            sleep(4)
            while true do
                local okU, updater = pcall(dofile, "/lib/updater.lua")
                if okU and http and updater.config().auto then
                    local okC, info = logger.try("updater", function() return updater.check(false) end)
                    if okC and type(info) == "table" and info.available then
                        updateInfo = info
                        pcall(function() updateButton:setVisible(true) end)
                    end
                end
                sleep(1800)
            end
        end)

        basalt.schedule(function()
            while true do
                clockLabel:setText(os.date("%H:%M:%S"))
                if errorFlash then
                    errorLabel:setText((os.epoch("utc") - errorFlash < 8000) and " ! " or "")
                end
                sleep(1)
            end
        end)

        ------------------------------------------------------------
        -- Frames are never destroyed in the middle of the click that
        -- replaces them: they are hidden at once and destroyed later.
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
        -- Dialogs (pop-ups) and context menus
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
            local dtitle, dtext = t(opts.title or ""), t(opts.text or "")
            local dw = math.min(w - 2, math.max(opts.third and 38 or 32, #dtext + 4))
            local dh = opts.input and 9 or 7
            local dx, dy = math.floor((w - dw) / 2) + 1, math.floor((h - dh) / 2)
            local d = main:addFrame()
                :setPosition(dx, math.max(1, dy)):setSize(dw, dh)
                :setBackground(palette.gray):setZ(900)
            currentDialog = d
            d:addLabel():setText(center(dtitle, dw))
                :setPosition(1, 1):setSize(dw, 1)
                :setBackground(accent):setForeground(palette.black)
            d:addLabel():setText(dtext:sub(1, dw - 2))
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
            d:addButton():setText(t(opts.ok or "OK")):setPosition(2, by):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(accept)
            if opts.cancel ~= false then
                d:addButton():setText(t(opts.cancel or "Cancel")):setPosition(14, by):setSize(10, 1)
                    :setBackground(palette.lightGray):setForeground(palette.black)
                    :onClick(function()
                        closeDialog()
                        if opts.onCancel then opts.onCancel() end
                    end)
            end
            if opts.third then
                d:addButton():setText(t(opts.third)):setPosition(26, by):setSize(10, 1)
                    :setBackground(palette.gray):setForeground(palette.white)
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

        -- entries = { { "Label", function } ... } at x, y
        local currentMenu = nil
        local function closeMenu()
            if currentMenu then retire(currentMenu); currentMenu = nil end
        end
        local function openMenu(x, y, entries)
            closeMenu()
            local mw = 4
            for _, e in ipairs(entries) do mw = math.max(mw, #t(e[1]) + 3) end
            local mh = #entries
            x = math.max(1, math.min(x, w - mw + 1))
            y = math.max(1, math.min(y, h - mh))
            local m = main:addFrame():setPosition(x, y):setSize(mw, mh):setBackground(palette.lightGray):setZ(850)
            currentMenu = m
            for i, e in ipairs(entries) do
                m:addButton():setText(" " .. t(e[1])):setPosition(1, i):setSize(mw, 1)
                    :setBackground(palette.lightGray):setForeground(palette.black)
                    :onClick(function()
                        closeMenu()
                        e[2]()
                    end)
            end
        end

        ------------------------------------------------------------
        -- Apps (modules in /lib/apps)
        ------------------------------------------------------------
        local appModules = {}   -- every module found
        local apps = {}         -- the enabled ones: { name, module }
        local showDesktop       -- forward declaration (icons)
        local launchApp, openWindow

        local function runOnTerminal(command)
            request = { command = command }
            basalt.stop()
        end
        local function restart()
            request = { restart = true }
            basalt.stop()
        end
        local function openTerminal(command) launchApp("Terminal", command) end

        ------------------------------------------------------------
        -- Windows
        ------------------------------------------------------------
        local windows = {}
        local zTop = 10
        local activeWin = nil
        local cascade = 0
        local drag = nil
        local carry = nil
        local lastTitleClick = { win = nil, at = 0 }
        local taskButtons = {}
        local MAX_TASK = 6

        local function refreshTaskbar()
            local first = 10
            local avail = w - 32 - first
            local n = math.min(#windows, MAX_TASK)
            local bw = n > 0 and math.max(5, math.min(14, math.floor(avail / n))) or 0
            for i = 1, MAX_TASK do
                local b = taskButtons[i]
                local win = windows[i]
                if win and i <= n then
                    local label = (" " .. win.title):sub(1, bw - 1)
                    local active = (win == activeWin and not win.minimized)
                    b:setText(label .. string.rep(" ", math.max(0, bw - 1 - #label)))
                        :setPosition(first + (i - 1) * bw, 1):setSize(bw - 1, 1)
                        :setBackground(active and accent or (win.minimized and palette.black or palette.lightGray))
                        :setForeground(active and palette.black or palette.white)
                    b:setVisible(true)
                else
                    b:setVisible(false)
                end
            end
        end

        local function paintBar(win)
            local active = (win == activeWin)
            pcall(function()
                win.bar:setBackground(active and accent or palette.lightGray)
                local bt = (" " .. win.title):sub(1, win.fw - 13)
                win.bar:setText(bt .. string.rep(" ", math.max(0, win.fw - 12 - #bt)))
            end)
        end

        local function focusWindow(win)
            if not win or win.closed then return end
            if win.minimized then
                win.minimized = false
                win.frame:setVisible(true)
            end
            zTop = zTop + 1
            if zTop > 700 then
                -- renumber to stay below the menus and dialogs
                zTop = 10
                for _, other in ipairs(windows) do
                    zTop = zTop + 1
                    other.frame:setZ(zTop)
                end
            end
            win.frame:setZ(zTop)
            local previous = activeWin
            activeWin = win
            if previous and previous ~= win then paintBar(previous) end
            paintBar(win)
            refreshTaskbar()
        end

        local function topWindowAt(x, y)
            local best
            for _, win in ipairs(windows) do
                if not win.minimized and not win.closed
                    and x >= win.x and x < win.x + win.fw and y >= win.y and y < win.y + win.fh then
                    if not best or win.frame.get("z") > best.frame.get("z") then best = win end
                end
            end
            return best
        end

        local function closeWindow(win, force)
            if not win or win.closed then return end
            -- an app may veto the close (unsaved work): its guard shows a
            -- dialog and returns true; it closes the window itself later
            if not force and win.guard then
                local okG, veto = pcall(win.guard)
                if okG and veto then
                    focusWindow(win)
                    return
                end
            end
            win.closed = true
            if win.onClose then pcall(win.onClose) end
            for _, fn in ipairs(win.closers or {}) do logger.try("close:" .. tostring(win.app.id), fn) end
            retire(win.frame)
            for i, other in ipairs(windows) do
                if other == win then table.remove(windows, i) break end
            end
            if activeWin == win then
                activeWin = nil
                local best
                for _, other in ipairs(windows) do
                    if not other.minimized and (not best or other.frame.get("z") > best.frame.get("z")) then best = other end
                end
                if best then focusWindow(best) end
            end
            logger.info("desktop", "closed window " .. tostring(win.app.name))
            refreshTaskbar()
        end

        local function minimizeWindow(win)
            if not win or win.closed then return end
            win.minimized = true
            win.frame:setVisible(false)
            if activeWin == win then
                activeWin = nil
                local best
                for _, other in ipairs(windows) do
                    if not other.minimized and (not best or other.frame.get("z") > best.frame.get("z")) then best = other end
                end
                if best then focusWindow(best) end
            end
            refreshTaskbar()
        end

        local function appSize(app, maximized)
            local maxBw, maxBh = w, h - 2
            if maximized then return maxBw, maxBh end
            local pref = app.size
            local bw = pref and pref[1] or math.min(w - 2, 70)
            local bh = pref and pref[2] or math.min(h - 4, 26)
            return math.max(20, math.min(bw, maxBw)), math.max(6, math.min(bh, maxBh))
        end

        function openWindow(app, arg, opts)
            opts = opts or {}
            if not app.multi and not opts.force then
                for _, win in ipairs(windows) do
                    if win.app == app then
                        focusWindow(win)
                        return win
                    end
                end
            end
            closeMenu()
            sweep()

            local bw, bh = appSize(app, opts.maximized)
            local fw, fh = bw, bh + 1
            local x, y = 1, 1
            if opts.maximized then
                x, y = 1, 1
            elseif opts.x then
                x, y = opts.x, opts.y
            else
                cascade = (cascade % 6) + 1
                x = math.max(1, math.min(w - fw + 1, 1 + (cascade - 1) * 2 + math.floor((w - fw) / 2) - 4))
                y = math.max(1, math.min((h - 1) - fh + 1, 1 + (cascade - 1)))
            end

            local frame = content:addFrame():setPosition(x, y):setSize(fw, fh)
                :setBackground(palette.gray):setZ(zTop + 1)
            local bar = frame:addButton():setText(""):setPosition(1, 1):setSize(fw - 12, 1)
                :setBackground(palette.lightGray):setForeground(palette.black)
            local body = frame:addFrame():setPosition(1, 2):setSize(bw, bh):setBackground(desktopBg)

            local win = {
                app = app, arg = arg, frame = frame, bar = bar, body = body,
                x = x, y = y, fw = fw, fh = fh, bw = bw, bh = bh,
                title = t(app.name), maximized = opts.maximized and true or false,
                minimized = false, closed = false,
            }
            table.insert(windows, win)

            local function titleButton(offset, text, bg, fg, fn)
                frame:addButton():setText(text):setPosition(fw - offset, 1):setSize(3, 1)
                    :setBackground(bg):setForeground(fg):onClick(fn)
            end
            titleButton(11, " + ", palette.cyan, palette.black, function()
                focusWindow(win)
                carry = win
            end)
            titleButton(8, " _ ", palette.yellow, palette.black, function() minimizeWindow(win) end)
            titleButton(5, win.maximized and " o " or " O ", palette.lime, palette.black, function()
                local saved = win.saver and win.saver() or nil
                local wasMax = win.maximized
                local ox, oy = win.x, win.y
                closeWindow(win, true)
                local newWin = openWindow(app, arg, {
                    maximized = not wasMax, force = true, restore = saved,
                    x = wasMax and (win.restoreX or ox) or nil, y = wasMax and (win.restoreY or oy) or nil,
                })
                if newWin and not wasMax then newWin.restoreX, newWin.restoreY = ox, oy end
            end)
            titleButton(2, " X ", palette.red, palette.white, function() closeWindow(win) end)

            bar:onClick(function(self, btn, rx)
                focusWindow(win)
                local now = os.epoch("utc")
                if lastTitleClick.win == win and now - lastTitleClick.at < 500 and not win.noMax then
                    lastTitleClick = { win = nil, at = 0 }
                    drag = nil
                    -- same as the Full screen button
                    local saved = win.saver and win.saver() or nil
                    local wasMax = win.maximized
                    local ox, oy = win.x, win.y
                    closeWindow(win, true)
                    local newWin = openWindow(app, arg, {
                        maximized = not wasMax, force = true, restore = saved,
                        x = wasMax and (win.restoreX or ox) or nil, y = wasMax and (win.restoreY or oy) or nil,
                    })
                    if newWin and not wasMax then newWin.restoreX, newWin.restoreY = ox, oy end
                    return
                end
                lastTitleClick = { win = win, at = now }
                drag = { kind = "win", win = win, grab = rx, moved = false }
            end)

            -- per-window API handed to the app
            local ctx
            ctx = setmetatable({
                win = win,
                setTitle = function(text)
                    win.title = tostring(text)
                    paintBar(win)
                    refreshTaskbar()
                end,
                closeWindow = function(force) closeWindow(win, force) end,
                setGuard = function(fn) win.guard = fn end,
                alive = function() return not win.closed end,
                isActive = function() return activeWin == win and not win.minimized end,
                visible = function() return not win.closed and not win.minimized end,
                restoreState = opts.restore,
                setSaver = function(fn) win.saver = fn end,
                onClose = function(fn) win.closers = win.closers or {} table.insert(win.closers, fn) end,
            }, { __index = desktop._base })

            focusWindow(win)
            logger.info("desktop", "opened " .. tostring(app.name))
            local okBuild, errBuild = logger.try("app:" .. tostring(app.id), function()
                app.build(body, ctx, arg)
            end)
            if not okBuild then
                closeWindow(win, true)
                message("Error", t("%s crashed. See the Logs app.", t(app.name)))
                return nil
            end
            return win
        end

        function launchApp(name, arg)
            for _, a in ipairs(apps) do
                if a.name == name or a.id == name then
                    return openWindow(a, arg)
                end
            end
            for _, a in ipairs(appModules) do
                if a.name == name then
                    message("Info", t("%s is disabled (Settings > Apps).", t(name)))
                    return nil
                end
            end
        end

        for i = 1, MAX_TASK do
            local b = taskbar:addButton():setText(""):setPosition(10, 1):setSize(6, 1)
            b:setVisible(false)
            b:onClick(function()
                local win = windows[i]
                if not win then return end
                if win.minimized then focusWindow(win)
                elseif win == activeWin then minimizeWindow(win)
                else focusWindow(win) end
            end)
            taskButtons[i] = b
        end

        -- Brings the clicked window to the front, and drops a window that
        -- is being carried ("+" button) where the next click lands.
        basalt.onEvent("mouse_click", function(btn, x, y)
            if carry then
                local win = carry
                carry = nil
                if not win.closed and not win.maximized then
                    local nx = math.max(1, math.min(w - 3, x - 1))
                    local ny = math.max(1, math.min(h - 2, y))
                    win.x, win.y = nx, ny
                    win.frame:setPosition(nx, ny)
                end
                return
            end
            if y >= 1 and y <= h - 1 then
                local win = topWindowAt(x, y)
                if win and win ~= activeWin then focusWindow(win) end
            end
        end)

        ------------------------------------------------------------
        -- Context for the apps (shared by all windows)
        ------------------------------------------------------------
        local function pickFile(opts, callback)
            closeDialog()
            sweep()
            local dw, dh = math.min(w - 4, 44), math.min(h - 3, 16)
            local d = main:addFrame():setPosition(math.floor((w - dw) / 2) + 1, math.floor((h - dh) / 2) + 1)
                :setSize(dw, dh):setBackground(palette.gray):setZ(900)
            currentDialog = d
            local dir = "/" .. fs.combine("", opts.dir or "/")
            if not fs.isDir(dir) then dir = "/" end
            d:addLabel():setText(center(t(opts.title or "Open"), dw)):setPosition(1, 1):setSize(dw, 1)
                :setBackground(accent):setForeground(palette.black)
            local pathLabel = d:addLabel():setText(""):setPosition(2, 2):setSize(dw - 2, 1)
                :setForeground(palette.lightGray)
            local save = opts.mode == "save"
            local dirMode = opts.mode == "dir"
            local list = d:addList():setPosition(2, 3):setSize(dw - 2, dh - (save and 7 or 5))
                :setBackground(palette.black):setForeground(palette.white)
                :setSelectedBackground(accent):setSelectedForeground(palette.black)
            local nameInput
            if save then
                nameInput = d:addInput():setPosition(2, dh - 3):setSize(dw - 2, 1)
                    :setBackground(palette.black):setForeground(palette.white):setText(opts.name or "")
            end
            local entries = {}
            local lastPick = { index = nil, at = 0 }
            local function choose(path)
                closeDialog()
                callback(path)
            end
            local function refresh()
                list:clear()
                entries = {}
                pathLabel:setText(dir:sub(1, dw - 2))
                if dir ~= "/" then entries[#entries + 1] = { name = "..", dir = true } end
                local names = fs.list(dir)
                table.sort(names, function(a, b)
                    local da, db = fs.isDir(fs.combine(dir, a)), fs.isDir(fs.combine(dir, b))
                    if da ~= db then return da end
                    return a:lower() < b:lower()
                end)
                for _, name in ipairs(names) do
                    entries[#entries + 1] = { name = name, dir = fs.isDir(fs.combine(dir, name)) }
                end
                for _, e in ipairs(entries) do
                    list:addItem({ text = (e.dir and " [DIR] " or "       ") .. e.name,
                        fg = e.dir and palette.yellow or palette.white, selectedFg = palette.black })
                end
            end
            local function openEntry(e)
                if e.name == ".." then
                    local parent = fs.getDir(dir)
                    dir = (parent == "" or parent == "..") and "/" or ("/" .. parent)
                    refresh()
                elseif e.dir then
                    dir = "/" .. fs.combine(dir, e.name)
                    refresh()
                elseif dirMode then
                    -- files are only shown
                elseif save then
                    nameInput:setText(e.name)
                else
                    choose("/" .. fs.combine(dir, e.name))
                end
            end
            list:onSelect(function(self, index)
                local e = entries[index]
                if not e then return end
                local now = os.epoch("utc")
                if lastPick.index == index and now - lastPick.at < 700 then
                    lastPick = { index = nil, at = 0 }
                    openEntry(e)
                    return
                end
                lastPick = { index = index, at = now, entry = e }
                if save and not e.dir then nameInput:setText(e.name) end
            end)
            local by = dh - 1
            d:addButton():setText(t(save and "Save" or (dirMode and "Select" or "Open"))):setPosition(2, by):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    if dirMode then
                        choose(dir)
                    elseif save then
                        local name = trim(nameInput:getText() or "")
                        if name == "" or name:find("/", 1, true) then return end
                        choose("/" .. fs.combine(dir, name))
                    elseif lastPick.entry then
                        openEntry(lastPick.entry)
                    end
                end)
            d:addButton():setText(t("Cancel")):setPosition(14, by):setSize(10, 1)
                :setBackground(palette.lightGray):setForeground(palette.black):onClick(closeDialog)
            refresh()
        end

        desktop._base = {
            basalt = basalt, palette = palette, accent = accent, bg = desktopBg,
            t = t, home = home, username = username, config = config,
            center = center, trim = trim, validName = validName,
            dialog = openDialog, message = message, confirm = confirm,
            pickFile = pickFile, openTerminal = openTerminal, runOnTerminal = runOnTerminal,
            launch = launchApp, restart = restart,
            windows = function() return windows end,
            closeWin = function(win) closeWindow(win) end,
            focusWin = function(win) focusWindow(win) end,
            appModules = appModules,
            try = function(tag, fn, ...) return logger.try(tag, fn, ...) end,
            log = function(level, text) pcall(logger.log, "app", level, tostring(text)) end,
            safe = function(tag, fn, ...) return logger.pcall(tag, fn, ...) end,
            -- gives the focus to `element` once the click that opened the
            -- app has been fully dispatched (Basalt focuses the clicked
            -- element last, which would steal it back)
            focus = function(element)
                basalt.schedule(function()
                    sleep(0.05)
                    pcall(function() element:setFocused(true) end)
                end)
            end,
        }

        -- load the modules
        if fs.exists("/lib/apps") and fs.isDir("/lib/apps") then
            local files = fs.list("/lib/apps")
            table.sort(files)
            for _, file in ipairs(files) do
                if file:match("%.lua$") then
                    local okMod, mod = logger.try("desktop", dofile, "/lib/apps/" .. file)
                    if okMod and type(mod) == "table" and mod.id and mod.build then
                        table.insert(appModules, mod)
                    end
                end
            end
        end
        table.sort(appModules, function(a, b)
            local ia, ib = 99, 99
            for i, id in ipairs(SYSTEM_ORDER) do
                if id == a.id then ia = i end
                if id == b.id then ib = i end
            end
            if ia ~= ib then return ia < ib end
            return a.id < b.id
        end)
        for _, mod in ipairs(appModules) do
            local on = mod.system or type(config.apps) ~= "table" or config.apps[mod.id] ~= false
            if on then table.insert(apps, mod) end
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
        local pageLabel
        local currentItems = {}
        local desktopPanel

        local function saveLayout()
            if fs.exists(home) then logger.pcall("desktop", nyxlib.saveTable, layoutPath, layout) end
        end

        local function cellX(col) return (col - 1) * GW + 2 end
        local function cellY(row) return (row - 1) * GH + 2 end

        -- Everything that gets an icon
        local function collectItems()
            local items = {}
            for _, a in ipairs(apps) do
                table.insert(items, {
                    id = "app:" .. a.name, name = a.name, label = t(a.name), icon = a.icon,
                    open = function() launchApp(a.name) end, kind = "app",
                })
            end
            local manifest = nyxlib.loadManifest()
            local names = {}
            for name, entry in pairs(manifest) do
                if not entry.removed and (nyxlib.launcherFor(name, entry) or entry.service) then
                    table.insert(names, name)
                end
            end
            table.sort(names)
            for _, name in ipairs(names) do
                local entry = manifest[name]
                local cmd = nyxlib.launcherFor(name, entry)
                table.insert(items, {
                    id = "pkg:" .. name, name = name, kind = "pkg", package = name,
                    icon = (iconlib.isPixel(entry.icon) and entry.icon) or iconlib.load(name)
                        or (type(entry.icon) == "table" and (entry.icon.color or entry.icon.art) and entry.icon)
                        or iconlib.builtin.package,
                    open = function()
                        if cmd then runOnTerminal(cmd) else openTerminal("service start " .. tostring(entry.service)) end
                    end,
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
                                    launchApp("Code Editor", full)
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

        local function deleteItem(it)
            if it.kind == "fs" then
                confirm("Delete", t("Delete %s ?", it.name), function()
                    local okDel, errDel = pcall(fs.delete, it.path)
                    if not okDel then message("Error", tostring(errDel)) end
                    showDesktop()
                end)
            elseif it.kind == "pkg" then
                confirm("Uninstall", t("Uninstall %s ?", it.package), function()
                    openTerminal("apt remove " .. it.package)
                end)
            else
                message("Info", t("%s is a system app.", it.name))
            end
        end

        local function renameItem(it)
            if it.kind ~= "fs" then
                message("Info", "Only desktop files can be renamed.")
                return
            end
            openDialog({ title = "Rename", text = t("New name for %s", it.name), input = it.name,
                onOk = function(value)
                    value = validName(value)
                    if not value then message("Error", "Invalid name.") return end
                    local dest = fs.combine(fs.getDir(it.path), value)
                    if fs.exists(dest) then message("Error", t("%s already exists.", value)) return end
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
                    if not fs.exists(deskDir) then logger.pcall("desktop", fs.makeDir, deskDir) end
                    local dest = fs.combine(deskDir, value)
                    if fs.exists(dest) then message("Error", t("%s already exists.", value)) return end
                    if isDir then
                        logger.pcall("desktop", fs.makeDir, dest)
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

        -- Wallpaper (see /lib/wallpaper.lua): when one is set the icons are
        -- transparent images drawn over it, otherwise plain frames.
        local wpGen = 0
        local wpOn = false

        local function iconBimg(it, sel)
            local rows = iconlib.build(it.icon, "transparent")
            local out = {}
            for r = 1, 3 do
                local row = rows[r]
                out[r] = { " " .. row[1] .. " ", "0" .. row[2] .. "0", "t" .. row[3] .. "t" }
            end
            local name = center(it.label or it.name, 10)
            local fgs, bgs = {}, {}
            local acc = colors.toBlit(accent)
            for i = 1, 10 do
                local blank = name:sub(i, i) == " "
                fgs[i] = sel and "f" or "0"
                bgs[i] = blank and "t" or (sel and acc or "f")
            end
            out[4] = { name, table.concat(fgs), table.concat(bgs) }
            return { out }
        end

        -- One icon = a frame: pixel image (see /lib/icon.lua) + name
        local function buildIcon(panel, it, x, y)
            if wpOn then
                local img = panel:addImage():setPosition(x, y):setSize(10, 4):setZ(10)
                img:setTransparent(true)
                img:setBimg(iconBimg(it, false))
                it.frame, it.transImg = img, true
                return img
            end
            local f = panel:addFrame():setPosition(x, y):setSize(10, 4):setBackground(desktopBg)
            it.frame = f
            local rows = iconlib.build(it.icon, config.desktopBg or "black")
            f:addImage():setPosition(2, 1):setSize(8, 3):setBimg({ rows })
            it.nameLabel = f:addLabel():setText(center(it.label or it.name, 10)):setPosition(1, 4)
                :setSize(10, 1):setBackground(desktopBg):setForeground(palette.white)
            return f
        end

        local function highlight()
            for _, it in ipairs(currentItems) do
                if it.transImg then
                    local sel = (it.id == selectedId)
                    pcall(function() it.frame:setBimg(iconBimg(it, sel)) end)
                elseif it.nameLabel then
                    local sel = (it.id == selectedId)
                    pcall(function()
                        it.nameLabel:setBackground(sel and accent or desktopBg)
                        it.nameLabel:setForeground(sel and palette.black or palette.white)
                    end)
                end
            end
        end

        -- Puts item `it` in the grid cell (col, row) of the current page
        -- (swapping with whatever is there), saves and redraws.
        local function placeItem(it, col, row)
            col = math.max(1, math.min(COLS, col))
            row = math.max(1, math.min(ROWS, row))
            local target
            for _, other in ipairs(currentItems) do
                if other ~= it and other.pos.page == page and other.pos.col == col and other.pos.row == row then
                    target = other
                end
            end
            local old = { page = it.pos.page, col = it.pos.col, row = it.pos.row }
            if target then layout[target.id] = old end
            layout[it.id] = { page = page, col = col, row = row }
            saveLayout()
            showDesktop()
        end

        function showDesktop()
            closeMenu()
            sweep()
            if desktopPanel then retire(desktopPanel) end
            local panel = content:addFrame()
                :setPosition(1, 1):setSize(w, h - 1):setBackground(desktopBg):setZ(1)
            desktopPanel = panel
            wpGen = wpGen + 1
            wpOn = false
            local wpId = config.wallpaper
            if type(wpId) == "string" and wpId ~= "none" then
                local okW, wallp = pcall(dofile, "/lib/wallpaper.lua")
                local okO, obj = false, nil
                if okW then
                    okO, obj = pcall(wallp.new, wpId, w, h - 1, { path = config.wallpaperImage })
                end
                if okO and obj then
                    wpOn = true
                    local img = panel:addImage():setPosition(1, 1):setSize(w, h - 1):setZ(1)
                    img:setBimg({ obj.frame(0) })
                    local gen = wpGen
                    if obj.animated and config.wallpaperAnimate ~= false then
                        basalt.schedule(function()
                            local n = 0
                            while gen == wpGen do
                                sleep(obj.delay or 0.2)
                                if gen ~= wpGen then return end
                                n = n + 1
                                local okF, fr = pcall(obj.frame, n)
                                if okF then pcall(function() img:setBimg({ fr }) end) end
                            end
                        end)
                    end
                end
            end
            drag = (drag and drag.kind == "win") and drag or nil
            currentItems = collectItems()
            assignCells(currentItems)
            if page > pages then page = pages end
            updatePageLabel()

            for _, it in ipairs(currentItems) do
                if it.pos.page == page then
                    local f = buildIcon(panel, it, cellX(it.pos.col), cellY(it.pos.row))
                    f:onClick(function(self, btn, rx, ry)
                        closeMenu()
                        if btn == 2 then
                            selectedId = it.id
                            highlight()
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
                        selectedId = it.id
                        highlight()
                        drag = { kind = "icon", item = it, offx = rx, offy = ry, moved = false }
                        -- a single click also shows the icon's menu
                        local mx = f:getX() + 10
                        if mx + 12 > w then mx = math.max(1, f:getX() - 12) end
                        iconMenu(it, mx, f:getY())
                    end)
                end
            end

            panel:onClick(function(self, btn, rx, ry)
                closeMenu()
                if btn == 2 then
                    selectedId = nil
                    highlight()
                    openMenu(rx, ry, {
                        { "New folder", function() newDesktopEntry(true) end },
                        { "New file", function() newDesktopEntry(false) end },
                        { "Refresh", function() showDesktop() end },
                    })
                    return
                end
                -- click an icon, then click an empty spot: the icon goes there
                if selectedId then
                    for _, it in ipairs(currentItems) do
                        if it.id == selectedId and it.pos.page == page then
                            local col = math.floor((rx - 2) / GW) + 1
                            local row = math.floor((ry - 2) / GH) + 1
                            selectedId = nil
                            placeItem(it, col, row)
                            return
                        end
                    end
                    selectedId = nil
                    highlight()
                end
            end)
            highlight()
        end

        -- Drag & drop (icons and windows) is tracked with the global event hook:
        -- widgets under the pointer (lists, text boxes...) swallow drag events,
        -- the hook sees them all.
        basalt.onEvent("mouse_drag", function(btn, x, y)
            if not drag then return end
            if drag.kind == "win" then
                local win = drag.win
                if win.closed or win.maximized then return end
                local nx = math.max(1 - (win.fw - 6), math.min(w - 3, x - drag.grab + 1))
                local ny = math.max(1, math.min(h - 2, y))
                if nx ~= win.x or ny ~= win.y then
                    drag.moved = true
                    win.x, win.y = nx, ny
                    win.frame:setPosition(nx, ny)
                end
            elseif drag.kind == "icon" then
                local f = drag.item.frame
                local nx = math.max(1, math.min(w - 9, x - drag.offx + 1))
                local ny = math.max(1, math.min(h - 4, y - drag.offy + 1))
                if nx ~= f:getX() or ny ~= f:getY() then
                    if not drag.moved then closeMenu() end
                    drag.moved = true
                    f:setPosition(nx, ny)
                end
            end
        end)
        basalt.onEvent("mouse_up", function(btn, x, y)
            if not drag then return end
            local d = drag
            drag = nil
            if d.kind ~= "icon" or not d.moved then return end
            local f = d.item.frame
            -- nearest grid cell to the icon's centre
            local col = math.floor((f:getX() + 4 - 2) / GW + 1.5)
            local row = math.floor((f:getY() + 1 - 2) / GH + 1.5)
            selectedId = nil
            placeItem(d.item, col, row)
        end)

        ------------------------------------------------------------
        -- Taskbar: page switcher + Start menu
        ------------------------------------------------------------
        pageLabel = taskbar:addLabel():setText(""):setForeground(palette.white):setPosition(w - 20, 1):setSize(8, 1)
        pageLabel:onClick(function(self, btn, rx)
            if pages > 1 then
                if rx <= 3 then page = page - 1 else page = page + 1 end
                if page < 1 then page = pages end
                if page > pages then page = 1 end
                showDesktop()
            end
        end)

        local startMenu = nil
        local function closeStart()
            if startMenu then retire(startMenu); startMenu = nil end
        end
        startButton:onClick(function()
            if startMenu then closeStart() return end
            closeMenu()
            local entries = { { "Desktop", function() showDesktop() end } }
            for _, a in ipairs(apps) do
                table.insert(entries, { a.name, function() launchApp(a.name) end })
            end
            table.insert(entries, { "New folder", function() newDesktopEntry(true) end })
            table.insert(entries, { "Exit to shell", function() runOnTerminal("shell") end })
            table.insert(entries, { "Reboot", function() runOnTerminal("reboot") end })
            table.insert(entries, { "Shutdown", function() runOnTerminal("shutdown") end })
            local colW = 18
            local maxRows = math.max(3, h - 2)
            local ncols = math.max(1, math.ceil(#entries / maxRows))
            local mh = math.ceil(#entries / ncols)
            local mw = colW * ncols
            local menu = main:addFrame():setSize(mw, mh):setPosition(1, h - mh):setBackground(palette.gray):setZ(950)
            menu.menuW, menu.menuH = mw, mh
            for i = 1, #entries do
                local e = entries[i]
                local col, row = math.floor((i - 1) / mh), (i - 1) % mh + 1
                local bg, fg = palette.gray, palette.white
                if i == 1 then bg, fg = accent, palette.black end
                if e[1] == "Reboot" then bg, fg = palette.orange, palette.black end
                if e[1] == "Shutdown" then bg, fg = palette.red, palette.white end
                menu:addButton():setText(" " .. t(e[1])):setPosition(col * colW + 1, row):setSize(colW, 1)
                    :setBackground(bg):setForeground(fg)
                    :onClick(function() closeStart(); e[2]() end)
            end
            startMenu = menu
        end)

        -- clicking anywhere else closes the Start menu
        basalt.onEvent("mouse_click", function(btn, x, y)
            if startMenu and not (y >= h - startMenu.menuH and x <= startMenu.menuW) and y < h then
                closeStart()
            end
        end)

        showDesktop()
        basalt.run()
    end, function(e)
        if debug and debug.traceback then return debug.traceback(tostring(e), 2) end
        return tostring(e)
    end)

    if not ok then logger.crash("desktop", runErr) end
    logger.info("desktop", "desktop stopped")
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
            print("Details: logs -e")
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
