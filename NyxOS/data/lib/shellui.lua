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

-- Basalt's TextBox has no scrollTo(): its viewport is the `scrollY`
-- property (a 0-based line offset), so "scroll to the bottom" means
-- showing the last `height` lines.
local function scrollToBottom(box)
    pcall(function()
        local total = #box:getLines()
        box:setScrollY(math.max(0, total - box:getHeight()))
    end)
end

-- Runs a command and returns its output as a string (see /lib/capture.lua).
local function captureCommand(cmd)
    local capture = dofile("/lib/capture.lua")
    return capture.run(cmd)
end

-- Builds the terminal UI (tabs, output box, input line) inside `main`,
-- any Basalt container. Used full-screen by shellui.run() and inside a
-- desktop panel by the desktop's Terminal app (opts.header = false).
--   opts.header : false to omit the "NyxOS -- host / user" bar
--   opts.onExit : called when the last tab is closed (`exit`)
function shellui.mount(basalt, main, opts)
    opts = opts or {}
    local theme = dofile("/lib/theme.lua")
    local accent = theme.accent()
    local nyxlib = dofile("/lib/nyxlib.lua")
    local permissionsOk, permissions = pcall(dofile, "/lib/permissions.lua")
    local w, h = main:getWidth(), main:getHeight()

        local session = nyxlib.loadSession()
        local currentUser = session.username or "guest"

        -- Header with hostname and user (not when embedded in the desktop)
        local top = 0
        local userLabel = { setText = function() end }
        if opts.header ~= false then
            top = 1
            local header = main:addFrame()
                :setPosition(1, 1)
                :setSize(w, 1)
                :setBackground(accent)

            header:addLabel()
                :setText("NyxOS -- " .. nyxlib.getHostname())
                :setForeground(palette.black)
                :setPosition(2, 1)

            userLabel = header:addLabel()
                :setText(currentUser .. "@nyxos")
                :setForeground(palette.black)
                :setPosition(math.max(2, w - #currentUser - 8), 1)
        end

        -- Tab bar (multiple independent terminals within the window)
        local tabBar = main:addFrame()
            :setPosition(1, top + 1)
            :setSize(w, 1)
            :setBackground(palette.gray)

        -- Output area (scrollable)
        local outputBox = main:addTextBox()
            :setPosition(2, top + 3)
            :setSize(w - 3, h - top - 4)
            :setEditable(false)
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
            return "NyxOS Graphical Shell v1.1.0\nType 'help' for the command list, or 'man' for the manual.\n\n"
        end

        local redrawTabBar
        -- Closes the active terminal tab; closing the last one leaves the
        -- graphical shell.
        local function closeActiveTab()
            if #tabs <= 1 then
                if opts.onExit then opts.onExit() else basalt.stop() end
                return
            end
            for i, tab in ipairs(tabs) do
                if tab == activeTab then
                    table.remove(tabs, i)
                    activeTab = tabs[math.min(i, #tabs)]
                    break
                end
            end
            outputBox:setText(activeTab.output)
            scrollToBottom(outputBox)
            redrawTabBar()
        end

        function redrawTabBar()
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
                    scrollToBottom(outputBox)
                    redrawTabBar()
                end)
                table.insert(tabButtons, btn)
                x = x + #label + 3
            end
            local plusBtn = tabBar:addButton()
                :setText("+")
                :setPosition(x, 1)
                :setSize(3, 1)
                :setBackground(palette.lightGray)
                :setForeground(palette.black)
            plusBtn:onClick(function()
                local newTab = { output = motdText(), history = {}, historyIndex = 1 }
                table.insert(tabs, newTab)
                activeTab = newTab
                outputBox:setText(newTab.output)
                redrawTabBar()
            end)
            table.insert(tabButtons, plusBtn)

            -- "x": close the active terminal
            local closeBtn = tabBar:addButton()
                :setText("x")
                :setPosition(x + 4, 1)
                :setSize(3, 1)
                :setBackground(palette.red)
                :setForeground(palette.white)
            closeBtn:onClick(closeActiveTab)
            table.insert(tabButtons, closeBtn)
        end

        local firstTab = { output = motdText(), history = {}, historyIndex = 1 }
        table.insert(tabs, firstTab)
        activeTab = firstTab
        outputBox:setText(firstTab.output)
        redrawTabBar()

        -- Runs a command in the active tab
        local busy, awaiting = false, false
        local function executeCommand(cmd)
            if cmd == nil or cmd == "" then
                return
            end
            local tab = activeTab
            local capture = dofile("/lib/capture.lua")

            table.insert(tab.history, cmd)
            tab.historyIndex = #tab.history + 1

            -- `clear` / `cls` / `exit` act on the text box itself: the
            -- command would only clear an invisible capture buffer.
            if capture.isClear(cmd) then
                tab.output = ""
                outputBox:setText("")
                cmdInput:setText("")
                return
            end
            if capture.isExit(cmd) then
                cmdInput:setText("")
                closeActiveTab()
                return
            end

            if busy then
                return
            end
            busy = true
            tab.output = tab.output .. "$ " .. cmd .. "\n"
            outputBox:setText(tab.output)
            scrollToBottom(outputBox)
            cmdInput:setText("")

            -- The command runs in a Basalt thread so it can wait for
            -- input (sudo's password, "y/n" questions) without freezing
            -- the interface.
            local base = tab.output
            local ui = {
                prompt = function(soFar, mask)
                    tab.output = base .. soFar
                    if tab == activeTab then
                        outputBox:setText(tab.output)
                        scrollToBottom(outputBox)
                    end
                    awaiting = true
                    pcall(function() cmdInput:setReplaceChar(mask or "") end)
                    pcall(function() cmdInput:setPlaceholder("(answer, then Enter)") end)
                    cmdInput:setText("")
                    cmdInput:setFocused(true)
                    local _, answer = os.pullEvent("nyx_prompt_done")
                    awaiting = false
                    pcall(function() cmdInput:setReplaceChar("") end)
                    pcall(function() cmdInput:setPlaceholder("Type a command...") end)
                    return answer
                end,
            }

            basalt.schedule(function()
                local okRun, output, err = pcall(capture.run, cmd, ui)
                if not okRun then
                    err = tostring(output)
                    output = ""
                end
                awaiting = false
                busy = false

                tab.output = base
                if output and output ~= "" then
                    tab.output = tab.output .. output .. "\n"
                end
                if err then
                    tab.output = tab.output .. "Error: " .. tostring(err) .. "\n"
                end
                tab.output = capture.trim(tab.output .. "\n", 300)

                if tab == activeTab then
                    outputBox:setText(tab.output)
                    scrollToBottom(outputBox)
                end
                cmdInput:setText("")
                cmdInput:setFocused(true)

                -- Refresh the user label in case sudo/login state changed
                local newSession = nyxlib.loadSession()
                local user = newSession.username or "guest"
                local suffix = ""
                if permissionsOk and permissions and permissions.sudoActive(user) then
                    suffix = " [sudo]"
                end
                pcall(function() userLabel:setText(user .. "@nyxos" .. suffix) end)
            end)
        end

        -- Enter / Run: answers a pending question, or starts a command.
        local function submit()
            if awaiting then
                local text = cmdInput:getText()
                cmdInput:setText("")
                os.queueEvent("nyx_prompt_done", text)
            else
                executeCommand(cmdInput:getText())
            end
        end

        cmdInput:onKey(function(self, key)
            local tab = activeTab
            if key == keys.enter or key == keys.numPadEnter then
                submit()
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
                submit()
            end)

        local newTermButton = main:addButton()
            :setText("+Term")
            :setPosition(w - 4, h - 1)
            :setSize(5, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :onClick(function()
                local newTab = { output = motdText(), history = {}, historyIndex = 1 }
                table.insert(tabs, newTab)
                activeTab = newTab
                outputBox:setText(newTab.output)
                redrawTabBar()
            end)

        cmdInput:setFocused(true)

    -- Lets the embedding UI run a command in the active tab (e.g. the
    -- desktop's "Run" / "apt install" buttons).
    return {
        execute = function(cmd) executeCommand(cmd) end,
    }
end

-- Main graphical shell
function shellui.run()
    local basalt = loadBasalt()
    if not basalt then
        print("Error: Basalt unavailable. Cannot start the graphical shell.")
        return false
    end

    pcall(function() dofile("/lib/services.lua").registerPseudo("shellui", "ui", "Graphical shell (Basalt)") end)
    local ok, err = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        shellui.mount(basalt, main, {})
        basalt.run()
    end)

    if not ok then
        print("Error while starting the graphical shell: " .. tostring(err))
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

    shell.run("shell")
end

return shellui
