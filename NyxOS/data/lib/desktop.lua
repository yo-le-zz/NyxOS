-- /lib/desktop.lua : NyxOS graphical desktop
--
-- A Basalt-based desktop environment: a taskbar (Start menu, running
-- app indicator, clock), desktop icons that launch full-area "apps"
-- (File Explorer, Terminal, Packages, Task Manager, Settings), and
-- power buttons (shutdown/reboot) in the Start menu.
--
-- Scope note: apps run one at a time, filling the content area below
-- the taskbar (switch back to the desktop, or to another app, via the
-- taskbar) -- there is no floating/draggable/overlapping window
-- manager yet. Icons are colour + glyph blocks rather than full pixel
-- art, since CC: Tweaked terminals are character-cell based.

local desktop = {}
local palette = colors or colours

local function loadBasalt()
    local nyxlib = dofile("/lib/nyxlib.lua")
    return nyxlib.loadBasalt()
end

-- Basalt's TextBox has no scrollTo(): its viewport is the `scrollY`
-- property (a 0-based line offset), so "scroll to the bottom" means
-- showing the last `height` lines.
local function scrollToBottom(box)
    pcall(function()
        local total = #box:getLines()
        box:setScrollY(math.max(0, total - box:getHeight()))
    end)
end

-- Runs a shell command and returns its captured text output (same
-- helper as the graphical shell: /lib/capture.lua).
local function captureCommand(cmd)
    local capture = dofile("/lib/capture.lua")
    return capture.run(cmd)
end

