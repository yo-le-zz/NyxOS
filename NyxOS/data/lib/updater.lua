-- /lib/updater.lua : NyxOS update checker / installer
--
--   local updater = dofile("/lib/updater.lua")
--   local info, err = updater.check()        -- { current, latest, available, tag, repo }
--   updater.install(info.tag)                -- downloads that tag, then installs it
--
-- Settings (in /etc/nyx-config.lua):
--   updateRepo     "owner/name" of the GitHub repository   (default yo-le-zz/NyxOS)
--   autoUpdate     true: check in the background           (default true)
--   updateInterval hours between two checks                (default 24)
--
-- The state of the last check is kept in /etc/nyx-update.lua. An update
-- never touches /etc (users, config) or /home: the installer skips them.
-- All files are downloaded BEFORE anything is replaced (webinstall stops
-- on the first failure), so a broken connection leaves the system as it was.

local updater = {}

updater.DEFAULT_REPO = "yo-le-zz/NyxOS"
local STATE = "/etc/nyx-update.lua"

local function loadTable(path)
    if not fs.exists(path) or fs.isDir(path) then return {} end
    local ok, data = pcall(dofile, path)
    return (ok and type(data) == "table") and data or {}
end

local function saveTable(path, data)
    local f = fs.open(path, "w")
    if not f then return false end
    f.write("return " .. textutils.serialize(data))
    f.close()
    return true
end

function updater.config()
    local cfg = loadTable("/etc/nyx-config.lua")
    local repo = cfg.updateRepo
    if type(repo) ~= "string" or not repo:match("^[%w%-%._]+/[%w%-%._]+$") then repo = updater.DEFAULT_REPO end
    local interval = tonumber(cfg.updateInterval) or 24
    if interval < 1 then interval = 1 end
    return {
        repo = repo,
        auto = cfg.autoUpdate ~= false,
        interval = interval,
        raw = cfg,
    }
end

function updater.setConfig(key, value)
    local cfg = loadTable("/etc/nyx-config.lua")
    cfg[key] = value
    return saveTable("/etc/nyx-config.lua", cfg)
end

function updater.currentVersion()
    if fs.exists("/etc/nyx-release") then
        local f = fs.open("/etc/nyx-release", "r")
        local line = f and f.readLine() or ""
        if f then f.close() end
        local v = tostring(line):match("(%d+%.%d+%.%d+)")
        if v then return v end
    end
    return "0.0.0"
end

local function parse(v)
    local a, b, c = tostring(v):match("(%d+)%.(%d+)%.(%d+)")
    return { tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0 }
end

-- -1 if a < b, 0 if equal, 1 if a > b
function updater.compare(a, b)
    local x, y = parse(a), parse(b)
    for i = 1, 3 do
        if x[i] < y[i] then return -1 end
        if x[i] > y[i] then return 1 end
    end
    return 0
end

local function get(url)
    if not http then return nil, "HTTP is disabled (http_enable=true in the CC config)" end
    local r, reason, failed = http.get(url, { ["User-Agent"] = "NyxOS-Updater", ["Accept"] = "application/vnd.github+json" })
    if not r then
        if failed then
            local code = failed.getResponseCode and failed.getResponseCode()
            failed.close()
            return nil, "HTTP " .. tostring(code or reason)
        end
        return nil, tostring(reason or "request failed")
    end
    local body = r.readAll()
    r.close()
    if not body or body == "" then return nil, "empty response" end
    return body
end
updater._get = get

-- Highest X.Y.Z tag of the repository (tags look like 1.3.0; a leading "v" is tolerated)
function updater.latestTag(repo)
    local body, err = get("https://api.github.com/repos/" .. repo .. "/tags?per_page=100")
    if not body then return nil, err end
    local data = textutils.unserialiseJSON and textutils.unserialiseJSON(body)
    if type(data) ~= "table" then return nil, "unreadable answer from GitHub" end
    local best, bestTag
    for _, entry in ipairs(data) do
        local name = type(entry) == "table" and entry.name
        local v = type(name) == "string" and name:match("^v?(%d+%.%d+%.%d+)$")
        if v and (not best or updater.compare(v, best) > 0) then best, bestTag = v, name end
    end
    if not best then return nil, "no version tag (X.Y.Z) in " .. repo end
    return best, bestTag
end

function updater.state()
    return loadTable(STATE)
end

-- force: ignore the interval. Returns info table, or nil + error.
function updater.check(force)
    local cfg = updater.config()
    local state = updater.state()
    local now = os.epoch and os.epoch("utc") or 0
    local current = updater.currentVersion()
    if not force and state.checkedAt and state.repo == cfg.repo
        and now - state.checkedAt < cfg.interval * 3600000 and state.latest then
        return {
            current = current, latest = state.latest, tag = state.tag, repo = cfg.repo,
            available = updater.compare(state.latest, current) > 0, cached = true,
        }
    end
    local latest, tag = updater.latestTag(cfg.repo)
    if not latest then return nil, tag end
    saveTable(STATE, { checkedAt = now, repo = cfg.repo, latest = latest, tag = tag })
    return {
        current = current, latest = latest, tag = tag, repo = cfg.repo,
        available = updater.compare(latest, current) > 0,
    }
end

-- Downloads webinstall.lua of that tag and runs it (it downloads every file
-- first, then runs the installer in update mode).
function updater.install(tag)
    local cfg = updater.config()
    tag = tag or (updater.state().tag)
    if not tag then return false, "no version selected (run: nyxupdate check)" end
    local free = fs.getFreeSpace and fs.getFreeSpace("/") or math.huge
    local needed = 0
    for _, dir in ipairs({ "/lib", "/bin" }) do
        if fs.exists(dir) then
            local function size(p)
                if fs.isDir(p) then
                    local n = 0
                    for _, name in ipairs(fs.list(p)) do n = n + size(fs.combine(p, name)) end
                    return n
                end
                return fs.getSize(p)
            end
            needed = needed + size(dir)
        end
    end
    if free < needed then
        return false, string.format("not enough free space: %d bytes free, about %d needed (free some room: apt remove unused packages)", free, needed)
    end
    local body, err = get("https://raw.githubusercontent.com/" .. cfg.repo .. "/" .. tag .. "/webinstall.lua")
    if not body then return false, "cannot download the installer: " .. tostring(err) end
    local f = fs.open("/webinstall.lua", "w")
    if not f then return false, "cannot write /webinstall.lua" end
    f.write(body)
    f.close()
    if not shell then return false, "must run inside a shell" end
    local ok, runErr = pcall(shell.run, "/webinstall.lua", cfg.repo, tag)
    if not ok then return false, tostring(runErr) end
    return true
end

return updater
