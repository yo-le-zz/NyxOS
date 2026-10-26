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
    "data/startup.lua",
    "data/etc/motd",
    "data/lib/basalt.lua",
    "data/lib/capture.lua",
    "data/lib/crypto.lua",
    "data/lib/db.lua",
    "data/lib/desktop.lua",
    "data/lib/display.lua",
    "data/lib/login.lua",
    "data/lib/logger.lua",
    "data/lib/machineid.lua",
    "data/lib/monitorbridge.lua",
    "data/lib/network.lua",
    "data/lib/nyxapi.lua",
    "data/lib/nyxscript.lua",
    "data/lib/nyxlib.lua",
    "data/lib/permissions.lua",
    "data/lib/procui.lua",
    "data/lib/services.lua",
    "data/lib/specs.lua",
    "data/lib/services/heartbeat.lua",
    "data/lib/shellui.lua",
    "data/lib/theme.lua",
    "data/lib/tmp.lua",
    "data/lib/toolkit.lua",
    "data/lib/users.lua",
    "data/bin/adduser.lua",
    "data/bin/apt.lua",
    "data/bin/bg.lua",
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
    "data/bin/find.lua",
    "data/bin/grep.lua",
    "data/bin/guimode.lua",
    "data/bin/head.lua",
    "data/bin/hostname.lua",
    "data/bin/jobs.lua",
    "data/bin/kill.lua",
    "data/bin/killall.lua",
    "data/bin/logs.lua",
    "data/bin/machineid.lua",
    "data/bin/man.lua",
    "data/bin/mkpkg.lua",
    "data/bin/neofetch.lua",
    "data/bin/net.lua",
    "data/bin/newterm.lua",
    "data/bin/nyx.lua",
    "data/bin/passwd.lua",
    "data/bin/pkill.lua",
    "data/bin/ps.lua",
    "data/bin/pwd.lua",
    "data/bin/reboot.lua",
    "data/bin/recovery.lua",
    "data/bin/reset.lua",
    "data/bin/rm.lua",
    "data/bin/service.lua",
    "data/bin/shutdown.lua",
    "data/bin/specs.lua",
    "data/bin/sudo.lua",
    "data/bin/tail.lua",
    "data/bin/testbasalt.lua",
    "data/bin/top.lua",
    "data/bin/touch.lua",
    "data/bin/tree.lua",
    "data/bin/uname.lua",
    "data/bin/uninstall.lua",
    "data/bin/uptime.lua",
    "data/bin/users.lua",
    "data/bin/wc.lua",
    "data/bin/wget.lua",
    "data/bin/whoami.lua",
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
