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

-- Logs a (possibly multi-line) error with its traceback when available.
function logger.crash(tag, err)
    local text = tostring(err)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then logger.log(tag, "error", line) end
    end
end

-- Runs fn(...) and logs any error with a traceback instead of letting it
-- escape. Returns ok, result-or-error.
function logger.try(tag, fn, ...)
    local function handler(e)
        if debug and debug.traceback then
            return debug.traceback(tostring(e), 2)
        end
        return tostring(e)
    end
    local res = table.pack(xpcall(fn, handler, ...))
    if not res[1] then
        logger.crash(tag, res[2])
        return false, res[2]
    end
    return true, res[2], res[3], res[4]
end

-- Returns only the error/warn lines (last `count`).
function logger.errors(count)
    local out = {}
    for _, line in ipairs(logger.tail(100000)) do
        if line:find("[ERROR]", 1, true) or line:find("[WARN ]", 1, true) then out[#out + 1] = line end
    end
    count = count or 30
    local res = {}
    for i = math.max(1, #out - count + 1), #out do res[#res + 1] = out[i] end
    return res
end

function logger.clear()
    if fs.exists(LOG_PATH) then fs.delete(LOG_PATH) end
end

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
