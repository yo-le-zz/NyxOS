-- /bin/recovery.lua : repairs NyxOS system files without touching users,
-- configuration, installed-package records or /home. Downloads a fresh
-- copy of /bin, /lib, /nyxos.lua and /etc/motd straight from the GitHub
-- repository (same source as webinstall.lua). It can also be run from the
-- recovery shell if NyxOS itself is too damaged to boot normally.
-- Usage: recovery
--
-- Each file is downloaded completely BEFORE the old one is replaced, so a
-- network error half way never leaves a truncated system file behind.
-- (NyxOS's boot file is /nyxos.lua; /startup.lua belongs to NyxLoader or
-- to you and is never touched.)

local REPO_BASE = "https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/NyxOS"

-- Keep this list in sync with webinstall.lua / install.lua.
-- Not repaired on purpose (they are user data): /etc/apt/installed.lua,
-- /etc/services/*.lua, /etc/passwd, /etc/theme...
local FILES = {
    "data/bin/adduser.lua",
    "data/bin/apps.lua",
    "data/bin/apt.lua",
    "data/bin/bg.lua",
    "data/bin/calc.lua",
    "data/bin/cat.lua",
    "data/bin/curl.lua",
    "data/bin/date.lua",
    "data/bin/db.lua",
    "data/bin/dd.lua",
    "data/bin/deluser.lua",
    "data/bin/desktop.lua",
    "data/bin/df.lua",
    "data/bin/diagbasalt.lua",
    "data/bin/display.lua",
    "data/bin/echo.lua",
    "data/bin/encrypt.lua",
    "data/bin/env.lua",
    "data/bin/export.lua",
    "data/bin/find.lua",
    "data/bin/free.lua",
    "data/bin/grep.lua",
    "data/bin/guimode.lua",
    "data/bin/head.lua",
    "data/bin/hostname.lua",
    "data/bin/hosts.lua",
    "data/bin/ifconfig.lua",
    "data/bin/jobs.lua",
    "data/bin/kill.lua",
    "data/bin/killall.lua",
    "data/bin/lang.lua",
    "data/bin/logs.lua",
    "data/bin/machineid.lua",
    "data/bin/man.lua",
    "data/bin/mkpkg.lua",
    "data/bin/neofetch.lua",
    "data/bin/net.lua",
    "data/bin/netstat.lua",
    "data/bin/newterm.lua",
    "data/bin/nslookup.lua",
    "data/bin/nyx.lua",
    "data/bin/nyxcert.lua",
    "data/bin/nyxupdate.lua",
    "data/bin/passwd.lua",
    "data/bin/ping.lua",
    "data/bin/pkill.lua",
    "data/bin/printenv.lua",
    "data/bin/profile.lua",
    "data/bin/ps.lua",
    "data/bin/pwd.lua",
    "data/bin/reboot.lua",
    "data/bin/recovery.lua",
    "data/bin/reset.lua",
    "data/bin/resources.lua",
    "data/bin/rm.lua",
    "data/bin/service.lua",
    "data/bin/shutdown.lua",
    "data/bin/sleep.lua",
    "data/bin/specs.lua",
    "data/bin/sudo.lua",
    "data/bin/tail.lua",
    "data/bin/testbasalt.lua",
    "data/bin/top.lua",
    "data/bin/touch.lua",
    "data/bin/tree.lua",
    "data/bin/uname.lua",
    "data/bin/uninstall.lua",
    "data/bin/unset.lua",
    "data/bin/uptime.lua",
    "data/bin/users.lua",
    "data/bin/wc.lua",
    "data/bin/web.lua",
    "data/bin/wget.lua",
    "data/bin/whoami.lua",
    "data/etc/apt/installed.lua",
    "data/etc/lang/de.lua",
    "data/etc/lang/es.lua",
    "data/etc/lang/fr.lua",
    "data/etc/motd",
    "data/etc/services/dhcpd.lua",
    "data/etc/services/dns.lua",
    "data/etc/services/heartbeat.lua",
    "data/etc/services/httpd.lua",
    "data/etc/services/netd.lua",
    "data/lib/apps/browser.lua",
    "data/lib/apps/calculator.lua",
    "data/lib/apps/calendar.lua",
    "data/lib/apps/clock.lua",
    "data/lib/apps/editor.lua",
    "data/lib/apps/files.lua",
    "data/lib/apps/game2048.lua",
    "data/lib/apps/globe.lua",
    "data/lib/apps/logs.lua",
    "data/lib/apps/minesweeper.lua",
    "data/lib/apps/monitor.lua",
    "data/lib/apps/notes.lua",
    "data/lib/apps/packages.lua",
    "data/lib/apps/paint.lua",
    "data/lib/apps/settings.lua",
    "data/lib/apps/snake.lua",
    "data/lib/apps/tasks.lua",
    "data/lib/apps/terminal.lua",
    "data/lib/basalt.lua",
    "data/lib/canvas.lua",
    "data/lib/capture.lua",
    "data/lib/crypto.lua",
    "data/lib/db.lua",
    "data/lib/desktop.lua",
    "data/lib/display.lua",
    "data/lib/env.lua",
    "data/lib/i18n.lua",
    "data/lib/icon.lua",
    "data/lib/installui.lua",
    "data/lib/logger.lua",
    "data/lib/login.lua",
    "data/lib/machineid.lua",
    "data/lib/mathexpr.lua",
    "data/lib/monitorbridge.lua",
    "data/lib/netstack.lua",
    "data/lib/network.lua",
    "data/lib/nyxapi.lua",
    "data/lib/nyxhttp.lua",
    "data/lib/nyxlib.lua",
    "data/lib/nyxscript.lua",
    "data/lib/permissions.lua",
    "data/lib/procui.lua",
    "data/lib/profile.lua",
    "data/lib/resources.lua",
    "data/lib/serverui.lua",
    "data/lib/services.lua",
    "data/lib/services/dhcpd.lua",
    "data/lib/services/dns.lua",
    "data/lib/services/heartbeat.lua",
    "data/lib/services/httpd.lua",
    "data/lib/services/netd.lua",
    "data/lib/shellui.lua",
    "data/lib/specs.lua",
    "data/lib/theme.lua",
    "data/lib/tmp.lua",
    "data/lib/toolkit.lua",
    "data/lib/updater.lua",
    "data/lib/users.lua",
    "data/lib/vm.lua",
    "data/lib/wallpaper.lua",
    "data/startup.lua",
}

-- Where each file goes on the computer.
local function destination(relative)
    if relative == "data/startup.lua" then
        return "/nyxos.lua"
    end
    return "/" .. relative:gsub("^data/", "")
end

if not http then
    print("recovery: the http API is not enabled on this computer.")
    print("Use install.lua from a local copy of the NyxOS repo instead.")
    return
end

print("=== NyxOS Recovery ===")
print("This re-downloads system files (/bin, /lib, /nyxos.lua) from")
print("github.com/yo-le-zz/NyxOS. Users, config and /home are untouched.")
write("Continue? (y/n): ")
if read() ~= "y" then
    print("Cancelled.")
    return
end

local ok, failed = 0, 0
for _, relative in ipairs(FILES) do
    local url = REPO_BASE .. "/" .. (relative:gsub(" ", "%%20"))
    local destPath = destination(relative)
    local response, err = http.get(url)
    local body = response and response.readAll()
    if response then response.close() end

    if body and body ~= "" then
        local dir = fs.getDir(destPath)
        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end
        local f = fs.open(destPath, "wb")
        if f then
            f.write(body)
            f.close()
            ok = ok + 1
            print("  repaired " .. destPath)
        else
            failed = failed + 1
            print("  FAILED   " .. destPath .. " (cannot write)")
        end
    else
        failed = failed + 1
        print("  FAILED   " .. destPath .. " (" .. tostring(err or "empty response") .. ")")
    end
end

print("")
print("Recovery done: " .. ok .. " file(s) repaired, " .. failed .. " failed.")
if failed == 0 then
    print("Reboot the computer: reboot")
end
