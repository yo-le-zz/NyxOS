-- /lib/shellui.lua : NyxOS graphical shell, built with Basalt
--
-- Full shell interface with:
-- - Scrollable output area per command
-- - Input field for typing commands
-- - Touch/click support on screen (via /lib/monitorbridge.lua)
-- - Command history (up/down)
-- - Several independent terminal tabs (a "+" button opens a new one)
-- - Execution via shell.run()

local shellui = {}
local palette = colors or colours

local function loadBasalt()
    local nyxlib = dofile("/lib/nyxlib.lua")
    return nyxlib.loadBasalt()
end

-- Captures a command's output and returns it as a string
local function captureCommand(cmd)
    local oldRedirect = term.redirect
    local output = {}

    term.redirect({
        write = function(text)
            table.insert(output, text)
        end,
        blit = function(text, fg, bg)
            table.insert(output, text)
        end,
        clear = function()
            output = {}
        end,
        clearLine = function()
            -- Ignore
        end,
        getCursorPos = function()
            return 1, 1
        end,
        setCursorPos = function(x, y)
            -- Ignore
        end,
        getCursorBlink = function()
            return false
        end,
        setCursorBlink = function(b)
            -- Ignore
        end,
        getSize = function()
            return 51, 19
        end,
        scroll = function(n)
            -- Ignore
        end,
        getTextColor = function()
            return palette.white
        end,
        setTextColor = function(c)
            -- Ignore
        end,
        getBackgroundColor = function()
            return palette.black
        end,
        setBackgroundColor = function(c)
            -- Ignore
        end,
    })

    local ok, err = pcall(shell.run, cmd)

    term.redirect(oldRedirect)

    return table.concat(output), (not ok) and err or nil
end