function desktop.run()
    local basalt = loadBasalt()
    if not basalt then
        print("Error: Basalt unavailable. Cannot start the desktop.")
        return false
    end

    local theme = dofile("/lib/theme.lua")
    local accent = theme.accent()
    local nyxlib = dofile("/lib/nyxlib.lua")

    pcall(function() dofile("/lib/services.lua").registerPseudo("desktop", "ui", "Graphical desktop (Basalt)") end)
    local ok, runErr = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()

        ------------------------------------------------------------
        -- Content area (icons, or the active app) + taskbar
        ------------------------------------------------------------
        local content = main:addFrame()
            :setPosition(1, 1)
            :setSize(w, h - 1)
            :setBackground(palette.black)

        local taskbar = main:addFrame()
            :setPosition(1, h)
            :setSize(w, 1)
            :setBackground(palette.gray)

        local startButton = taskbar:addButton()
            :setText(" Start ")
            :setPosition(1, 1)
            :setSize(8, 1)
            :setBackground(accent)
            :setForeground(palette.black)

        local activeLabel = taskbar:addLabel()
            :setText("Desktop")
            :setForeground(palette.white)
            :setPosition(10, 1)

        local clockLabel = taskbar:addLabel()
            :setText("")
            :setForeground(palette.white)
            :setPosition(w - 8, 1)

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
        -- App switching: each app clears `content` and rebuilds it.
        ------------------------------------------------------------
        local apps = {}
        local currentPanel = nil

        -- Rather than remove/destroy widgets (Basalt has no bulk
        -- "clear children" call), each screen (desktop icons or an
        -- app) gets its own fresh sub-frame that fully covers the
        -- content area; switching screens just hides the previous one
        -- and shows the new one.
        -- Basalt has no Frame:hide(): visibility is the `visible` property.
        -- Old panels are destroyed one launch later (never in the middle of
        -- the click that is replacing them) so they do not pile up.
        local graveyard = {}
        local function newPanel()
            for _, old in ipairs(graveyard) do
                pcall(function() old:destroy() end)
            end
            graveyard = {}
            if currentPanel then
                pcall(function() currentPanel:setVisible(false) end)
                table.insert(graveyard, currentPanel)
            end
            local panel = content:addFrame()
                :setPosition(1, 1)
                :setSize(w, h - 1)
                :setBackground(palette.black)
            currentPanel = panel
            return panel
        end

        local function showDesktopIcons()
            local area = newPanel()
            activeLabel:setText("Desktop")
            local x, y = 3, 2
            for _, app in ipairs(apps) do
                -- Rounded icon: a coloured 8x3 button whose four corner
                -- cells are drawn with teletext characters (128-159),
                -- each leaving only the inner corner pixel coloured.
                local iw = 8
                local icon = area:addButton()
                    :setText(app.glyph)
                    :setPosition(x, y)
                    :setSize(iw, 3)
                    :setBackground(app.color)
                    :setForeground(palette.black)
                icon:onClick(function() app.launch() end)
                local function corner(cx, cy, char, fg, bg)
                    area:addLabel()
                        :setText(char)
                        :setPosition(cx, cy)
                        :setSize(1, 1)
                        :setForeground(fg)
                        :setBackground(bg)
                        :onClick(function() app.launch() end)
                end
                corner(x, y, "\159", palette.black, app.color)
                corner(x + iw - 1, y, "\144", app.color, palette.black)
                corner(x, y + 2, "\130", app.color, palette.black)
                corner(x + iw - 1, y + 2, "\129", app.color, palette.black)
                area:addLabel()
                    :setText(app.name)
                    :setForeground(palette.white)
                    :setPosition(x + math.floor((iw - #app.name) / 2), y + 3)
                y = y + 5
                if y > h - 8 then
                    y = 2
                    x = x + 12
                end
            end
        end

        local function registerApp(name, glyph, color, builder)
            table.insert(apps, {
                name = name,
                glyph = glyph,
                color = color,
                launch = function()
                    local area = newPanel()
                    activeLabel:setText(name)
                    builder(area)
                end,
            })
        end

        ------------------------------------------------------------
        -- App: Back-to-desktop is always reachable via Start > Desktop,
        -- wired up after `apps` is populated below.
        ------------------------------------------------------------

        -- App: File Explorer (Windows-style: breadcrumb, list, up a
        -- level, new folder, delete/rename)
        registerApp("Files", " DIR ", palette.yellow, function(area)
            local currentDir = "/"

            local pathLabel = area:addLabel()
                :setText(currentDir)
                :setForeground(palette.white)
                :setPosition(2, 2)

            local list = area:addList()
                :setPosition(2, 3)
                :setSize(w - 4, h - 10)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)

            local status = area:addLabel()
                :setText("")
                :setForeground(palette.lightGray)
                :setPosition(2, h - 6)

            local entries = {}
            local selectedIndex = nil

            local function refresh()
                list:clear()
                entries = {}
                if currentDir ~= "/" then
                    table.insert(entries, { name = "..", dir = true })
                end
                local names = fs.list(currentDir)
                table.sort(names)
                for _, name in ipairs(names) do
                    local full = fs.combine(currentDir, name)
                    table.insert(entries, { name = name, dir = fs.isDir(full), full = full })
                end
                for _, e in ipairs(entries) do
                    list:addItem((e.dir and "[DIR] " or "      ") .. e.name)
                end
                pathLabel:setText(currentDir)
            end

            list:onSelect(function(self, index)
                selectedIndex = index
                local e = entries[index]
                if not e then return end
                if e.name == ".." then
                    currentDir = fs.getDir(currentDir)
                    if currentDir == "" then currentDir = "/" end
                    refresh()
                elseif e.dir then
                    currentDir = e.full
                    refresh()
                else
                    status:setText("Selected: " .. e.full .. " (" .. nyxlib.formatSize(fs.getSize(e.full)) .. ")")
                end
            end)

            area:addButton()
                :setText("New folder")
                :setPosition(2, h - 4)
                :setSize(14, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(function()
                    local name = "New Folder"
                    local n = 1
                    while fs.exists(fs.combine(currentDir, name)) do
                        n = n + 1
                        name = "New Folder " .. n
                    end
                    fs.makeDir(fs.combine(currentDir, name))
                    refresh()
                end)

            local pendingDelete = nil
            area:addButton()
                :setText("Delete")
                :setPosition(18, h - 4)
                :setSize(10, 1)
                :setBackground(palette.red)
                :setForeground(palette.white)
                :onClick(function()
                    local e = selectedIndex and entries[selectedIndex]
                    if not e or e.name == ".." then
                        status:setText("Select a file or folder first.")
                        return
                    end
                    -- Two clicks: the first one only asks for confirmation.
                    if pendingDelete ~= e.full then
                        pendingDelete = e.full
                        status:setText("Click Delete again to remove " .. e.full)
                        return
                    end
                    pendingDelete = nil
                    local okDel, errDel = pcall(fs.delete, e.full)
                    status:setText(okDel and ("Deleted " .. e.full) or ("Cannot delete: " .. tostring(errDel)))
                    selectedIndex = nil
                    refresh()
                end)

            refresh()
        end)

        -- App: Terminal -- the very same UI as the graphical shell
        -- (tabs, history, clear/exit, sudo prompts), just smaller.
        registerApp("Terminal", " >_ ", palette.cyan, function(area)
            local shellui = dofile("/lib/shellui.lua")
            shellui.mount(basalt, area, {
                header = false,
                onExit = function() showDesktopIcons() end,
            })
        end)

        -- App: Packages (apt front-end)
        registerApp("Packages", " PKG ", palette.green, function(area)
            local manifest = nyxlib.loadManifest()
            local names = {}
            for name in pairs(manifest) do table.insert(names, name) end
            table.sort(names)

            local list = area:addList()
                :setPosition(2, 2)
                :setSize(w - 4, h - 10)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)
            for _, name in ipairs(names) do
                local e = manifest[name]
                list:addItem(name .. " (v" .. tostring(e.version or "?") .. ")")
            end

            local output = area:addTextBox()
                :setPosition(2, h - 7)
                :setSize(w - 4, 4)
                :setEditable(false)
                :setBackground(palette.black)
                :setForeground(palette.white)

            local selected = nil
            list:onSelect(function(self, index) selected = names[index] end)

            local function runOn(cmd)
                if not selected then
                    output:setText("Select a package first.")
                    return
                end
                local out = captureCommand("apt " .. cmd .. " " .. selected)
                output:setText(out)
            end

            area:addButton():setText("Info"):setPosition(2, h - 2):setSize(8, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function() runOn("info") end)
            area:addButton():setText("Update"):setPosition(11, h - 2):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function() runOn("update") end)
            area:addButton():setText("Remove"):setPosition(22, h - 2):setSize(10, 1)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function() runOn("remove --yes") end)
        end)

        -- App: Task Manager (services + power)
        registerApp("Tasks", " TSK ", palette.orange, function(area)
            local servicesOk, services = pcall(dofile, "/lib/services.lua")
            local specs = dofile("/lib/specs.lua")
            local procui = dofile("/lib/procui.lua")
            local aw, ah = area:getWidth(), area:getHeight()

            -- Three pages: Processes / Specs / Power
            local pages = {}
            local function page()
                local f = area:addFrame():setPosition(1, 3):setSize(aw, ah - 2):setBackground(palette.black)
                f:setVisible(false)
                table.insert(pages, f)
                return f
            end
            local tabButtons = {}
            local function showPage(i)
                for j, f in ipairs(pages) do f:setVisible(j == i) end
                for j, b in ipairs(tabButtons) do
                    b:setBackground(j == i and accent or palette.gray)
                    b:setForeground(j == i and palette.black or palette.white)
                end
            end
            local tabNames = { "Processes", "Specs", "Power" }
            local tx = 2
            for i, name in ipairs(tabNames) do
                local b = area:addButton():setText(" " .. name .. " "):setPosition(tx, 2)
                    :setSize(#name + 2, 1)
                b:onClick(function() showPage(i) end)
                tabButtons[i] = b
                tx = tx + #name + 3
            end
            area:addLabel():setText("Task Manager"):setForeground(accent):setPosition(2, 1)

            ---------------- Processes ----------------
            local pp = page()
            local list = pp:addList()
                :setPosition(2, 1)
                :setSize(aw - 2, ah - 7)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)
            local info = pp:addLabel():setText(""):setForeground(palette.lightGray):setPosition(2, ah - 5)

            local rows = {}
            local selected = nil
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
                            user = "root", killable = false, description = def.description, stoppedService = true })
                    end
                end
                for _, p in ipairs(rows) do
                    list:addItem(string.format("%-4s %-13s %-8s %s",
                        p.pid > 0 and p.pid or "-", tostring(p.name):sub(1, 13), p.kind, p.state))
                end
            end
            refresh()

            list:onSelect(function(self, index)
                selected = rows[index]
                if selected then
                    info:setText(((selected.description or selected.cmd or "") .. ""):sub(1, aw - 4))
                end
            end)

            local function act(fn)
                if not selected then info:setText("Select a row first."); return end
                local ok, msg = pcall(fn, selected)
                info:setText(tostring(ok and msg or ("Error: " .. tostring(msg))):sub(1, aw - 4))
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
            local sp = page()
            local specBox = sp:addTextBox()
                :setPosition(2, 1):setSize(aw - 2, ah - 4)
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
            local pw = page()
            pw:addLabel():setText("Power"):setForeground(accent):setPosition(2, 2)
            pw:addButton():setText(" Reboot "):setPosition(2, 4):setSize(12, 3)
                :setBackground(palette.orange):setForeground(palette.black)
                :onClick(function() basalt.stop(); shell.run("reboot") end)
            pw:addButton():setText(" Shutdown "):setPosition(16, 4):setSize(14, 3)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function() basalt.stop(); shell.run("shutdown") end)

            showPage(1)
        end)

        -- App: Settings (theme + hostname)
        registerApp("Settings", " CFG ", palette.purple, function(area)
            area:addLabel():setText("Hostname:"):setForeground(palette.white):setPosition(2, 2)
            local hostInput = area:addInput()
                :setPosition(2, 3)
                :setSize(30, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setText(nyxlib.getHostname())

            area:addLabel():setText("Accent colour:"):setForeground(palette.white):setPosition(2, 5)
            local themeList = area:addList()
                :setPosition(2, 6)
                :setSize(30, math.min(#theme.presets, 6))
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)
            for _, p in ipairs(theme.presets) do
                themeList:addItem(p.name)
            end
            local chosen = theme.presets[1]
            themeList:onSelect(function(self, index) chosen = theme.presets[index] end)

            local status = area:addLabel():setText(""):setForeground(palette.lightGray):setPosition(2, h - 3)

            area:addButton():setText("Save"):setPosition(2, h - 2):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    nyxlib.setHostname(hostInput:getText())
                    theme.save({ name = chosen.name, accent = chosen.accent })
                    status:setText("Saved. Restart the desktop to see the new accent colour.")
                end)
        end)

        local startMenu = nil
        -- Start button: quick menu (desktop apps + Desktop + power)
        startButton:onClick(function()
            if startMenu then
                startMenu:setVisible(not startMenu:getVisible())
                return
            end
            local menu = main:addFrame()
                :setSize(16, #apps + 4)
                :setPosition(1, h - (#apps + 4))
                :setBackground(palette.gray)

            local y = 1
            menu:addButton()
                :setText("Desktop")
                :setPosition(1, y)
                :setSize(16, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(function() menu:setVisible(false); showDesktopIcons() end)
            y = y + 1

            for _, app in ipairs(apps) do
                menu:addButton()
                    :setText(app.name)
                    :setPosition(1, y)
                    :setSize(16, 1)
                    :setBackground(palette.gray)
                    :setForeground(palette.white)
                    :onClick(function() menu:setVisible(false); app.launch() end)
                y = y + 1
            end

            menu:addButton()
                :setText("Reboot")
                :setPosition(1, y)
                :setSize(16, 1)
                :setBackground(palette.orange)
                :setForeground(palette.black)
                :onClick(function() basalt.stop(); shell.run("reboot") end)
            y = y + 1

            menu:addButton()
                :setText("Shutdown")
                :setPosition(1, y)
                :setSize(16, 1)
                :setBackground(palette.red)
                :setForeground(palette.white)
                :onClick(function() basalt.stop(); shell.run("shutdown") end)

            startMenu = menu
        end)

        showDesktopIcons()
        basalt.run()
    end)

    if not ok then
        print("Error while starting the desktop: " .. tostring(runErr))
        return false
    end
    return true
end

return desktop
