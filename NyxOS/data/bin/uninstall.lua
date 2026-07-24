-- /bin/uninstall.lua : full NyxOS uninstallation
-- Basalt graphical interface with real-time scanning
-- Usage: uninstall

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

-- Try multiple locations to load Basalt
local basaltOk, basalt = pcall(dofile, "/lib/basalt.lua")
if not basaltOk or not basalt then
    -- Try from the current directory (for tests run from disk)
    basaltOk, basalt = pcall(dofile, "data/lib/basalt.lua")
end
if not basaltOk or not basalt then
    -- Try a relative path
    basaltOk, basalt = pcall(dofile, "../lib/basalt.lua")
end
if basaltOk and basalt then
    local bridgeOk, bridge = pcall(dofile, "/lib/monitorbridge.lua")
    if bridgeOk and bridge then
        pcall(bridge.patch, basalt)
    end
end

-- Fallback text mode if Basalt is unavailable
local function textMode(...)
    local args = { ... }
    local forceMode = false

    for _, arg in ipairs(args) do
        if arg == "--force" then
            forceMode = true
        end
    end

    -- Check that NyxOS is installed
    if not fs.exists("/etc/nyx-release") then
        print("NyxOS is not installed on this computer.")
        return
    end

    -- Show install information
    local releaseFile = fs.open("/etc/nyx-release", "r")
    local releaseInfo = releaseFile.readAll()
    releaseFile.close()

    print("=== Uninstalling NyxOS ===")
    print("")
    print(releaseInfo)
    print("")

    if not forceMode then
        print("WARNING: This will COMPLETELY remove NyxOS.")
        print("The following will be deleted:")
        print("  - /bin/* (all NyxOS commands)")
        print("  - /lib/* (all NyxOS libraries)")
        print("  - /etc/* (configuration, users)")
        print("  - /home/* (all user folders)")
        print("  - /var/* (temporary data)")
        print("  - /startup.lua (boot script)")
        print("")
        print("The computer will reboot into vanilla CC: Tweaked.")
        print("")

        -- List users to warn about
        local userList = users.load()
        if #userList > 0 then
            print("Users that will be deleted:")
            for _, u in ipairs(userList) do
                local adminStr = u.admin and " (admin)" or ""
                print("  - " .. u.username .. adminStr)
            end
            print("")
        end

        write("Confirm uninstallation? (type 'yes' to confirm): ")
        local answer = read()
        if answer ~= "yes" then
            print("Uninstallation cancelled.")
            return
        end
    end

    print("")
    print("Deleting files...")

    -- Recursively deletes a folder
    local function removeRecursive(path)
        if not fs.exists(path) then
            return
        end
        if fs.isDir(path) then
            for _, name in ipairs(fs.list(path)) do
                local item = fs.combine(path, name)
                removeRecursive(item)
            end
            fs.delete(path)
        else
            fs.delete(path)
        end
    end

    -- Delete NyxOS folders
    local dirsToRemove = {
        "/bin",
        "/lib",
        "/etc",
        "/home",
        "/var",
    }

    for _, dir in ipairs(dirsToRemove) do
        if fs.exists(dir) then
            print("  Deleting " .. dir .. "...")
            removeRecursive(dir)
        end
    end

    -- Delete startup.lua
    if fs.exists("/startup.lua") then
        print("  Deleting /startup.lua...")
        fs.delete("/startup.lua")
    end

    -- Clean up any remaining root files that might belong to NyxOS
    local rootFiles = fs.list("/")
    local nyxFiles = {".DS_Store", "rom"} -- files to preserve
    for _, name in ipairs(rootFiles) do
        local path = "/" .. name
        if fs.isDir(path) then
            -- Preserve CC: Tweaked system folders
            if name ~= "rom" and name ~= ".DS_Store" then
                print("  Deleting " .. path .. "...")
                removeRecursive(path)
            end
        else
            -- Preserve system files
            local preserve = false
            for _, preserveName in ipairs(nyxFiles) do
                if name == preserveName then
                    preserve = true
                    break
                end
            end
            if not preserve then
                print("  Deleting " .. path .. "...")
                fs.delete(path)
            end
        end
    end

    print("")
    print("Uninstallation completed successfully.")
    print("")
    print("NyxOS has been completely removed from this computer.")
    print("The computer will reboot into vanilla CC: Tweaked.")
    print("")
    print("Press any key to reboot...")
    os.pullEvent("key")

    print("Rebooting...")
    os.reboot()
end

