-- /lib/login.lua : NyxOS boot screen
--
-- 1) CloverOS-style boot menu (choose the boot mode, with automatic
--    startup after a countdown).
-- 2) Multi-user login screen (required to enter the shell, unless the
--    "recovery shell" is explicitly chosen).
--
-- Everything is built with the Basalt library (/lib/basalt.lua) for a
-- polished graphical interface. If Basalt is missing or crashes for any
-- reason, every step automatically falls back to a simple text mode:
-- the computer must never get stuck at boot.

local nyxlib = dofile("/lib/nyxlib.lua")
local users  = dofile("/lib/users.lua")
local theme  = dofile("/lib/theme.lua")

local login = {}
local palette = colors or colours

local function loadBasalt()
    return nyxlib.loadBasalt()
end

------------------------------------------------------------------
-- Boot menu
------------------------------------------------------------------

-- Simple, reliable text version (no dependency on Basalt): shows the
-- options then a plain read(), without an automatic parallel countdown
-- (CC:Tweaked doesn't make it easy to read the keyboard and count down
-- at the same time without coroutines/parallel -- not worth the risk on
-- the text recovery screen).
local function bootMenuTextSimple(accent)
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
    pcall(term.setTextColor, accent)
    print("== NyxOS -- " .. nyxlib.getHostname() .. " ==")
    pcall(term.setTextColor, palette.white)
    print("")
    print("1) Start NyxOS (default)")
    print("2) Recovery shell (no login)")
    print("")
    write("Choice (Enter = start normally): ")
    local answer = read()
    if answer == "2" then
        return "recovery"
    end
    return "boot"
end

local function bootMenuBasalt(basalt, accent)
    local choice = "boot"
    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()
        local cx, cy = math.floor(w / 2), math.floor(h / 2)

        main:addLabel()
            :setText("NyxOS")
            :setForeground(accent)
            :setPosition(math.max(1, cx - 2), math.max(1, cy - 5))

        main:addLabel()
            :setText(nyxlib.getHostname() .. " -- choose a boot mode")
            :setForeground(palette.lightGray)
            :setPosition(math.max(1, cx - 18), math.max(1, cy - 3))

        local list = main:addList()
            :setPosition(math.max(1, cx - 15), math.max(1, cy - 1))
            :setSize(30, 3)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setSelectedBackground(accent)
            :setSelectedForeground(palette.black)
            :addItem("Start NyxOS")
            :addItem("Recovery shell (no login)")

        local countdown = main:addLabel()
            :setText("Starting automatically in 5s -- Up/Down then Enter")
            :setForeground(palette.gray)
            :setPosition(math.max(1, cx - 25), math.min(h, cy + 3))

        local selectedIndex = 1
        local remaining = 5
        local finished = false

        local function finish(sel)
            if finished then return end
            finished = true
            if sel == 2 then choice = "recovery" end
            basalt.stop()
        end

        list:onSelect(function(self, index, item)
            selectedIndex = index
        end)

        list:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then
                finish(selectedIndex)
            else
                remaining = -1
            end
        end)

        basalt.schedule(function()
            while remaining > 0 and not finished do
                sleep(1)
                remaining = remaining - 1
                if remaining > 0 then
                    countdown:setText("Starting automatically in " .. remaining .. "s -- Up/Down then Enter")
                end
            end
            if not finished then
                finish(1)
            end
        end)

        list:setFocused(true)
        basalt.run()
    end)
    if not ok then
        return "boot"
    end
    return choice
end

function login.bootMenu()
    local accent = theme.accent()
    local basalt = loadBasalt()
    if basalt then
        return bootMenuBasalt(basalt, accent)
    end
    return bootMenuTextSimple(accent)
end

------------------------------------------------------------------
-- Login screen
------------------------------------------------------------------

local function loginText(accent)
    local list = users.load()
    if #list == 0 then
        print("No users configured. Create an account:")
        write("Username: ")
        local name = read()
        while not name or name == "" do
            write("Name can't be empty. Username: ")
            name = read()
        end
        write("Password (optional): ")
        local pass = read("*")
        users.add(name, pass, true)
        return name
    end

    while true do
        term.setBackgroundColor(palette.black)
        term.clear()
        term.setCursorPos(1, 1)
        pcall(term.setTextColor, accent)
        print("NyxOS -- " .. nyxlib.getHostname())
        pcall(term.setTextColor, palette.white)
        print("Users: " .. table.concat((function()
            local names = {}
            for _, u in ipairs(list) do table.insert(names, u.username) end
            return names
        end)(), ", "))
        print("")
        write("login: ")
        local name = read()
        local user = users.find(name or "")
        if not user then
            print("Unknown user.")
            sleep(1)
        else
            local ok = true
            if user.password and user.password ~= "" then
                write("password: ")
                local pass = read("*")
                ok = users.checkPassword(name, pass)
            end
            if ok then
                return user.username
            else
                print("Incorrect password.")
                sleep(1)
            end
        end
    end
end

local function loginBasalt(basalt, accent)
    local list = users.load()
    if #list == 0 then
        return nil -- no users: let text mode handle account creation
    end

    local loggedUser = nil
    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()
        local cx, cy = math.floor(w / 2), math.floor(h / 2)

        main:addLabel()
            :setText("NyxOS -- " .. nyxlib.getHostname())
            :setForeground(accent)
            :setPosition(math.max(1, cx - 12), math.max(1, cy - 6))

        main:addLabel()
            :setText("User:")
            :setForeground(palette.white)
            :setPosition(math.max(1, cx - 14), cy - 3)

        local userList = main:addList()
            :setPosition(math.max(1, cx - 14), cy - 2)
            :setSize(28, math.min(6, #list))
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setSelectedBackground(accent)
            :setSelectedForeground(palette.black)
        for _, u in ipairs(list) do
            userList:addItem(u.username)
        end

        local passLabel = main:addLabel()
            :setText("Password:")
            :setForeground(palette.white)
            :setPosition(math.max(1, cx - 14), cy + math.min(6, #list) + 1)

        local passInput = main:addInput()
            :setPosition(math.max(1, cx - 14), cy + math.min(6, #list) + 2)
            :setSize(28, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setReplaceChar("*")

        local status = main:addLabel()
            :setText("Select your user, enter your password, then confirm.")
            :setForeground(palette.lightGray)
            :setPosition(math.max(1, cx - 25), cy + math.min(6, #list) + 4)

        local selected = list[1]
        userList:onSelect(function(self, index, item)
            selected = list[index]
        end)

        local function attempt()
            if not selected then return end
            if users.checkPassword(selected.username, passInput:getText()) then
                loggedUser = selected.username
                basalt.stop()
            else
                status:setText("Incorrect password, try again.")
                pcall(function() passInput:setText("") end)
            end
        end

        passInput:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then
                attempt()
            end
        end)

        local loginButton = main:addButton()
            :setText("Log in")
            :setPosition(math.max(1, cx - 8), cy + math.min(6, #list) + 6)
            :setSize(16, 1)
            :setBackground(accent)
            :setForeground(palette.black)
            :onClick(function() attempt() end)

        passInput:setFocused(true)
        basalt.run()
    end)
    if not ok then
        return nil
    end
    return loggedUser
end

-- Returns the username of the logged in user.
function login.authenticate()
    local accent = theme.accent()
    local basalt = loadBasalt()
    if basalt then
        local name = loginBasalt(basalt, accent)
        if name then
            return name
        end
        -- Basalt crashed, or no users exist yet: fall back to text mode
        -- so boot never gets stuck.
    end
    return loginText(accent)
end

return login
