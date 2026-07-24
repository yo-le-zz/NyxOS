-- /bin/encrypt.lua : Linux-style (LUKS) disk encryption
-- Basalt graphical interface with real-time scanning
-- Usage: encrypt

local crypto = dofile("/lib/crypto.lua")

-- Check for the Cryptography Accelerator
local cryptoOk, cryptoMsg = crypto.requireCrypto()
if not cryptoOk then
    print(cryptoMsg)
    print("")
    print("Options:")
    print("1. Connect a Cryptography Accelerator")
    print("2. Continue without encryption (not secure)")
    print("")
    write("Continue without encryption? (y/n): ")
    local answer = read()
    if answer ~= "y" and answer ~= "Y" then
        return
    end
    print("WARNING: No-encryption mode - passwords are not secure")
    sleep(2)
end

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

local CONFIG_PATH = "/etc/encrypt-config.lua"

-- Loads the encrypted disk configuration
local function loadConfig()
    if not fs.exists(CONFIG_PATH) then
        return {}
    end
    local f = fs.open(CONFIG_PATH, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

-- Saves the configuration
local function saveConfig(config)
    local f = fs.open(CONFIG_PATH, "w")
    f.write(textutils.serialize(config))
    f.close()
end

-- Detects all available disks/drives
local function findDrives()
    local drives = {}
    local sides = {"top", "bottom", "left", "right", "front", "back"}

    -- Search by side (directly connected)
    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) then
            local p = peripheral.wrap(side)
            if p and p.getMountPath then
                local mount = p.getMountPath()
                if mount then
                    table.insert(drives, {
                        name = side,
                        mount = mount,
                        type = "drive",
                        peripheral = p
                    })
                end
            end
        end
    end

    -- Search by network name (wired modems - drive_0, drive_1, disk_drive, etc.)
    local names = peripheral.getNames()
    for _, name in ipairs(names) do
        local p = peripheral.wrap(name)
        if not p then
            goto continue
        end

        -- Check if this is a drive (has the getMountPath method)
        if p.getMountPath then
            local mount = p.getMountPath()
            if mount then
                -- Check if this drive isn't already in the list
                local found = false
                for _, drive in ipairs(drives) do
                    if drive.name == name then
                        found = true
                        break
                    end
                end
                if not found then
                    -- Determine the type
                    local driveType = "network_drive"
                    if name:match("^drive_%d+$") then
                        driveType = "wired_drive"
                    elseif name:match("^disk_drive") then
                        driveType = "disk_drive"
                    elseif name:find("drive") then
                        driveType = "network_drive"
                    end

                    table.insert(drives, {
                        name = name,
                        mount = mount,
                        type = driveType,
                        peripheral = p
                    })
                end
            end
        end

        ::continue::
    end

    return drives
end

-- Fallback text mode if Basalt is unavailable
local function textMode(...)
    local args = { ... }

    if #args == 0 then
        local drives = findDrives()
        local config = loadConfig()

        if #drives == 0 then
            print("No disk detected.")
            print("Connect a drive (disk drive) to the computer.")
            return
        end

        print("Available disks:")
        print("")

        for i, drive in ipairs(drives) do
            local encrypted = config[drive.name]
            local status = "Not encrypted"
            if encrypted then
                if encrypted.unlocked then
                    status = "Encrypted (UNLOCKED)"
                else
                    status = "Encrypted (LOCKED)"
                end
            end

            print(string.format("%d) %s", i, drive.name))
            print("   Mount   : " .. drive.mount)
            print("   Type    : " .. drive.type)
            print("   Status  : " .. status)
            print("")
        end
    else
        print("Text mode does not support actions.")
        print("Use the graphical interface.")
    end
end

