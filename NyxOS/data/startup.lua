-- /startup.lua : NyxOS boot script (runs on every boot)

-- NyxOS commands take priority over any same-named ROM program (needed
-- so our own /bin/shutdown.lua, /bin/reboot.lua, etc. are the ones that
-- actually run).
shell.setPath("/bin:" .. shell.path())

-- Fake /dev/null and /dev/zero (see /lib/nyxlib.lua)
local nyxlibEarlyOk, nyxlibEarly = pcall(dofile, "/lib/nyxlib.lua")
if nyxlibEarlyOk and nyxlibEarly then
    pcall(nyxlibEarly.installDevFs)
end

-- Ensures /var/tmp and /var/apt/tmp exist (see /bin/shutdown.lua for the
-- matching cleanup on the way out).
pcall(function() dofile("/lib/tmp.lua").ensure() end)

-- Generates the persistent machine identity on first boot.
pcall(function() dofile("/lib/machineid.lua").get() end)

-- Redirects display to a connected screen (monitor), if one is found,
-- regardless of which side or network name it's on (automatic position
-- detection), and adapts the text scale for Advanced Monitor (colour)
-- vs standard Monitor. If no screen is detected, NyxOS continues
-- normally on the computer's native screen.
local displayOk, nyxdisplay = pcall(dofile, "/lib/display.lua")
if displayOk and nyxdisplay then
    pcall(nyxdisplay.setup, true)
end

-- Records the boot time for the "uptime" command
if not fs.exists("/var/run") then
    fs.makeDir("/var/run")
end
local bootFile = fs.open("/var/run/boot.time", "w")
bootFile.write(tostring(os.epoch("utc")))
bootFile.close()

local loggerOk, logger = pcall(dofile, "/lib/logger.lua")
if loggerOk and logger then
    pcall(logger.info, "boot", "NyxOS starting up")
end

-- Boot menu + login (CloverOS-style). Everything happens in
-- /lib/login.lua with Basalt and an automatic text fallback: if
-- anything fails here, the computer still reaches the shell instead of
-- getting stuck.
local mode = "boot"
local loginOk, nyxlogin = pcall(dofile, "/lib/login.lua")
if loginOk and nyxlogin then
    local menuOk, menuChoice = pcall(nyxlogin.bootMenu)
    if menuOk and menuChoice then
        mode = menuChoice
    end

    if mode == "recovery" then
        term.setBackgroundColor((colors or colours).black)
        term.clear()
        term.setCursorPos(1, 1)
        print("=== NyxOS recovery shell (no login) ===")
        print("Type 'recovery' to repair system files, or 'shell' for the")
        print("plain CraftOS shell if NyxOS itself won't load.")
    else
        local authOk, username = pcall(nyxlogin.authenticate)
        if authOk and username then
            local nyxlib = dofile("/lib/nyxlib.lua")
            nyxlib.saveSession(username)
            local user = dofile("/lib/users.lua").find(username)
            if user and user.home and fs.exists(user.home) then
                pcall(shell.setDir, user.home)
            end
        end
    end
end

if fs.exists("/etc/motd") then
    local f = fs.open("/etc/motd", "r")
    print(f.readAll())
    f.close()
end

-- The actual interactive shell: graphical (Basalt) with an automatic
-- text fallback if it's unavailable/disabled.
local function runInteractiveShell()
    local nyxlibOk, nyxlibForUi = pcall(dofile, "/lib/nyxlib.lua")
    local uiMode = "shell"
    if nyxlibOk and nyxlibForUi then
        local cfg = nyxlibForUi.loadTable("/etc/nyx-config.lua")
        uiMode = cfg.uiMode or "shell"
    end

    if uiMode == "desktop" then
        local desktopOk, desktop = pcall(dofile, "/lib/desktop.lua")
        if desktopOk and desktop then
            local runOk, success = pcall(desktop.run)
            if runOk and success then
                return
            end
        end
        -- Desktop unavailable/crashed: fall through to the standard
        -- graphical shell below instead of getting stuck.
    end

    local shelluiOk, shellui = pcall(dofile, "/lib/shellui.lua")
    if shelluiOk and shellui then
        local runOk, success = pcall(shellui.run)
        if not runOk or success == false then
            shellui.runTextFallback()
        end
    else
        shell.run("/bin/shell")
    end
end

-- Runs the shell alongside every autostart service (a tiny init system
-- -- see /lib/services.lua). If the service manager itself fails to
-- load for any reason, fall back to just running the shell directly so
-- boot never gets stuck.
local servicesOk, services = pcall(dofile, "/lib/services.lua")
if servicesOk and services then
    local ok, err = pcall(services.runWithShell, runInteractiveShell)
    if not ok then
        runInteractiveShell()
    end
else
    runInteractiveShell()
end
