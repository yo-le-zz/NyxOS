-- /lib/logger.lua : centralized NyxOS logging
--
-- Every subsystem (services, apt, sudo, boot...) can call
-- logger.log(tag, level, message) to append a line to the single system
-- log at /var/log/nyxos.log, in the spirit of Linux's syslog/journald.
-- The log auto-rotates once it grows past a size cap so it never fills
-- the disk.

local logger = {}

local LOG_PATH = "/var/log/nyxos.log"
local LOG_DIR = "/var/log"
local MAX_SIZE = 64 * 1024 -- 64 KB before rotation

local function ensureDir()
    if not fs.exists(LOG_DIR) then
        fs.makeDir(LOG_DIR)
    end
end

local function rotateIfNeeded()
    if fs.exists(LOG_PATH) and fs.getSize(LOG_PATH) > MAX_SIZE then
        local old = LOG_PATH .. ".1"
        if fs.exists(old) then
            fs.delete(old)
        end
        fs.move(LOG_PATH, old)
    end
end

-- level: "info" | "warn" | "error" (freeform, but keep it short)
function logger.log(tag, level, message)
    ensureDir()
    rotateIfNeeded()
    local line = string.format("[%s] [%-5s] [%s] %s",
        os.date("%Y-%m-%d %H:%M:%S", math.floor(os.epoch("utc") / 1000)),
        (level or "info"):upper(),
        tag or "nyxos",
        tostring(message))
    local f = fs.open(LOG_PATH, "a")
    if f then
        f.write(line .. "\n")
        f.close()
    end
end

function logger.info(tag, message) logger.log(tag, "info", message) end
function logger.warn(tag, message) logger.log(tag, "warn", message) end
function logger.error(tag, message) logger.log(tag, "error", message) end

-- Returns the last `count` lines (default 50), most recent last.
function logger.tail(count)
    count = count or 50
    if not fs.exists(LOG_PATH) then
        return {}
    end
    local f = fs.open(LOG_PATH, "r")
    local lines = {}
    local line = f.readLine()
    while line do
        table.insert(lines, line)
        line = f.readLine()
    end
    f.close()
    if #lines <= count then
        return lines
    end
    local out = {}
    for i = #lines - count + 1, #lines do
        table.insert(out, lines[i])
    end
    return out
end

-- Returns every line whose tag matches `tag` (case-sensitive, exact).
function logger.filterByTag(tag)
    if not fs.exists(LOG_PATH) then
        return {}
    end
    local f = fs.open(LOG_PATH, "r")
    local lines = {}
    local line = f.readLine()
    local needle = "] [" .. tag .. "] "
    while line do
        if line:find(needle, 1, true) then
            table.insert(lines, line)
        end
        line = f.readLine()
    end
    f.close()
    return lines
end

return logger
