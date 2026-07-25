-- install.lua : NyxOS installer / updater
-- Place install.lua and the data/ folder side by side, then run: install
--
-- If NyxOS is already installed, system files are updated while
-- preserving users, configuration and /home. If NyxOS looks partially
-- installed/broken, a Recovery option repairs system files without
-- touching your data (see also the standalone `recovery` command).

local VERSION = "1.0.2"
local palette = colors or colours

------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------

local function getInstallDir()
    local prog = shell.getRunningProgram()
    if prog and prog ~= "" then
        local dir = fs.getDir(prog)
        if dir and dir ~= "" then
            return dir
        end
    end
    return "."
end

local function findDataDir()
    local base = getInstallDir()
    local candidates = {
        fs.combine(base, "data"),
        "data",
        "disk/data",
    }
    for _, path in ipairs(candidates) do
        if fs.isDir(path) then
            return path
        end
    end
    return nil
end

local function loadBasalt(dataDir)
    local paths = {}
    if dataDir then
        table.insert(paths, fs.combine(dataDir, "lib/basalt.lua"))
    end
    table.insert(paths, "/lib/basalt.lua")
    table.insert(paths, "data/lib/basalt.lua")
    table.insert(paths, "disk/data/lib/basalt.lua")
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local ok, mod = pcall(dofile, path)
            if ok and type(mod) == "table" and mod.getMainFrame then
                local bridgePath = dataDir and fs.combine(dataDir, "lib/monitorbridge.lua") or "/lib/monitorbridge.lua"
                local bridgeOk, bridge = pcall(dofile, fs.exists(bridgePath) and bridgePath or "/lib/monitorbridge.lua")
                if bridgeOk and bridge then
                    pcall(bridge.patch, mod)
                end
                return mod
            end
        end
    end
    return nil
end