-- Main graphical shell
function shellui.run()
    local basalt = loadBasalt()
    if not basalt then
        print("Error: Basalt unavailable. Cannot start the graphical shell.")
        return false
    end

    local theme = dofile("/lib/theme.lua")
    local accent = theme.accent()
    local nyxlib = dofile("/lib/nyxlib.lua")
    local permissionsOk, permissions = pcall(dofile, "/lib/permissions.lua")

    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()

        local session = nyxlib.loadSession()
        local currentUser = session.username or "guest"

        -- Header with hostname, user, clock
        local header = main:addFrame()
            :setPosition(1, 1)
            :setSize(w, 1)
            :setBackground(accent)

        header:addLabel()
            :setText("NyxOS -- " .. nyxlib.getHostname())
            :setForeground(palette.black)
            :setPosition(2, 1)

        local userLabel = header:addLabel()
            :setText(currentUser .. "@nyxos")
            :setForeground(palette.black)
            :setPosition(math.max(2, w - #currentUser - 8), 1)

        -- Tab bar (multiple independent terminals within the window)
        local tabBar = main:addFrame()
            :setPosition(1, 2)
            :setSize(w, 1)
            :setBackground(palette.gray)

        -- Output area (scrollable)
        local outputBox = main:addTextBox()
            :setPosition(2, 4)
            :setSize(w - 3, h - 5)
            :setBackground(palette.black)
            :setForeground(palette.white)

        -- Command input field
        local inputLabel = main:addLabel()
            :setText("$")
            :setForeground(accent)
            :setPosition(2, h - 1)

        local cmdInput = main:addInput()
            :setPosition(4, h - 1)
            :setSize(w - 15, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setPlaceholder("Type a command...")

        ------------------------------------------------------------
        -- Multiple terminal tabs: each tab keeps its own output text
        -- and command history, so switching tabs feels like switching
        -- between independent terminal windows.
        ------------------------------------------------------------
        local tabs = {}
        local activeTab = nil
        local tabButtons = {}

        local function motdText()
            if fs.exists("/etc/motd") then
                local f = fs.open("/etc/motd", "r")
                local motd = f.readAll()
                f.close()
                if motd ~= "" then
                    return motd .. "\n\n"
                end
            end
            return "NyxOS Graphical Shell v1.0.1\nType 'help' for the command list, or 'man' for the manual.\n\n"
        end

        local function redrawTabBar()
            for _, btn in ipairs(tabButtons) do
                pcall(btn.destroy, btn)
            end
            tabButtons = {}
            local x = 1
            for i, tab in ipairs(tabs) do
                local label = "Term " .. i
                local btn = tabBar:addButton()
                    :setText(label)
                    :setPosition(x, 1)
                    :setSize(#label + 2, 1)
                    :setBackground(tab == activeTab and accent or palette.gray)
                    :setForeground(tab == activeTab and palette.black or palette.white)
                btn:onClick(function()
                    activeTab = tab
                    outputBox:setText(tab.output)
                    outputBox:scrollTo("bottom")
                    redrawTabBar()
                end)
                table.insert(tabButtons, btn)
                x = x + #label + 3
            end
            local plusBtn = tabBar:addButton()
                :setText("+")
                :setPosition(x, 1)
                :setSize(3, 1)
                :setBackground(palette.darkGray)
                :setForeground(palette.white)
            plusBtn:onClick(function()
                local newTab = { output = motdText(), history = {}, historyIndex = 1 }
                table.insert(tabs, newTab)
                activeTab = newTab
                outputBox:setText(newTab.output)
                redrawTabBar()
            end)
            table.insert(tabButtons, plusBtn)
        end

        local firstTab = { output = motdText(), history = {}, historyIndex = 1 }
        table.insert(tabs, firstTab)
        activeTab = firstTab
        outputBox:setText(firstTab.output)
        redrawTabBar()

        -- Runs a command in the active tab
        local function executeCommand(cmd)
            if cmd == nil or cmd == "" then
                return
            end
            local tab = activeTab

            table.insert(tab.history, cmd)
            tab.historyIndex = #tab.history + 1

            tab.output = tab.output .. "$ " .. cmd .. "\n"
            outputBox:setText(tab.output)

            local output, err = captureCommand(cmd)

            if output and output ~= "" then
                tab.output = tab.output .. output .. "\n"
            end
            if err then
                tab.output = tab.output .. "Error: " .. tostring(err) .. "\n"
            end
            tab.output = tab.output .. "\n"

            outputBox:setText(tab.output)
            outputBox:scrollTo("bottom")
            cmdInput:setText("")

            -- Refresh the user label in case sudo/login state changed
            local newSession = nyxlib.loadSession()
            local user = newSession.username or "guest"
            local suffix = ""
            if permissionsOk and permissions and permissions.sudoActive(user) then
                suffix = " [sudo]"
            end
            pcall(function() userLabel:setText(user .. "@nyxos" .. suffix) end)
        end

        cmdInput:onKey(function(self, key)
            local tab = activeTab
            if key == keys.enter or key == keys.numPadEnter then
                executeCommand(cmdInput:getText())
            elseif key == keys.up then
                if tab.historyIndex > 1 then
                    tab.historyIndex = tab.historyIndex - 1
                    cmdInput:setText(tab.history[tab.historyIndex] or "")
                end
            elseif key == keys.down then
                if tab.historyIndex < #tab.history then
                    tab.historyIndex = tab.historyIndex + 1
                    cmdInput:setText(tab.history[tab.historyIndex] or "")
                else
                    tab.historyIndex = #tab.history + 1
                    cmdInput:setText("")
                end
            end
        end)

        -- Run button (touch support)
        local runButton = main:addButton()
            :setText("Run")
            :setPosition(w - 10, h - 1)
            :setSize(5, 1)
            :setBackground(accent)
            :setForeground(palette.black)
            :onClick(function()
                executeCommand(cmdInput:getText())
            end)

        local newTermButton = main:addButton()
            :setText("+Term")
            :setPosition(w - 4, h - 1)
            :setSize(5, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)
            :onClick(function()
                local newTab = { output = motdText(), history = {}, historyIndex = 1 }
                table.insert(tabs, newTab)
                activeTab = newTab
                outputBox:setText(newTab.output)
                redrawTabBar()
            end)

        cmdInput:setFocused(true)

        basalt.run()
    end)

    if not ok then
        print("Error while starting the graphical shell.")
        return false
    end

    return true
end

-- Text fallback (if Basalt is unavailable/disabled)
function shellui.runTextFallback()
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)

    local nyxlib = dofile("/lib/nyxlib.lua")
    local theme = dofile("/lib/theme.lua")
    local accent = theme.accent()

    pcall(term.setTextColor, accent)
    print("=== NyxOS Shell (text mode) ===")
    pcall(term.setTextColor, palette.white)
    print("Basalt unavailable -- using the standard shell.")
    print("")

    shell.run("/bin/shell")
end

return shellui
