-- /lib/resources.lua : adapts NyxOS to the storage it actually has
--
-- The capacity of the computer can change after the installation (a bigger
-- `computerSpaceLimit` in the CC:Tweaked config, an upgraded server...).
-- Nothing is decided at install time: every limit below is computed from
-- the *current* capacity and free space, and re-read every 30 seconds.
--
--   local res = dofile("/lib/resources.lua")
--   local b = res.budget()      -- { tier = "tiny", logMax = 40960, shellLines = 300, ... }
--   res.pressure()              -- "ok" | "low" | "critical"  (free space left)
--   res.cleanup()               -- frees caches / temporary files, returns bytes freed
--
-- Tiers by capacity: tiny (< 2 MB, the CC default is 1 MB), small (< 8 MB),
-- medium (< 32 MB), large.

local res = {}

local KB, MB = 1024, 1024 * 1024
local TIERS = {
    tiny   = { logMax = 40 * KB,  logView = 200,  shellLines = 300,  history = 30,  autosave = 30, vmPages = 4, treeCache = false, keepOldLog = false },
    small  = { logMax = 128 * KB, logView = 500,  shellLines = 600,  history = 60,  autosave = 20, vmPages = 8, treeCache = true,  keepOldLog = true },
    medium = { logMax = 512 * KB, logView = 1500, shellLines = 1500, history = 150, autosave = 15, vmPages = 16, treeCache = true,  keepOldLog = true },
    large  = { logMax = 2 * MB,   logView = 4000, shellLines = 4000, history = 500, autosave = 10, vmPages = 32, treeCache = true,  keepOldLog = true },
}

local cache = nil

local function treeSize(path, skipRom)
    if skipRom and path == "rom" then return 0 end
    if fs.isDir(path) then
        local n = 0
        for _, name in ipairs(fs.list(path)) do n = n + treeSize(fs.combine(path, name), skipRom) end
        return n
    end
    return fs.getSize(path)
end

-- Total capacity of the computer's own storage, in bytes
function res.capacity()
    if fs.getCapacity then
        local ok, cap = pcall(fs.getCapacity, "/")
        if ok and type(cap) == "number" and cap > 0 then return cap end
    end
    local ok, free = pcall(fs.getFreeSpace, "/")
    if not ok or type(free) ~= "number" then return 1 * MB end
    return free + treeSize("", true)
end

function res.free()
    local ok, free = pcall(fs.getFreeSpace, "/")
    return ok and type(free) == "number" and free or math.huge
end

local function tierFor(cap)
    if cap < 2 * MB then return "tiny" end
    if cap < 8 * MB then return "small" end
    if cap < 32 * MB then return "medium" end
    return "large"
end

-- Current free space as a state: critical < 2% (or 24 KB), low < 8% (or 80 KB)
function res.pressure()
    local cap, free = res.capacity(), res.free()
    if free < 24 * KB or free < cap * 0.02 then return "critical" end
    if free < 80 * KB or free < cap * 0.08 then return "low" end
    return "ok"
end

function res.budget(force)
    local now = os.epoch and os.epoch("utc") or 0
    if cache and not force and now - cache.at < 30000 then return cache.value end
    local cap = res.capacity()
    local tier = tierFor(cap)
    local value = { tier = tier, capacity = cap, free = res.free() }
    for k, v in pairs(TIERS[tier]) do value[k] = v end
    -- under pressure everything shrinks, whatever the tier
    local p = res.pressure()
    value.pressure = p
    if p ~= "ok" then
        value.logMax = math.min(value.logMax, 24 * KB)
        value.shellLines = math.min(value.shellLines, 200)
        value.treeCache = false
        value.keepOldLog = false
    end
    cache = { at = now, value = value }
    return value
end

-- Frees what can be rebuilt: temporary files, apt caches under pressure,
-- the rotated log. Returns the number of bytes freed.
function res.cleanup(aggressive)
    local before = res.free()
    local b = res.budget(true)
    local function wipe(path)
        if fs.exists(path) then pcall(fs.delete, path) end
    end
    if fs.exists("/tmp") and fs.isDir("/tmp") then
        for _, name in ipairs(fs.list("/tmp")) do wipe("/tmp/" .. name) end
    end
    if not b.keepOldLog then wipe("/var/log/nyxos.log.1") end
    if aggressive or not b.treeCache then
        wipe("/var/apt/tree-cache.lua")
        wipe("/var/apt/registry-cache.lua")
    end
    if fs.exists("/home") then
        -- editor backups older than a day are not needed any more
        for _, user in ipairs(fs.list("/home")) do
            local dir = "/home/" .. user .. "/.autosave"
            if fs.exists(dir) and fs.isDir(dir) then
                for _, name in ipairs(fs.list(dir)) do
                    local ok, attr = pcall(fs.attributes, dir .. "/" .. name)
                    if aggressive or (ok and attr and attr.modified and os.epoch("utc") - attr.modified > 86400000) then
                        wipe(dir .. "/" .. name)
                    end
                end
            end
        end
    end
    cache = nil
    return math.max(0, res.free() - before)
end

return res
