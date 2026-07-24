-- /bin/recovery.lua : repairs NyxOS system files without touching users,
-- configuration, or /home. Downloads a fresh copy of /bin, /lib,
-- /startup.lua and /etc/motd straight from the GitHub repository (same
-- source as webinstall.lua), and can also be run from the recovery
-- shell if NyxOS itself is too damaged to boot normally.
-- Usage: recovery

local REPO_BASE = "https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/NyxOS"

local FILES = {
    "data/startup.lua",
    "data/etc/motd",
    "data/lib/basalt.lua",
    "data/lib/crypto.lua",
    "data/lib/db.lua",
    "data/lib/display.lua",
    "data/lib/login.lua",
    "data/lib/logger.lua",
    "data/lib/machineid.lua",
    "data/lib/monitorbridge.lua",
    "data/lib/network.lua",
    "data/lib/nyxapi.lua",
    "data/lib/nyxlib.lua",
    "data/lib/permissions.lua",
    "data/lib/services.lua",
    "data/lib/shellui.lua",
    "data/lib/theme.lua",
    "data/lib/tmp.lua",
    "data/lib/toolkit.lua",
    "data/lib/users.lua",
    "data/bin/adduser.lua",
    "data/bin/apt.lua",
    "data/bin/cat.lua",
    "data/bin/curl.lua",
    "data/bin/date.lua",
    "data/bin/db.lua",
    "data/bin/deluser.lua",
    "data/bin/df.lua",
    "data/bin/diagbasalt.lua",
    "data/bin/display.lua",
    "data/bin/echo.lua",
    "data/bin/encrypt.lua",
    "data/bin/find.lua",
    "data/bin/grep.lua",
    "data/bin/head.lua",
    "data/bin/hostname.lua",
    "data/bin/logs.lua",
    "data/bin/machineid.lua",
    "data/bin/man.lua",
    "data/bin/mkpkg.lua",
    "data/bin/net.lua",
    "data/bin/neofetch.lua",
    "data/bin/newterm.lua",
    "data/bin/passwd.lua",
    "data/bin/pwd.lua",
    "data/bin/reboot.lua",
    "data/bin/reset.lua",
    "data/bin/service.lua",
    "data/bin/shutdown.lua",
    "data/bin/sudo.lua",
    "data/bin/tail.lua",
    "data/bin/testbasalt.lua",
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

if not http then
    print("recovery: the http API is not enabled on this computer.")
    print("Use install.lua from a local copy of the NyxOS repo instead.")
    return
end

print("=== NyxOS Recovery ===")
print("This re-downloads system files (/bin, /lib, /startup.lua) from")
print("github.com/yo-le-zz/NyxOS. Users, config and /home are untouched.")
write("Continue? (y/n): ")
if read() ~= "y" then
    print("Cancelled.")
    return
end

local ok, failed = 0, 0
for _, relative in ipairs(FILES) do
    local url = REPO_BASE .. "/" .. relative
    local destPath = "/" .. relative:gsub("^data/", "")
    local response, err = http.get(url)
    if response then
        local body = response.readAll()
        response.close()
        local dir = fs.getDir(destPath)
        if dir ~= "" and not fs.exists(dir) then
            fs.makeDir(dir)
        end
        local f = fs.open(destPath, "w")
        f.write(body)
        f.close()
        ok = ok + 1
        print("  repaired " .. destPath)
    else
        failed = failed + 1
        print("  FAILED   " .. destPath .. " (" .. tostring(err) .. ")")
    end
end

print("")
print("Recovery done: " .. ok .. " file(s) repaired, " .. failed .. " failed.")
if failed == 0 then
    print("Reboot the computer: reboot")
end
