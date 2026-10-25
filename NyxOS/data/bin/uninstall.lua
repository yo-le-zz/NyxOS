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


-- What NyxOS put on the computer. Anything else (the user's own files in
-- the root, disk drives, NyxLoader's boot files...) is deliberately left
-- alone: the old uninstaller wiped every folder in "/" except /rom.
local NYX_DIRS = { "/bin", "/lib", "/etc", "/home", "/var" }

local function readAll(path)
    local f = fs.exists(path) and not fs.isDir(path) and fs.open(path, "r")
    if not f then return nil end
    local body = f.readAll()
    f.close()
    return body
end

-- Deletes a file/folder; returns false (and the reason) instead of
-- raising, so one read-only mount cannot abort the whole uninstall.
local function safeDelete(path)
    if not fs.exists(path) then return true end
    local ok, err = pcall(fs.delete, path)
    return ok, err
end

-- Removes NyxOS. `log(text)` reports progress; returns the list of
-- things that could not be deleted.
local function wipeNyxOS(log)
    local failures = {}
    local function remove(path)
        if fs.exists(path) then
            log("Deleting " .. path .. "...")
            local ok, err = safeDelete(path)
            if not ok then table.insert(failures, path .. ": " .. tostring(err)) end
        end
    end

    for _, dir in ipairs(NYX_DIRS) do remove(dir) end
    remove("/nyxos.lua")

    -- boot.json describes NyxOS to NyxLoader.
    local boot = readAll("/boot.json")
    if boot and boot:find("nyxos.lua", 1, true) then remove("/boot.json") end

    -- /startup.lua is removed only when it is NyxOS's own fallback script;
    -- NyxLoader's (or the user's) is not ours to delete.
    local startup = readAll("/startup.lua")
    if startup and startup:find("Minimal fallback boot script", 1, true) then
        remove("/startup.lua")
    end
    return failures
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
        print("  - /nyxos.lua and /boot.json (boot files)")
        print("")
        print("Other files in the root folder (and NyxLoader) are kept.")
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
    local failures = wipeNyxOS(function(text) print("  " .. text) end)
    for _, f in ipairs(failures) do print("  could not delete " .. f) end

    print("")
    print("Uninstallation completed successfully.")
    print("")
    print("NyxOS has been removed from this computer.")
    print("Your other files in the root folder were left untouched.")
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
        :setBackground(palette.gray)
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
        fileList:clear()
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
            "/nyxos.lua, /boot.json (boot files)"
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
        userListDisplay:clear()

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
            :setBackground(palette.gray)
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
            local failures = wipeNyxOS(function(text)
                progressLabel:setText(text)
                basalt.update()
            end)

            progressLabel:setText(#failures == 0 and "Done!" or ("Done, " .. #failures .. " item(s) could not be deleted"))
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