-- Detects a connected monitor and redirects the terminal to it *before*
-- the wizard runs, so both the text and the Basalt install screens
-- render on the external screen (not just the computer's own terminal)
-- when one is present. Falls back silently to the computer terminal if
-- no monitor is found.
local function setupScreen(dataDir)
    local displayPath = dataDir and fs.combine(dataDir, "lib/display.lua") or "/lib/display.lua"
    if not fs.exists(displayPath) then
        displayPath = "/lib/display.lua"
    end
    if not fs.exists(displayPath) then
        return
    end
    local ok, nyxdisplay = pcall(dofile, displayPath)
    if ok and nyxdisplay then
        pcall(nyxdisplay.setup, true)
    end
end

local function loadThemePresets(dataDir)
    local defaults = {
        { name = "Nyx Violet",     accent = palette.purple },
        { name = "Ocean Blue",     accent = palette.blue },
        { name = "Cyan",           accent = palette.cyan },
        { name = "Forest Green",   accent = palette.green },
        { name = "Sunset Orange",  accent = palette.orange },
        { name = "Crimson Red",    accent = palette.red },
        { name = "Magenta",        accent = palette.magenta },
        { name = "Classic Grey",   accent = palette.lightGray },
    }
    if dataDir then
        local themePath = fs.combine(dataDir, "lib/theme.lua")
        if fs.exists(themePath) then
            local ok, theme = pcall(dofile, themePath)
            if ok and theme and theme.presets then
                return theme.presets
            end
        end
    end
    return defaults
end

-- NyxOS installs behind NyxLoader now: the OS entry point is
-- /nyxos.lua (or <root>/nyxos.lua on a disk install), described by a
-- boot.json NyxLoader reads to know what to chainload. /startup.lua is
-- NyxLoader's own territory on the main computer.
local function isInstalled(root)
    root = root or ""
    return fs.exists(fs.combine(root, "etc/nyx-release"))
        or fs.exists(fs.combine(root, "nyxos.lua"))
        or (root == "" and fs.exists("/startup.lua"))
end

-- Detects any attached disk drive (peripheral type "drive") with a
-- mounted disk, for the "install on a disk" flow.
local function findDisks()
    local disks = {}
    if not peripheral then
        return disks
    end
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "drive" then
            local drive = peripheral.wrap(name)
            local mount = drive and drive.getMountPath and drive.getMountPath()
            if mount then
                table.insert(disks, { peripheralName = name, mount = mount })
            end
        end
    end
    return disks
end

-- Heuristic: NyxOS looks *partially* installed (some core pieces
-- present, others missing) -- a good sign something broke, and the
-- wizard should offer Recovery instead of a blind update.
local function looksBroken(root)
    root = root or ""
    if not isInstalled(root) then
        return false
    end
    local expected = { "nyxos.lua", "lib/nyxlib.lua", "lib/users.lua", "bin/apt.lua", "etc/passwd" }
    local missing = 0
    for _, p in ipairs(expected) do
        if not fs.exists(fs.combine(root, p)) then missing = missing + 1 end
    end
    return missing > 0 and missing < #expected
end

local function getInstalledVersion(root)
    root = root or ""
    local releasePath = fs.combine(root, "etc/nyx-release")
    if not fs.exists(releasePath) then
        return "unknown"
    end
    local f = fs.open(releasePath, "r")
    local line = f.readLine() or "unknown"
    f.close()
    return line
end

local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function copyFile(src, dst)
    ensureDir(fs.getDir(dst))
    if fs.exists(dst) then
        fs.delete(dst)
    end
    fs.copy(src, dst)
end

local function copyTree(src, dst, skip)
    skip = skip or {}
    if not fs.isDir(src) then
        return
    end
    ensureDir(dst)
    for _, name in ipairs(fs.list(src)) do
        local srcPath = fs.combine(src, name)
        local dstPath = fs.combine(dst, name)
        if skip[dstPath] or skip[name] then
            -- preserve
        elseif fs.isDir(srcPath) then
            copyTree(srcPath, dstPath, skip)
        else
            copyFile(srcPath, dstPath)
        end
    end
end

local function writeRelease(root)
    root = root or ""
    local f = fs.open(fs.combine(root, "etc/nyx-release"), "w")
    f.write("NyxOS " .. VERSION .. "\n")
    f.write("Installed on " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n")
    f.close()
end

local function writeBootJson(root)
    root = root or ""
    local f = fs.open(fs.combine(root, "boot.json"), "w")
    f.write(textutils.serialiseJSON and textutils.serialiseJSON({
        name = "NyxOS",
        version = VERSION,
        author = "yo-le-zz",
        file = "nyxos.lua",
    }) or ('{"name":"NyxOS","version":"' .. VERSION .. '","author":"yo-le-zz","file":"nyxos.lua"}'))
    f.close()
end

-- /etc files that must never be overwritten by an update/recovery
-- (paths relative to the install root -- see deployFiles).
local UPDATE_SKIP_NAMES = {
    "etc/passwd", "etc/hostname", "etc/nyx-theme.lua", "etc/nyx-display.lua",
    "etc/nyx-config.lua", "etc/encrypt-config.lua", "etc/nyx-release",
    "etc/apt/installed.lua", "etc/machine-id", "etc/sudoers.lua",
}

-- root: "" for the main computer, or a disk's mount path (e.g.
-- "disk3") for a disk install -- everything is deployed under that
-- prefix so a disk install is fully self-contained and portable.
local function deployFiles(dataDir, root, isUpdate)
    root = root or ""
    print(isUpdate and "Updating system files..." or "Installing files...")

    ensureDir(fs.combine(root, "bin"))
    ensureDir(fs.combine(root, "lib"))
    ensureDir(fs.combine(root, "etc"))
    ensureDir(fs.combine(root, "var"))
    ensureDir(fs.combine(root, "home"))

    local skip = {}
    for _, name in ipairs(UPDATE_SKIP_NAMES) do
        skip[fs.combine(root, name)] = true
    end

    copyTree(fs.combine(dataDir, "bin"), fs.combine(root, "bin"), skip)
    copyTree(fs.combine(dataDir, "lib"), fs.combine(root, "lib"), skip)
    copyTree(fs.combine(dataDir, "etc/services"), fs.combine(root, "etc/services"), skip)

    -- The OS entry point: NyxLoader chainloads this via boot.json,
    -- instead of the OS owning /startup.lua directly.
    copyFile(fs.combine(dataDir, "startup.lua"), fs.combine(root, "nyxos.lua"))
    writeBootJson(root)

    if fs.exists(fs.combine(dataDir, "etc/motd")) then
        copyFile(fs.combine(dataDir, "etc/motd"), fs.combine(root, "etc/motd"))
    end

    ensureDir(fs.combine(root, "etc/apt"))
    if not isUpdate or not fs.exists(fs.combine(root, "etc/apt/installed.lua")) then
        if fs.exists(fs.combine(dataDir, "etc/apt/installed.lua")) then
            copyFile(fs.combine(dataDir, "etc/apt/installed.lua"), fs.combine(root, "etc/apt/installed.lua"))
        end
    end

    if not isUpdate then
        if fs.exists(fs.combine(dataDir, "etc/nyx-release")) then
            copyFile(fs.combine(dataDir, "etc/nyx-release"), fs.combine(root, "etc/nyx-release"))
        end
    end

    writeRelease(root)
end

-- Wipes everything on the main computer except /rom, for a truly fresh
-- install (never run for updates/recovery, and never for a disk
-- install -- only ever for a brand new main-computer install).
local function wipeExceptRom()
    for _, name in ipairs(fs.list("/")) do
        if name ~= "rom" then
            pcall(fs.delete, "/" .. name)
        end
    end
end

-- Fetches and runs NyxLoader's own webinstall.lua so it becomes this
-- computer's /startup.lua (NyxLoader is a separate project -- NyxOS
-- only needs to hand off to its installer, not reimplement it). If
-- this fails (no http, network hiccup...), NyxOS still writes a
-- minimal fallback /startup.lua that boots straight into nyxos.lua, so
-- the computer never bricks even without NyxLoader installed.
local function installNyxLoader()
    if http then
        print("Installing NyxLoader (boot menu)...")
        local response = http.get("https://raw.githubusercontent.com/yo-le-zz/NyxLoader/main/webinstall.lua")
        if response then
            local body = response.readAll()
            response.close()
            local tmpPath = "/var/apt/tmp/nyxloader-webinstall.lua"
            if not fs.exists("/var/apt/tmp") then fs.makeDir("/var/apt/tmp") end
            local f = fs.open(tmpPath, "w")
            f.write(body)
            f.close()
            local ok = shell.run(tmpPath)
            fs.delete(tmpPath)
            if ok then
                print("NyxLoader installed.")
                return true
            end
            print("NyxLoader's installer reported an error.")
        else
            print("Could not download NyxLoader's installer.")
        end
        print("Using a minimal fallback boot script instead.")
    else
        print("http unavailable: using a minimal fallback boot script instead of NyxLoader.")
    end

    local f = fs.open("/startup.lua", "w")
    f.write([[
-- Minimal fallback boot script (NyxLoader could not be installed).
-- Re-run 'install' with http enabled to get the full NyxLoader boot
-- menu instead: https://github.com/yo-le-zz/NyxLoader
if fs.exists("/nyxos.lua") then
    dofile("/nyxos.lua")
else
    print("nyxos.lua not found.")
end
]])
    f.close()
    return false