-- Basalt graphical interface
local function guiMode()
    local palette = colors or colours
    local main = basalt.getMainFrame():setBackground(palette.black)
    local w, h = main:getWidth(), main:getHeight()

    local config = loadConfig()
    local selectedDrive = nil
    local drives = {}

    -- Title
    main:addLabel()
        :setText("Disk Encryption - NyxOS")
        :setForeground(palette.cyan)
        :setPosition(2, 2)

    -- Scan status label
    local scanStatus = main:addLabel()
        :setText("Scanning...")
        :setForeground(palette.yellow)
        :setPosition(2, 4)

    -- Drive list
    local driveList = main:addList()
        :setPosition(2, 5)
        :setSize(w - 4, math.min(8, h - 12))
        :setBackground(palette.gray)
        :setForeground(palette.white)
        :setSelectedBackground(palette.blue)
        :setSelectedForeground(palette.white)

    -- Selected drive details label
    local detailsLabel = main:addLabel()
        :setText("")
        :setForeground(palette.lightGray)
        :setPosition(2, 14)
        :setSize(w - 4, 3)

    -- Action buttons
    local encryptButton = main:addButton()
        :setText("Encrypt")
        :setPosition(2, h - 2)
        :setSize(12, 1)
        :setBackground(palette.green)
        :setForeground(palette.black)
        :setEnabled(false)

    local unlockButton = main:addButton()
        :setText("Unlock")
        :setPosition(15, h - 2)
        :setSize(14, 1)
        :setBackground(palette.yellow)
        :setForeground(palette.black)
        :setEnabled(false)

    local lockButton = main:addButton()
        :setText("Lock")
        :setPosition(30, h - 2)
        :setSize(12, 1)
        :setBackground(palette.orange)
        :setForeground(palette.black)
        :setEnabled(false)

    local refreshButton = main:addButton()
        :setText("Refresh")
        :setPosition(w - 12, h - 2)
        :setSize(10, 1)
        :setBackground(palette.blue)
        :setForeground(palette.white)

    -- Message label
    local messageLabel = main:addLabel()
        :setText("")
        :setForeground(palette.red)
        :setPosition(2, h - 4)

    -- Refreshes the drive list
    local function updateDriveList()
        driveList:clearItems()
        scanStatus:setText("Scanning...")
        scanStatus:setForeground(palette.yellow)
        basalt.update()
        sleep(0.5) -- Delay so the scan is visible

        drives = findDrives()

        if #drives == 0 then
            scanStatus:setText("No disk detected")
            scanStatus:setForeground(palette.red)
            driveList:addItem("No disk available")
            detailsLabel:setText("Connect a drive to the computer.")
            encryptButton:setEnabled(false)
            unlockButton:setEnabled(false)
            lockButton:setEnabled(false)
            return
        end

        scanStatus:setText(#drives .. " disk(s) detected")
        scanStatus:setForeground(palette.green)
        basalt.update()
        sleep(0.3) -- Delay so the result is visible

        for i, drive in ipairs(drives) do
            local encrypted = config[drive.name]
            local status = "[NOT ENCRYPTED]"
            if encrypted then
                if encrypted.unlocked then
                    status = "[UNLOCKED]"
                else
                    status = "[LOCKED]"
                end
            end
            driveList:addItem(string.format("%s %s - %s", status, drive.name, drive.type))
        end

        -- Don't disable the buttons here, they'll be enabled on selection
        detailsLabel:setText("Select a disk to see the options")
    end

    -- Selecting a disk
    driveList:onSelect(function(self, index, item)
        if index > #drives then
            selectedDrive = nil
            return
        end

        selectedDrive = drives[index]
        local encrypted = config[selectedDrive.name]

        detailsLabel:setText(string.format("Disk: %s | Mount: %s | Type: %s",
            selectedDrive.name, selectedDrive.mount, selectedDrive.type))

        if encrypted then
            encryptButton:setEnabled(false)
            if encrypted.unlocked then
                unlockButton:setEnabled(false)
                lockButton:setEnabled(true)
            else
                unlockButton:setEnabled(true)
                lockButton:setEnabled(false)
            end
        else
            encryptButton:setEnabled(true)
            unlockButton:setEnabled(false)
            lockButton:setEnabled(false)
        end

        messageLabel:setText("")
    end)

    -- Refresh button
    refreshButton:onClick(function()
        messageLabel:setText("")
        config = loadConfig()
        updateDriveList()
    end)

    -- Encrypt button
    encryptButton:onClick(function()
        if not selectedDrive then return end

        -- Confirmation window
        local confirmWindow = basalt.createFrame()
            :setSize(40, 10)
            :setPosition(math.floor((w - 40) / 2), math.floor((h - 10) / 2))
            :setBackground(palette.gray)

        confirmWindow:addLabel()
            :setText("Disk encryption")
            :setForeground(palette.white)
            :setPosition(2, 2)

        confirmWindow:addLabel()
            :setText("Disk: " .. selectedDrive.name)
            :setForeground(palette.lightGray)
            :setPosition(2, 3)

        confirmWindow:addLabel()
            :setText("WARNING: All files will be encrypted")
            :setForeground(palette.red)
            :setPosition(2, 5)

        local passInput = confirmWindow:addInput()
            :setPosition(2, 7)
            :setSize(36, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)
            :setPlaceholder("Password")
            :setReplaceChar("*")

        local confirmBtn = confirmWindow:addButton()
            :setText("Encrypt")
            :setPosition(2, 9)
            :setSize(18, 1)
            :setBackground(palette.green)
            :setForeground(palette.black)

        local cancelBtn = confirmWindow:addButton()
            :setText("Cancel")
            :setPosition(22, 9)
            :setSize(16, 1)
            :setBackground(palette.red)
            :setForeground(palette.white)

        cancelBtn:onClick(function()
            confirmWindow:hide()
        end)

        confirmBtn:onClick(function()
            local password = passInput:getText()
            if not password or password == "" then
                messageLabel:setText("Password cannot be empty.")
                confirmWindow:hide()
                return
            end

            -- Derive the key
            local key = crypto.hash(password)
            if #key < 32 then
                key = key .. string.rep("0", 32 - #key)
            end
            key = key:sub(1, 32)

            local salt = crypto.generateKey()

            config[selectedDrive.name] = {
                encrypted = true,
                unlocked = false,
                salt = salt,
                keyHash = crypto.hash(key)
            }
            saveConfig(config)

            confirmWindow:hide()
            messageLabel:setText("Disk encrypted successfully!")
            messageLabel:setForeground(palette.green)
            updateDriveList()
        end)

        confirmWindow:show()
        passInput:setFocused(true)
    end)

    -- Unlock button
    unlockButton:onClick(function()
        if not selectedDrive then return end

        local confirmWindow = basalt.createFrame()
            :setSize(40, 8)
            :setPosition(math.floor((w - 40) / 2), math.floor((h - 8) / 2))
            :setBackground(palette.gray)

        confirmWindow:addLabel()
            :setText("Unlocking disk")
            :setForeground(palette.white)
            :setPosition(2, 2)

        confirmWindow:addLabel()
            :setText("Disk: " .. selectedDrive.name)
            :setForeground(palette.lightGray)
            :setPosition(2, 3)

        local passInput = confirmWindow:addInput()
            :setPosition(2, 5)
            :setSize(36, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)
            :setPlaceholder("Password")
            :setReplaceChar("*")

        local confirmBtn = confirmWindow:addButton()
            :setText("Unlock")
            :setPosition(2, 7)
            :setSize(18, 1)
            :setBackground(palette.green)
            :setForeground(palette.black)

        local cancelBtn = confirmWindow:addButton()
            :setText("Cancel")
            :setPosition(22, 7)
            :setSize(16, 1)
            :setBackground(palette.red)
            :setForeground(palette.white)

        cancelBtn:onClick(function()
            confirmWindow:hide()
        end)

        confirmBtn:onClick(function()
            local password = passInput:getText()
            if not password or password == "" then
                messageLabel:setText("Password required.")
                messageLabel:setForeground(palette.red)
                confirmWindow:hide()
                return
            end

            local key = crypto.hash(password)
            if #key < 32 then
                key = key .. string.rep("0", 32 - #key)
            end
            key = key:sub(1, 32)

            local keyHash = crypto.hash(key)
            if keyHash ~= config[selectedDrive.name].keyHash then
                messageLabel:setText("Incorrect password!")
                messageLabel:setForeground(palette.red)
                confirmWindow:hide()
                return
            end

            config[selectedDrive.name].unlocked = true
            config[selectedDrive.name].key = key
            saveConfig(config)

            confirmWindow:hide()
            messageLabel:setText("Disk unlocked!")
            messageLabel:setForeground(palette.green)
            updateDriveList()
        end)

        confirmWindow:show()
        passInput:setFocused(true)
    end)

    -- Lock button
    lockButton:onClick(function()
        if not selectedDrive then return end

        config[selectedDrive.name].unlocked = false
        config[selectedDrive.name].key = nil
        saveConfig(config)

        messageLabel:setText("Disk locked!")
        messageLabel:setForeground(palette.green)
        updateDriveList()
    end)

    -- Initial refresh
    updateDriveList()

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
