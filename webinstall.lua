-- webinstall.lua : NyxOS web installer
-- Usage: wget https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/webinstall.lua webinstall.lua && webinstall
--
-- Downloads install.lua and the data/ folder from GitHub, then runs the
-- installer/updater if NyxOS is already present.

local VERSION = "1.0.1"
local REPO_BASE = "https://raw.githubusercontent.com/yo-le-zz/NyxOS/main/NyxOS"
local palette = colors or colours

-- Files to download (relative to NyxOS/)
local FILES = {
    "install.lua",
    "data/startup.lua",
    "data/etc/motd",
    "data/etc/apt/installed.lua",
    "data/etc/services/heartbeat.lua",
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
    "data/lib/services/heartbeat.lua",
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
    "data/bin/guimode.lua",
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
    "data/bin/recovery.lua",
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

local function isInstalled()
    return fs.exists("/etc/nyx-release") or fs.exists("/startup.lua")
end

local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function download(url)
    local response = http.get(url, {
        ["User-Agent"] = "NyxOS-WebInstall/" .. VERSION,
    })
    if not response then
        return nil, "HTTP unavailable (check http_enable=true in the config)"
    end
    local code = response.getResponseCode and response.getResponseCode() or 200
    if code < 200 or code >= 300 then
        response.close()
        return nil, "HTTP " .. tostring(code) .. " for " .. url
    end
    local body = response.readAll()
    response.close()
    if not body or body == "" then
        return nil, "Empty response for " .. url
    end
    return body
end

local function downloadFile(relPath, destPath)
    local url = REPO_BASE .. "/" .. relPath:gsub(" ", "%%20")
    local body, err = download(url)
    if not body then
        return false, err
    end
    ensureDir(fs.getDir(destPath))
    if fs.exists(destPath) then
        fs.delete(destPath)
    end
    local f = fs.open(destPath, "w")
    f.write(body)
    f.close()
    return true
end

local function main()
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)

    if not http then
        print("Error: HTTP unavailable.")
        print("Enable http_enable=true in the CC: Tweaked config.")
        return
    end

    local updateMode = isInstalled()
    if updateMode then
        print("=== NyxOS web update ===")
        print("NyxOS is already installed. Downloading version " .. VERSION .. "...")
    else
        print("=== NyxOS web install ===")
        print("Downloading version " .. VERSION .. "...")
    end
    print("")

    local okCount = 0
    local failCount = 0
    for _, relPath in ipairs(FILES) do
        local destPath = relPath
        write("  " .. relPath .. " ... ")
        local ok, err = downloadFile(relPath, destPath)
        if ok then
            print("OK")
            okCount = okCount + 1
        else
            print("FAILED")
            print("    " .. tostring(err))
            failCount = failCount + 1
        end
    end

    print("")
    if failCount > 0 then
        print("Partial download: " .. okCount .. " OK, " .. failCount .. " failure(s).")
        print("Check your connection and re-run webinstall.")
        return
    end

    print("Download complete (" .. okCount .. " files).")
    print("")
    if updateMode then
        print("Starting the update...")
    else
        print("Starting the installation...")
    end
    print("")

    shell.run("install")
end

main()