end

local function applyConfig(config, root)
    root = root or ""

    if root == "" then
        local nyxlib = dofile("/lib/nyxlib.lua")
        local users = dofile("/lib/users.lua")
        local theme = dofile("/lib/theme.lua")

        nyxlib.setHostname(config.hostname)
        theme.save({ name = config.themeName, accent = config.accent })
        nyxlib.saveTable("/etc/nyx-config.lua", { gui = config.gui ~= false })

        if users.count() == 0 then
            local ok, err = users.add(config.username, config.password, true)
            if not ok then
                print("Error creating user: " .. tostring(err))
                return false
            end
        end
        return true
    end

    -- Disk install: users.lua/nyxlib.lua hardcode absolute "/etc/..."
    -- paths (correct for the main computer they'd normally run on), so
    -- write the equivalent files directly under the disk's own root
    -- instead, using the disk's own copy of crypto.lua for hashing.
    local crypto = dofile(fs.combine(root, "lib/crypto.lua"))
    local nyxlib = dofile(fs.combine(root, "lib/nyxlib.lua"))

    local f = fs.open(fs.combine(root, "etc/hostname"), "w")
    f.write(config.hostname)
    f.close()

    nyxlib.saveTable(fs.combine(root, "etc/nyx-theme.lua"), { name = config.themeName, accent = config.accent })
    nyxlib.saveTable(fs.combine(root, "etc/nyx-config.lua"), { gui = config.gui ~= false })

    local home = "home/" .. config.username
    ensureDir(fs.combine(root, home))
    local hashedPassword = ""
    if config.password and config.password ~= "" then
        hashedPassword = crypto.hash(config.password)
    end
    nyxlib.saveTable(fs.combine(root, "etc/passwd"), {
        { username = config.username, password = hashedPassword, home = "/" .. home, admin = true },
    })

    return true
end

------------------------------------------------------------------
-- Text wizard
------------------------------------------------------------------

-- defaultValue is returned when the user just presses Enter (empty
-- answer) -- e.g. askYesNo("... [y]: ", true) so the shown "[y]" hint
-- actually matches the behaviour.
local function askYesNo(prompt, defaultValue)
    write(prompt)
    local answer = read()
    if answer == nil or answer == "" then
        return defaultValue and true or false
    end
    return answer == "y" or answer == "Y" or answer == "yes"
end

local function wizardText(presets, mode)
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)

    if mode == "update" or mode == "recovery" then
        print(mode == "recovery" and "=== NyxOS Recovery ===" or "=== NyxOS Update ===")
        print("")
        print("Installed version : " .. getInstalledVersion())
        print("New version       : NyxOS " .. VERSION)
        print("")
        if mode == "recovery" then
            print("NyxOS looks partially installed or damaged.")
            print("Recovery repairs system files (/bin, /lib, /startup.lua)")
            print("without touching your users, config, or /home.")
        else
            print("Users and configuration will be preserved.")
        end
        print("")
        if not askYesNo((mode == "recovery" and "Run recovery" or "Continue the update") .. "? (y/n): ") then
            print("Cancelled.")
            return nil
        end
        return { update = true, recovery = (mode == "recovery") }
    end

    print("=== Installing NyxOS " .. VERSION .. " ===")
    print("")

    write("Username (admin): ")
    local username = read()
    while not username or username == "" do
        write("Name can't be empty. Username: ")
        username = read()
    end

    write("Password (optional, Enter = none): ")
    local password = read("*")

    write("Computer name [" .. tostring(os.getComputerLabel() or "nyxos") .. "]: ")
    local hostname = read()
    if not hostname or hostname == "" then
        hostname = os.getComputerLabel() or "nyxos"
    end

    print("")
    print("Accent colour:")
    for i, p in ipairs(presets) do
        print("  " .. i .. ") " .. p.name)
    end
    write("Choice [1]: ")
    local choice = tonumber(read()) or 1
    if choice < 1 or choice > #presets then choice = 1 end
    local preset = presets[choice]

    print("")
    local gui = askYesNo("Install the graphical interface (Basalt)? (y/n) [y]: ", true)

    print("")
    if not askYesNo("Confirm installation? (y/n): ") then
        print("Installation cancelled.")
        return nil
    end

    return {
        update = false,
        username = username,
        password = password or "",
        hostname = hostname,
        themeName = preset.name,
        accent = preset.accent,
        gui = gui,
    }