-- Basalt graphical interface
local function guiMode()
    -- Check that NyxOS is installed
    if not fs.exists("/etc/nyx-release") then
        print("NyxOS is not installed on this computer.")
        return
    end

    local palette = colors or colours
    local main = basalt.getMainFrame():setBackground(palette.black)
    local w, h = main:getWidth(), main:getHeight()

    -- Load install information
    local releaseFile = fs.open("/etc/nyx-release", "r")
    local releaseInfo = releaseFile.readAll()
    releaseFile.close()

    -- Load the user list
    local userList = users.load()

    -- Title
    main:addLabel()
        :setText("Uninstalling NyxOS")
        :setForeground(palette.red)
        :setPosition(2, 2)

    -- Install information
    local infoLabel = main:addLabel()
        :setText(releaseInfo)
        :setForeground(palette.lightGray)
        :setPosition(2, 4)

    -- Scan status label
    local scanStatus = main:addLabel()
        :setText("Scanning files...")
        :setForeground(palette.yellow)
        :setPosition(2, 7)

    -- List of files/folders to delete
    local fileList = main:addList()
        :setPosition(2, 8)
        :setSize(w - 4, math.min(6, h - 18))
        :setBackground(palette.gray)
        :setForeground(palette.white)
        :setSelectedBackground(palette.blue)
        :setSelectedForeground(palette.white)

    -- User list
    local userListDisplay = main:addList()
        :setPosition(2, 15)
        :setSize(w - 4, math.min(4, h - 22))
        :setBackground(palette.darkGray)
        :setForeground(palette.white)
        :setSelectedBackground(palette.purple)
        :setSelectedForeground(palette.white)

    -- Warning label
    local warningLabel = main:addLabel()
        :setText("WARNING: This operation is IRREVERSIBLE")
        :setForeground(palette.red)
        :setPosition(2, h - 6)

    -- Buttons
    local uninstallButton = main:addButton()
        :setText("Uninstall")
        :setPosition(2, h - 2)
        :setSize(15, 1)
        :setBackground(palette.red)
        :setForeground(palette.white)

    local cancelButton = main:addButton()
        :setText("Cancel")
        :setPosition(19, h - 2)
        :setSize(12, 1)
        :setBackground(palette.gray)
        :setForeground(palette.white)

    -- Progress label
    local progressLabel = main:addLabel()
        :setText("")
        :setForeground(palette.green)
        :setPosition(w - 25, h - 2)

    -- Scans the files
    local function scanFiles()
        fileList:clearItems()
        scanStatus:setText("Scanning files...")
        scanStatus:setForeground(palette.yellow)
        basalt.update()
        sleep(0.5) -- Delay so the scan is visible

        local items = {
            "/bin/* (commands)",
            "/lib/* (libraries)",
            "/etc/* (configuration)",
            "/home/* (users)",
            "/var/* (temporary)",
            "/startup.lua (boot script)"
        }

        for i, item in ipairs(items) do
            fileList:addItem(item)
        end

        scanStatus:setText("Scan complete - " .. #items .. " items found")
        scanStatus:setForeground(palette.green)
        basalt.update()
        sleep(0.3) -- Delay so the result is visible
    end

    -- Shows the users
    local function displayUsers()
        userListDisplay:clearItems()

        if #userList > 0 then
            for _, u in ipairs(userList) do
                local adminStr = u.admin and " [ADMIN]" or ""
                userListDisplay:addItem(u.username .. adminStr)
            end
        else
            userListDisplay:addItem("No users")
        end
    end

    -- Cancel button
    cancelButton:onClick(function()
        basalt.stop()
        print("Uninstallation cancelled.")
    end)

    -- Uninstall button
    uninstallButton:onClick(function()
        -- Final confirmation window
        local confirmWindow = basalt.createFrame()
            :setSize(40, 8)
            :setPosition(math.floor((w - 40) / 2), math.floor((h - 8) / 2))
            :setBackground(palette.gray)

        confirmWindow:addLabel()
            :setText("FINAL CONFIRMATION")
            :setForeground(palette.red)
            :setPosition(2, 2)

        confirmWindow:addLabel()
            :setText("All data will be LOST")
            :setForeground(palette.white)
            :setPosition(2, 3)

        confirmWindow:addLabel()
            :setText("Type 'CONFIRM' to continue:")
            :setForeground(palette.yellow)
            :setPosition(2, 5)

        local confirmInput = confirmWindow:addInput()
            :setPosition(2, 6)
            :setSize(36, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)

        local confirmBtn = confirmWindow:addButton()
            :setText("Confirm")
            :setPosition(2, 7)
            :setSize(18, 1)
            :setBackground(palette.red)
            :setForeground(palette.white)

        local cancelBtn = confirmWindow:addButton()
            :setText("Cancel")
            :setPosition(22, 7)
            :setSize(16, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)

        cancelBtn:onClick(function()
            confirmWindow:hide()
        end)

        confirmBtn:onClick(function()
            local input = confirmInput:getText()
            if input ~= "CONFIRM" then
                return
            end

            confirmWindow:hide()

            -- Uninstall
            local function removeRecursive(path)
                if not fs.exists(path) then
                    return
                end
                if fs.isDir(path) then
                    for _, name in ipairs(fs.list(path)) do
                        local item = fs.combine(path, name)
                        removeRecursive(item)
                    end
                    fs.delete(path)
                else
                    fs.delete(path)
                end
            end

            local dirsToRemove = {"/bin", "/lib", "/etc", "/home", "/var"}

            for i, dir in ipairs(dirsToRemove) do
                if fs.exists(dir) then
                    progressLabel:setText("Deleting " .. dir .. "...")
                    removeRecursive(dir)
                end
            end

            if fs.exists("/startup.lua") then
                progressLabel:setText("Deleting /startup.lua...")
                fs.delete("/startup.lua")
            end

            local rootFiles = fs.list("/")
            for _, name in ipairs(rootFiles) do
                local path = "/" .. name
                if fs.isDir(path) then
                    if name ~= "rom" and name ~= ".DS_Store" then
                        removeRecursive(path)
                    end
                else
                    local preserve = (name == ".DS_Store" or name == "rom")
                    if not preserve then
                        fs.delete(path)
                    end
                end
            end

            progressLabel:setText("Done!")
            progressLabel:setForeground(palette.green)

            basalt.stop()

            term.clear()
            term.setCursorPos(1, 1)
            print("Uninstallation completed successfully.")
            print("Rebooting...")
            sleep(2)
            os.reboot()
        end)

        confirmWindow:show()
        confirmInput:setFocused(true)
    end)

    -- Initialisation
    scanFiles()
    displayUsers()

    basalt.run()
end

-- Main entry point
if not basaltOk or not basalt then
    print("Basalt unavailable. Falling back to text mode.")
    textMode(...)
else
    term.clear()
    term.setCursorPos(1, 1)
    guiMode()
end
