-- /lib/nyxlib.lua
-- Utility functions shared across NyxOS

local nyxlib = {}

local MANIFEST_PATH = "/etc/apt/installed.lua"
local PASSWD_PATH = "/etc/passwd"
local SESSION_PATH = "/var/run/session.lua"

-- Generic read/write of serialised tables (used by the apt manifest,
-- /etc/passwd, the display config, etc.)
function nyxlib.loadTable(path)
    if not fs.exists(path) then
        return {}
    end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

function nyxlib.saveTable(path, data)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(data))
    f.close()
end

function nyxlib.loadManifest()
    return nyxlib.loadTable(MANIFEST_PATH)
end

function nyxlib.saveManifest(manifest)
    nyxlib.saveTable(MANIFEST_PATH, manifest)
end

-- Session: which user is currently logged in (written by /lib/login.lua
-- at boot). Volatile file, cleared on shutdown (lives in /var/run like
-- boot.time).
function nyxlib.loadSession()
    return nyxlib.loadTable(SESSION_PATH)
end

function nyxlib.saveSession(username)
    if not fs.exists("/var/run") then
        fs.makeDir("/var/run")
    end
    nyxlib.saveTable(SESSION_PATH, { username = username })
end

function nyxlib.clearSession()
    if fs.exists(SESSION_PATH) then
        fs.delete(SESSION_PATH)
    end
end

-- Compatibility: /etc/passwd now holds a LIST of users (see
-- /lib/users.lua). These two functions are still provided for commands
-- that only care about "the current user" (whoami, passwd, neofetch,
-- ...): they return/update the currently logged in user (or, absent a
-- session, the system's first account).
function nyxlib.loadPasswd()
    local ok, users = pcall(dofile, "/lib/users.lua")
    if not ok or not users then
        return nyxlib.loadTable(PASSWD_PATH)
    end
    local session = nyxlib.loadSession()
    if session.username then
        local u = users.find(session.username)
        if u then
            return u
        end
    end
    local list = users.load()
    return list[1] or {}
end

function nyxlib.savePasswd(passwd)
    local ok, users = pcall(dofile, "/lib/users.lua")
    if ok and users and passwd and passwd.username then
        local list = users.load()
        local found = false
        for i, u in ipairs(list) do
            if u.username == passwd.username then
                list[i] = passwd
                found = true
                break
            end
        end
        if not found then
            table.insert(list, passwd)
        end
        users.save(list)
        return
    end
    nyxlib.saveTable(PASSWD_PATH, passwd)
end

-- Reads /etc/hostname (plain text file, not serialised)
function nyxlib.getHostname()
    if not fs.exists("/etc/hostname") then
        return "nyxos"
    end
    local f = fs.open("/etc/hostname", "r")
    local name = f.readAll()
    f.close()
    return (name:gsub("%s+$", ""))
end

function nyxlib.setHostname(name)
    local f = fs.open("/etc/hostname", "w")
    f.write(name)
    f.close()
end

-- Formats a byte count into human-readable KB/MB/GB
-- Command that starts an installed package, or nil for a library.
-- Uses the `launch` field of app.json when the package declares one,
-- otherwise guesses from the installed files (older registry entries).
function nyxlib.launcherFor(name, entry)
    if type(entry) ~= "table" or entry.removed then return nil end
    if type(entry.launch) == "string" and entry.launch ~= "" then return entry.launch end
    local base = tostring(name):gsub("%-client$", ""):gsub("%-server$", "")
    for _, b in ipairs({ tostring(name), base }) do
        for _, p in ipairs({ "/bin/" .. b .. ".lua", "/" .. b .. ".lua" }) do
            if fs.exists(p) then return p end
        end
    end
    local best
    for _, f in ipairs(entry.files or {}) do
        if type(f) == "string" and f:match("%.lua$") and fs.exists(f)
            and (f:match("^/bin/[^/]+$") or f:match("^/[^/]+$")) then
            if f:find("client", 1, true) or f:find(base, 1, true) then return f end
            best = best or f
        end
    end
    return best
end

function nyxlib.formatSize(bytes)
    if not bytes then
        return "?"
    end
    local units = { "B", "KB", "MB", "GB" }
    local i = 1
    while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
    end
    return string.format("%.1f%s", bytes, units[i])
end

-- Whether the graphical interface should be used at all. Set at
-- install time (see install.lua's GUI checkbox); defaults to true when
-- unset so existing installs keep behaving as before.
function nyxlib.guiEnabled()
    if not fs.exists("/etc/nyx-config.lua") then
        return true
    end
    local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
    if cfg.gui == nil then
        return true
    end
    return cfg.gui and true or false
end

-- Loads Basalt from several possible locations (installed, data/
-- floppy, or a relative fallback).
function nyxlib.loadBasalt(extraPaths)
    if not nyxlib.guiEnabled() then
        return nil
    end
    local paths = {}
    if extraPaths then
        for _, p in ipairs(extraPaths) do
            table.insert(paths, p)
        end
    end
    table.insert(paths, "/lib/basalt.lua")
    table.insert(paths, "data/lib/basalt.lua")
    table.insert(paths, "disk/data/lib/basalt.lua")
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local ok, mod = pcall(dofile, path)
            if ok and type(mod) == "table" and mod.getMainFrame then
                local bridgeOk, bridge = pcall(dofile, "/lib/monitorbridge.lua")
                if bridgeOk and bridge then
                    pcall(bridge.patch, mod)
                end
                return mod
            end
        end
    end
    return nil
end

function nyxlib.isInstalled()
    return fs.exists("/etc/nyx-release") or fs.exists("/nyxos.lua")
end

------------------------------------------------------------------
-- /dev special files (null, zero) -- CC:Tweaked has no real character
-- devices, so this wraps fs.open once at boot to fake the two most
-- commonly used ones. Every other path behaves exactly as before.
------------------------------------------------------------------
local devFsInstalled = false

local function nullHandle()
    return {
        write = function() end,
        writeLine = function() end,
        close = function() end,
        readAll = function() return "" end,
        readLine = function() return nil end,
        read = function(n)
            if n then return "" end
            return nil
        end,
    }
end

local function zeroHandle()
    return {
        write = function() end,
        writeLine = function() end,
        close = function() end,
        readAll = function() return string.rep("\0", 4096) end,
        readLine = function() return string.rep("\0", 256) end,
        read = function(n)
            if n then return string.rep("\0", n) end
            return 0
        end,
    }
end

function nyxlib.installDevFs()
    if devFsInstalled then return end
    devFsInstalled = true

    if not fs.exists("/dev") then
        fs.makeDir("/dev")
    end

    local originalOpen = fs.open
    fs.open = function(path, mode)
        local resolved = "/" .. fs.combine("", path)
        if resolved == "/dev/null" then
            return nullHandle()
        elseif resolved == "/dev/zero" and (mode == "r" or mode == "rb" or mode == nil) then
            return zeroHandle()
        end
        return originalOpen(path, mode)
    end
end

return nyxlib