end

------------------------------------------------------------------
-- Basalt wizard
------------------------------------------------------------------

local function wizardBasalt(basalt, presets, mode)
    local result = nil -- nil = failed, false = cancelled, table = ok
    local accent = presets[1].accent

    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()
        local cx = math.floor(w / 2)

        if mode == "update" or mode == "recovery" then
            main:addLabel()
                :setText(mode == "recovery" and "NyxOS Recovery" or "NyxOS Update")
                :setForeground(accent)
                :setPosition(math.max(1, cx - 8), 2)

            main:addLabel()
                :setText("Current version: " .. getInstalledVersion())
                :setForeground(palette.white)
                :setPosition(2, 5)

            main:addLabel()
                :setText("New version: NyxOS " .. VERSION)
                :setForeground(palette.lightGray)
                :setPosition(2, 7)

            main:addLabel()
                :setText(mode == "recovery"
                    and "Repairs system files only. Users/config kept."
                    or "Users and configuration are preserved.")
                :setForeground(palette.gray)
                :setPosition(2, 10)

            main:addButton()
                :setText(mode == "recovery" and "Run recovery" or "Update")
                :setPosition(math.max(1, cx - 8), h - 4)
                :setSize(16, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(function()
                    result = { update = true, recovery = (mode == "recovery") }
                    basalt.stop()
                end)

            main:addButton()
                :setText("Cancel")
                :setPosition(math.max(1, cx - 8), h - 2)
                :setSize(16, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :onClick(function()
                    result = false
                    basalt.stop()
                end)
        else
            local y = 2
            main:addLabel()
                :setText("Installing NyxOS " .. VERSION)
                :setForeground(accent)
                :setPosition(math.max(1, cx - 10), y)
            y = y + 3

            main:addLabel()
                :setText("User (admin):")
                :setForeground(palette.white)
                :setPosition(2, y)
            local userInput = main:addInput()
                :setPosition(2, y + 1)
                :setSize(w - 4, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
            y = y + 3

            main:addLabel()
                :setText("Password (optional):")
                :setForeground(palette.white)
                :setPosition(2, y)
            local passInput = main:addInput()
                :setPosition(2, y + 1)
                :setSize(w - 4, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setReplaceChar("*")
            y = y + 3

            main:addLabel()
                :setText("Computer name:")
                :setForeground(palette.white)
                :setPosition(2, y)
            local hostInput = main:addInput()
                :setPosition(2, y + 1)
                :setSize(w - 4, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setText(tostring(os.getComputerLabel() or "nyxos"))
            y = y + 3

            main:addLabel()
                :setText("Accent colour:")
                :setForeground(palette.white)
                :setPosition(2, y)
            local themeList = main:addList()
                :setPosition(2, y + 1)
                :setSize(w - 4, math.min(#presets, 5))
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)
            for _, p in ipairs(presets) do
                themeList:addItem(p.name)
            end
            y = y + math.min(#presets, 5) + 1

            local guiCheckbox = main:addCheckBox()
                :setPosition(2, y)
                :setChecked(true)
                :setText("Install graphical interface (Basalt)")

            local selectedTheme = 1
            themeList:onSelect(function(self, index)
                selectedTheme = index
            end)

            local status = main:addLabel()
                :setText("Fill in the fields, then confirm.")
                :setForeground(palette.lightGray)
                :setPosition(2, h - 4)

            local function submit()
                local username = userInput:getText()
                if not username or username == "" then
                    status:setText("Username is required.")
                    return
                end
                local selected = selectedTheme
                if selected < 1 or selected > #presets then selected = 1 end
                local preset = presets[selected]
                local gui = true
                local okChk, checked = pcall(function() return guiCheckbox:getChecked() end)
                if okChk then gui = checked end
                result = {
                    update = false,
                    username = username,
                    password = passInput:getText() or "",
                    hostname = hostInput:getText() or "nyxos",
                    themeName = preset.name,
                    accent = preset.accent,
                    gui = gui,
                }
                basalt.stop()
            end

            main:addButton()
                :setText("Install")
                :setPosition(math.max(1, cx - 8), h - 2)
                :setSize(16, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(submit)

            userInput:setFocused(true)
        end

        basalt.run()
    end)

    if not ok then
        return nil
    end
    if result == false then
        return false
    end
    return result
end

------------------------------------------------------------------
-- Entry point
------------------------------------------------------------------

local function chooseTarget()
    local disks = findDisks()
    if #disks == 0 then
        return "" -- only the main computer is available
    end

    print("Install NyxOS on:")
    print("  1) This computer")
    for i, d in ipairs(disks) do
        print("  " .. (i + 1) .. ") Disk (" .. d.peripheralName .. ")")
    end
    write("Choice [1]: ")
    local choice = tonumber(read())
    if not choice or choice == 1 then
        return ""
    end
    local disk = disks[choice - 1]
    if not disk then
        return ""
    end
    return disk.mount
end

local function main()
    local dataDir = findDataDir()
    if not dataDir then
        print("Error: data/ folder not found.")
        print("Place install.lua and the data/ folder in the same directory.")
        return
    end

    setupScreen(dataDir)

    -- Only offer a choice of target for a brand new install -- updates
    -- and recovery always target the main computer's own existing
    -- install.
    local root = ""
    local freshInstall = not isInstalled("")
    if freshInstall then
        root = chooseTarget()
    end

    local alreadyInstalled = isInstalled(root)
    local mode = "install"
    if alreadyInstalled then
        mode = looksBroken(root) and "recovery" or "update"
    end

    local presets = loadThemePresets(dataDir)
    local basalt = loadBasalt(dataDir)

    local config
    if basalt then
        config = wizardBasalt(basalt, presets, mode)
        if config == false then
            print("Cancelled.")
            return
        end
    else
        print("Basalt unavailable, using text mode.")
    end
    if not config then
        config = wizardText(presets, mode)
    end

    if not config then
        return
    end

    -- A brand new install directly on the main computer wipes
    -- everything except /rom first, for a truly clean NyxOS -- never
    -- done for updates/recovery, and never for a disk install (which
    -- must not touch the computer's own files).
    if root == "" and not alreadyInstalled and not config.update then
        print("")
        print("WARNING: installing on this computer erases EVERYTHING on it")
        print("(except the built-in rom) before installing NyxOS.")
        write("Type 'yes' to confirm and continue: ")
        if read() ~= "yes" then
            print("Installation cancelled.")
            return
        end
        print("Formatting...")
        wipeExceptRom()
    end

    deployFiles(dataDir, root, config.update or alreadyInstalled)

    if not config.update and not alreadyInstalled then
        if not applyConfig(config, root) then
            return
        end
    end

    if root == "" and not config.update and not alreadyInstalled then
        installNyxLoader()
    end

    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
    if config.recovery then
        print("Recovery complete! NyxOS " .. VERSION .. " system files repaired.")
    elseif config.update or alreadyInstalled then
        print("Update complete! NyxOS " .. VERSION .. " is ready.")
    elseif root ~= "" then
        print("Installation complete on disk (" .. root .. ")!")
        print("First account: " .. config.username .. " (administrator)")
        print("Insert this disk into a computer running NyxLoader to boot it.")
    else
        print("Installation complete! NyxOS " .. VERSION .. " is ready.")
        print("First account: " .. config.username .. " (administrator)")
    end
    print("")
    print("Reboot the computer: reboot")
end

main()
