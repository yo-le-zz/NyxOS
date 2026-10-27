-- /nyxos.lua : NyxOS boot script (runs on every boot)
--
-- Installed as /nyxos.lua and described by /boot.json; NyxLoader (or the
-- minimal fallback /startup.lua written by the installer) starts it.

------------------------------------------------------------------
-- 1) Make sure a REAL CraftOS shell is available
------------------------------------------------------------------
-- NyxOS needs the full shell API (shell.run with PATH lookup,
-- shell.setPath, shell.resolveProgram, shell.setDir...). That API only
-- exists inside a program started by /rom/programs/shell.lua. NyxLoader
-- starts the OS through a tiny stand-in `shell` global that only knows
-- run()/dir()/resolve(), so the very first call below
-- (shell.setPath) used to crash the boot with
-- "attempt to call field 'setPath' (a nil value)".
local function isRealShell(sh)
    return type(sh) == "table"
        and type(sh.setPath) == "function"
        and type(sh.path) == "function"
        and type(sh.aliases) == "function"
        and type(sh.resolveProgram) == "function"
end

if not isRealShell(shell) then
    if _G.NYXOS_SHELL_BOOTSTRAP then
        error("NyxOS: could not start a CraftOS shell (/rom/programs/shell.lua).", 0)
    end
    -- Re-run this very file inside a genuine shell. The stand-in global
    -- is hidden meanwhile so shell.lua does not mistake it for a parent
    -- shell (it would call parent.path()/aliases(), which it lacks), and
    -- put back afterwards for whoever started us.
    _G.NYXOS_SHELL_BOOTSTRAP = true
    local standIn = _G.shell
    _G.shell = nil
    local ok, err = pcall(os.run, {}, "/rom/programs/shell.lua", "/nyxos.lua")
    _G.shell = standIn
    _G.NYXOS_SHELL_BOOTSTRAP = nil
    if not ok then
        error(err, 0)
    end
    return
end

-- Libraries loaded with dofile() (/lib/shellui.lua, /lib/desktop.lua,
-- /lib/nyxscript.lua...) run in the GLOBAL environment, where `shell` is
-- not defined (only programs started by the shell get it). Publish it so
-- they can run commands, and put the previous value back when we leave.
local previousShell, previousMultishell = _G.shell, _G.multishell
_G.shell = shell
if multishell then _G.multishell = multishell end

-- NyxOS commands take priority over any same-named ROM program (needed
-- so our own /bin/shutdown.lua, /bin/reboot.lua, etc. are the ones that
-- actually run). Not added twice if this script is started again.
if not (":" .. shell.path() .. ":"):find(":/bin:", 1, true) then
    shell.setPath("/bin:" .. shell.path())
end

-- `command &` runs the command as a background job (see /lib/services.lua).
-- Wrapped once, on the shell API table, so it works for the plain shell,
-- the graphical shell and the desktop terminal alike.
if not shell._nyxBackground then
    local originalRun = shell.run
    shell.run = function(...)
        local line = table.concat({ ... }, " ")
        local body = line:match("^(.-)%s*&%s*$")
        if body and body:match("%S") then
            local okSvc, svc = pcall(dofile, "/lib/services.lua")
            if okSvc and svc and svc.scheduler() then
                local pid, err = svc.spawn({ cmd = body })
                if pid then
                    print("[" .. pid .. "] " .. (body:match("^%s*(%S+)") or body) .. " running in the background")
                    return true
                end
                printError("background: " .. tostring(err))
                return false
            end
            printError("background jobs need the NyxOS scheduler (boot normally).")
            return false
        end
        return originalRun(...)
    end
    shell._nyxBackground = true
end

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

    if uiMode == "server" then
        -- Headless-style server: plain text shell, services keep running
        -- in the background (see runWithShell).
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        print("NyxOS server mode - services running in the background (ps, service).")
        shell.run("shell")
        return
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
        shell.run("shell")
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

-- Leaving NyxOS (not normally reached: shutdown/reboot end the session).
_G.shell, _G.multishell = previousShell, previousMultishell
