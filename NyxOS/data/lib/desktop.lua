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

-- Runs a shell command and returns its captured text output (same
-- trick used by the graphical shell in /lib/shellui.lua).
local function captureCommand(cmd)
    local oldRedirect = term.redirect
    local output = {}
    term.redirect({
        write = function(text) table.insert(output, text) end,
        blit = function(text) table.insert(output, text) end,
        clear = function() output = {} end,
        clearLine = function() end,
        getCursorPos = function() return 1, 1 end,
        setCursorPos = function() end,
        getCursorBlink = function() return false end,
        setCursorBlink = function() end,
        getSize = function() return 51, 19 end,
        scroll = function() end,
        getTextColor = function() return palette.white end,
        setTextColor = function() end,
        getBackgroundColor = function() return palette.black end,
        setBackgroundColor = function() end,
    })
    local ok, err = pcall(shell.run, cmd)
    term.redirect(oldRedirect)
    return table.concat(output), (not ok) and err or nil
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

    local ok = pcall(function()
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
        local function newPanel()
            if currentPanel then
                currentPanel:hide()
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
            local x, y = 2, 2
            for _, app in ipairs(apps) do
                local icon = area:addButton()
                    :setText(app.glyph)
                    :setPosition(x, y)
                    :setSize(6, 3)
                    :setBackground(app.color)
                    :setForeground(palette.black)
                icon:onClick(function() app.launch() end)
                area:addLabel()
                    :setText(app.name)
                    :setForeground(palette.white)
                    :setPosition(x, y + 3)
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
        registerApp("Files", "[#]", palette.yellow, function(area)
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
                list:clearItems()
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
                    fs.delete(e.full)
                    status:setText("Deleted " .. e.full)
                    selectedIndex = nil
                    refresh()
                end)

            refresh()
        end)

        -- App: Terminal (single embedded terminal, same execution model
        -- as the standalone graphical shell)
        registerApp("Terminal", ">_", palette.black, function(area)
            local outputBox = area:addTextBox()
                :setPosition(2, 2)
                :setSize(w - 3, h - 5)
                :setBackground(palette.black)
                :setForeground(palette.white)

            local cmdInput = area:addInput()
                :setPosition(2, h - 2)
                :setSize(w - 14, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setPlaceholder("Type a command...")

            local text = "NyxOS Terminal\n\n"
            outputBox:setText(text)

            local function run(cmd)
                if not cmd or cmd == "" then return end
                text = text .. "$ " .. cmd .. "\n"
                local out, err = captureCommand(cmd)
                if out and out ~= "" then text = text .. out .. "\n" end
                if err then text = text .. "Error: " .. tostring(err) .. "\n" end
                text = text .. "\n"
                outputBox:setText(text)
                outputBox:scrollTo("bottom")
                cmdInput:setText("")
            end

            cmdInput:onKey(function(self, key)
                if key == keys.enter or key == keys.numPadEnter then
                    run(cmdInput:getText())
                end
            end)

            area:addButton()
                :setText("Run")
                :setPosition(w - 10, h - 2)
                :setSize(6, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(function() run(cmdInput:getText()) end)

            cmdInput:setFocused(true)
        end)

        -- App: Packages (apt front-end)
        registerApp("Packages", "[+]", palette.green, function(area)
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
        registerApp("Tasks", "[T]", palette.orange, function(area)
            local servicesOk, services = pcall(dofile, "/lib/services.lua")

            local list = area:addList()
                :setPosition(2, 2)
                :setSize(w - 4, h - 12)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)

            local names = {}
            local function refresh()
                list:clearItems()
                names = {}
                if servicesOk and services then
                    for _, def in ipairs(services.list()) do
                        local st = services.status(def.name)
                        table.insert(names, def.name)
                        list:addItem(def.name .. " -- " .. st.state .. (def.autostart and " [enabled]" or ""))
                    end
                end
            end
            refresh()

            local selected = nil
            list:onSelect(function(self, index) selected = names[index] end)

            area:addButton():setText("Enable"):setPosition(2, h - 8):setSize(10, 1)
                :setBackground(accent):setForeground(palette.black)
                :onClick(function()
                    if selected then services.setAutostart(selected, true); refresh() end
                end)
            area:addButton():setText("Disable"):setPosition(13, h - 8):setSize(10, 1)
                :setBackground(palette.gray):setForeground(palette.white)
                :onClick(function()
                    if selected then services.setAutostart(selected, false); refresh() end
                end)

            area:addLabel():setText("Power:"):setForeground(palette.white):setPosition(2, h - 5)
            area:addButton():setText("Reboot"):setPosition(2, h - 4):setSize(10, 1)
                :setBackground(palette.orange):setForeground(palette.black)
                :onClick(function()
                    basalt.stop()
                    shell.run("reboot")
                end)
            area:addButton():setText("Shutdown"):setPosition(13, h - 4):setSize(11, 1)
                :setBackground(palette.red):setForeground(palette.white)
                :onClick(function()
                    basalt.stop()
                    shell.run("shutdown")
                end)
        end)

        -- App: Settings (theme + hostname)
        registerApp("Settings", "[*]", palette.purple, function(area)
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

        -- Start button: quick menu (desktop apps + Desktop + power)
        startButton:onClick(function()
            local menu = basalt.createFrame()
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
                :onClick(function() menu:hide(); showDesktopIcons() end)
            y = y + 1

            for _, app in ipairs(apps) do
                menu:addButton()
                    :setText(app.name)
                    :setPosition(1, y)
                    :setSize(16, 1)
                    :setBackground(palette.gray)
                    :setForeground(palette.white)
                    :onClick(function() menu:hide(); app.launch() end)
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

            menu:show()
        end)

        showDesktopIcons()
        basalt.run()
    end)

    if not ok then
        print("Error while starting the desktop.")
        return false
    end
    return true
end

return desktop
