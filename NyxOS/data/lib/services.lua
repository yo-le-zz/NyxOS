-- /lib/services.lua : NyxOS service / daemon manager
--
-- A "service" is a small Lua file under /etc/services/<name>.lua that
-- returns a definition table:
--
--   return {
--       name = "heartbeat",
--       description = "Writes an uptime line to the system log every minute.",
--       exec = "/lib/services/heartbeat.lua", -- returns function(args) ... end
--       autostart = true,
--   }
--
-- The referenced `exec` file must itself `return function(args) ... end`.
-- That function is expected to run forever (typically a `while true do
-- ... sleep(n) ... end` loop) -- NyxOS runs it as a cooperative
-- coroutine alongside the interactive shell, using a small scheduler
-- (see services.runWithShell below), similar in spirit to a very small
-- init/systemd. CC:Tweaked has no real OS-level processes, so this is
-- cooperative multitasking within a single Lua VM: every service must
-- yield regularly (sleep/os.pullEvent) instead of busy-looping.
--
-- Enabled/disabled state and crash status live in /var/run/services.lua
-- (volatile, rebuilt every boot).

local nyxlib = dofile("/lib/nyxlib.lua")
local logger = dofile("/lib/logger.lua")

local services = {}

local SERVICES_DIR = "/etc/services"
local STATUS_PATH = "/var/run/services.lua"

local function ensureDir()
    if not fs.exists(SERVICES_DIR) then
        fs.makeDir(SERVICES_DIR)
    end
end

local function loadStatus()
    return nyxlib.loadTable(STATUS_PATH)
end

local function saveStatus(status)
    nyxlib.saveTable(STATUS_PATH, status)
end

-- Registers (writes) a new service definition.
function services.register(def)
    ensureDir()
    if not def or not def.name or not def.exec then
        return false, "A service needs at least a name and an exec path."
    end
    local path = fs.combine(SERVICES_DIR, def.name .. ".lua")
    local f = fs.open(path, "w")
    f.write(textutils.serialize({
        name = def.name,
        description = def.description or "",
        exec = def.exec,
        autostart = def.autostart and true or false,
    }))
    f.close()
    return true
end

function services.unregister(name)
    local path = fs.combine(SERVICES_DIR, name .. ".lua")
    if fs.exists(path) then
        fs.delete(path)
        return true
    end
    return false
end

-- Lists every known service definition.
function services.list()
    ensureDir()
    local list = {}
    for _, filename in ipairs(fs.list(SERVICES_DIR)) do
        if filename:match("%.lua$") then
            local ok, def = pcall(dofile, fs.combine(SERVICES_DIR, filename))
            if ok and type(def) == "table" and def.name then
                table.insert(list, def)
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function services.find(name)
    local path = fs.combine(SERVICES_DIR, name .. ".lua")
    if not fs.exists(path) then
        return nil
    end
    local ok, def = pcall(dofile, path)
    if ok and type(def) == "table" then
        return def
    end
    return nil
end

function services.setAutostart(name, enabled)
    local def = services.find(name)
    if not def then
        return false, "Unknown service: " .. name
    end
    def.autostart = enabled and true or false
    return services.register(def)
end

function services.setStatus(name, state, detail)
    local status = loadStatus()
    status[name] = { state = state, detail = detail, at = os.epoch("utc") }
    saveStatus(status)
end

function services.status(name)
    local status = loadStatus()
    return status[name] or { state = "stopped" }
end

function services.statusAll()
    return loadStatus()
end

------------------------------------------------------------------
-- Mini scheduler: runs the interactive shell (or any "main" function)
-- alongside every autostart service, as cooperative coroutines sharing
-- the single event loop -- a tiny init system. The whole computer stops
-- as soon as the shell coroutine finishes; a crashing service is logged
-- and dropped without taking the shell down with it.
------------------------------------------------------------------
function services.runWithShell(shellFn)
    saveStatus({}) -- fresh run state every boot

    local threads = {}

    local function addThread(name, fn, isShell)
        table.insert(threads, { name = name, co = coroutine.create(fn), filter = nil, isShell = isShell })
    end

    addThread("shell", shellFn, true)

    for _, def in ipairs(services.list()) do
        if def.autostart then
            if fs.exists(def.exec) then
                addThread(def.name, function()
                    local ok, fnOrErr = pcall(dofile, def.exec)
                    if not ok or type(fnOrErr) ~= "function" then
                        services.setStatus(def.name, "crashed", "exec did not return a function")
                        logger.log("service", "error", def.name .. ": exec did not return a function")
                        return
                    end
                    services.setStatus(def.name, "running")
                    local runOk, runErr = pcall(fnOrErr)
                    if runOk then
                        services.setStatus(def.name, "stopped")
                    else
                        services.setStatus(def.name, "crashed", tostring(runErr))
                        logger.log("service", "error", def.name .. " crashed: " .. tostring(runErr))
                    end
                end, false)
            else
                services.setStatus(def.name, "crashed", "exec file not found: " .. def.exec)
                logger.log("service", "error", def.name .. ": exec file not found: " .. def.exec)
            end
        end
    end

    local function resumeAll(...)
        for i = #threads, 1, -1 do
            local t = threads[i]
            if coroutine.status(t.co) == "dead" then
                table.remove(threads, i)
            elseif t.filter == nil or t.filter == (select(1, ...)) then
                local ok, result = coroutine.resume(t.co, ...)
                if not ok then
                    if t.isShell then
                        error(result, 0)
                    end
                    services.setStatus(t.name, "crashed", tostring(result))
                    logger.log("service", "error", t.name .. " crashed: " .. tostring(result))
                    table.remove(threads, i)
                else
                    t.filter = result
                end
            end
        end
    end

    resumeAll()
    while true do
        local shellAlive = false
        for _, t in ipairs(threads) do
            if t.isShell then shellAlive = true end
        end
        if not shellAlive then
            break
        end
        local ev = { os.pullEventRaw() }
        resumeAll(table.unpack(ev))
    end
end

return services
