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
-- Instead of `exec` a service may give `program = "/path/main.lua"` (and
-- optional `args = {...}`): the file is then run like a normal program, so
-- an app's own server script can be a service as-is (server installs).
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
    if not def or not def.name or not (def.exec or def.program) then
        return false, "A service needs at least a name and an exec (or program) path."
    end
    local path = fs.combine(SERVICES_DIR, def.name .. ".lua")
    local f = fs.open(path, "w")
    f.write(textutils.serialize({
        name = def.name,
        description = def.description or "",
        exec = def.exec,
        autostart = def.autostart and true or false,
        program = def.program,
        args = def.args,
        owner = def.owner,
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
-- Scheduler: a tiny init + process table.
--
-- Every thread (the interactive shell, services, background jobs) is a
-- cooperative coroutine sharing the single CC event loop. The table lives
-- in the global NYX_SCHED so that every dofile()'d copy of this module
-- (the shell commands ps/kill/..., the desktop's Tasks app) sees the
-- scheduler that /nyxos.lua started.
--
-- Kinds: "shell" (the interactive session), "service", "job" (started
-- with `cmd &` / `bg`), and pseudo entries (kind "system"/"ui") that only
-- exist to be listed.
------------------------------------------------------------------
local function sched()
    return _G.NYX_SCHED
end

function services.scheduler()
    return sched()
end

local function tokenize(line)
    local tokens, i = {}, 1
    while i <= #line do
        local c = line:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == '"' then
            local j = line:find('"', i + 1, true) or (#line + 1)
            table.insert(tokens, line:sub(i + 1, j - 1))
            i = j + 1
        else
            local j = line:find("%s", i) or (#line + 1)
            table.insert(tokens, line:sub(i, j - 1))
            i = j
        end
    end
    return tokens
end

-- Runs a program file the way the shell would (own environment, with a
-- `shell` table whose getRunningProgram() is the program itself).
local function runProgram(path, args)
    local sh = _G.shell
    local proxy = setmetatable({
        getRunningProgram = function() return path end,
    }, { __index = sh })
    local env = setmetatable({ shell = proxy, multishell = _G.multishell }, { __index = _G })
    return os.run(env, path, (table.unpack or unpack)(args or {}))
end

-- Runs a command line as a background program.
local function runCommandLine(line)
    local tokens = tokenize(line)
    if #tokens == 0 then return end
    local sh = _G.shell
    local name = table.remove(tokens, 1)
    local path = sh and sh.resolveProgram and sh.resolveProgram(name)
    if not path and sh and sh.resolve then
        local p = sh.resolve(name)
        if fs.exists(p) and not fs.isDir(p) then path = p end
    end
    if not path then
        printError("No such program: " .. name)
        return
    end
    return runProgram(path, tokens)
end

local function addThread(s, t)
    t.pid = s.nextPid
    s.nextPid = s.nextPid + 1
    t.started = os.epoch("utc")
    t.resumes = 0
    t.state = "running"
    table.insert(s.threads, t)
    return t.pid
end

local function newServiceThread(def)
    return function()
        local ok, err
        if def.program then
            if not fs.exists(def.program) then
                services.setStatus(def.name, "crashed", "program not found: " .. def.program)
                logger.log("service", "error", def.name .. ": program not found: " .. def.program)
                return
            end
            services.setStatus(def.name, "running")
            ok, err = pcall(runProgram, def.program, def.args)
        else
            local lok, fnOrErr = pcall(dofile, def.exec)
            if not lok or type(fnOrErr) ~= "function" then
                services.setStatus(def.name, "crashed", "exec did not return a function")
                logger.log("service", "error", def.name .. ": exec did not return a function")
                return
            end
            services.setStatus(def.name, "running")
            ok, err = pcall(fnOrErr, def.args)
        end
        if ok then
            services.setStatus(def.name, "stopped")
        else
            services.setStatus(def.name, "crashed", tostring(err))
            logger.log("service", "error", def.name .. " crashed: " .. tostring(err))
        end
    end
end

-- Starts a registered service now (not only at boot). Returns pid.
function services.start(name)
    local s = sched()
    if not s then
        return nil, "The scheduler is not running (services only run on a booted NyxOS)."
    end
    local def = services.find(name)
    if not def then return nil, "Unknown service: " .. tostring(name) end
    for _, t in ipairs(s.threads) do
        if t.kind == "service" and t.name == name and not t.killed then
            return nil, name .. " is already running (pid " .. t.pid .. ")."
        end
    end
    if def.exec and not def.program and not fs.exists(def.exec) then
        services.setStatus(name, "crashed", "exec file not found: " .. def.exec)
        return nil, "exec file not found: " .. def.exec
    end
    return addThread(s, {
        name = name, kind = "service", co = coroutine.create(newServiceThread(def)),
        user = def.owner or "root", cmd = def.program or def.exec, description = def.description,
    })
end

-- Starts a background job (a command line, or a Lua function).
function services.spawn(opts)
    local s = sched()
    if not s then
        return nil, "The scheduler is not running."
    end
    local fn
    local label = opts.name
    if opts.cmd then
        label = label or opts.cmd:match("^%s*(%S+)") or "job"
        fn = function() return runCommandLine(opts.cmd) end
    elseif opts.fn then
        fn = opts.fn
    else
        return nil, "spawn needs `cmd` or `fn`."
    end
    local width = 51
    pcall(function() width = term.getSize() end)
    local ok, win = pcall(window.create, term.current(), 1, 1, width, 200, false)
    local session = nyxlib.loadSession()
    return addThread(s, {
        name = label, kind = "job", cmd = opts.cmd or label,
        user = opts.user or session.username or "root",
        win = ok and win or nil,
        co = coroutine.create(function()
            local rok, rerr = pcall(fn)
            if not rok then
                logger.log("job", "error", tostring(label) .. " crashed: " .. tostring(rerr))
                if _G.NYX_SCHED then
                    local msg = tostring(rerr)
                    pcall(printError, msg)
                end
            end
        end),
    })
end

-- Registers a listing-only entry (a part of the system that is not a
-- coroutine of its own, e.g. the graphical desktop or the network stack).
function services.registerPseudo(name, kind, description)
    local s = sched()
    if not s then return end
    s.pseudo[name] = { name = name, kind = kind or "system", description = description, started = os.epoch("utc") }
end

function services.unregisterPseudo(name)
    local s = sched()
    if s then s.pseudo[name] = nil end
end

-- Process table snapshot.
function services.processes()
    local s = sched()
    local list = {}
    if not s then return list end
    for _, t in ipairs(s.threads) do
      if not t.killed then
        table.insert(list, {
            pid = t.pid, name = t.name, kind = t.kind, user = t.user or "root",
            state = coroutine.status(t.co) == "dead" and "dead" or "running",
            started = t.started, resumes = t.resumes, cmd = t.cmd, description = t.description,
            killable = not t.isShell,
        })
      end
    end
    for _, p in pairs(s.pseudo) do
        table.insert(list, {
            pid = 0, name = p.name, kind = p.kind, user = "root", state = "running",
            started = p.started, resumes = 0, description = p.description, killable = false,
        })
    end
    table.sort(list, function(a, b)
        if a.pid ~= b.pid then return a.pid < b.pid end
        return a.name < b.name
    end)
    return list
end

-- Stops a thread by pid. Returns ok, err.
function services.kill(pid)
    local s = sched()
    if not s then return false, "The scheduler is not running." end
    pid = tonumber(pid)
    for _, t in ipairs(s.threads) do
        if t.pid == pid and not t.killed then
            if t.isShell then
                return false, "pid " .. pid .. " is the interactive session (use shutdown)."
            end
            -- Marked, then swept by the scheduler loop: removing here could
            -- shift the list while it is being iterated.
            t.killed = true
            if t.kind == "service" then
                services.setStatus(t.name, "stopped", "killed")
            end
            logger.log("proc", "info", "killed pid " .. pid .. " (" .. tostring(t.name) .. ")")
            return true, t
        end
    end
    return false, "No such process: " .. tostring(pid)
end

-- Captured terminal output of a job (text), or nil.
function services.jobOutput(pid)
    local s = sched()
    if not s then return nil end
    pid = tonumber(pid)
    for _, t in ipairs(s.threads) do
        if t.pid == pid and t.win and not t.killed then
            local _, cy = t.win.getCursorPos()
            local lines = {}
            for y = 1, cy do
                lines[#lines + 1] = (t.win.getLine(y) or ""):gsub("%s+$", "")
            end
            return table.concat(lines, "\n")
        end
    end
    return nil
end

function services.runWithShell(shellFn)
    saveStatus({}) -- fresh run state every boot

    local s = { threads = {}, pseudo = {}, nextPid = 1 }
    _G.NYX_SCHED = s

    addThread(s, { name = "shell", kind = "shell", co = coroutine.create(shellFn), isShell = true,
        user = nyxlib.loadSession().username or "root" })
    s.pseudo["scheduler"] = { name = "scheduler", kind = "system", description = "Cooperative process scheduler", started = os.epoch("utc") }
    s.pseudo["logger"] = { name = "logger", kind = "system", description = "System log (/var/log/nyxos.log)", started = os.epoch("utc") }

    -- Parts of the system that are listed in the Task Manager although they
    -- are not coroutines of their own.
    pcall(function()
        local netParts = {}
        if http then table.insert(netParts, "http") end
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.getType(name) == "modem" then table.insert(netParts, "modem:" .. name) end
        end
        s.pseudo["network"] = { name = "network", kind = "system", started = os.epoch("utc"),
            description = #netParts > 0 and table.concat(netParts, ", ") or "no http, no modem" }
        local screen = "computer terminal"
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.getType(name) == "monitor" then screen = "monitor:" .. name break end
        end
        s.pseudo["display"] = { name = "display", kind = "system", started = os.epoch("utc"), description = screen }
        s.pseudo["filesystem"] = { name = "filesystem", kind = "system", started = os.epoch("utc"),
            description = "/dev/null, /dev/zero, /tmp" }
    end)

    for _, def in ipairs(services.list()) do
        if def.autostart then
            local pid, err = services.start(def.name)
            if not pid then
                logger.log("service", "error", def.name .. ": " .. tostring(err))
            end
        end
    end

    local function resumeAll(...)
        local evName = (select(1, ...))
        for i = #s.threads, 1, -1 do
            local t = s.threads[i]
            if t then
                if t.killed or coroutine.status(t.co) == "dead" then
                    table.remove(s.threads, i)
                elseif evName == "terminate" and not t.isShell then
                    -- Ctrl+T ends the foreground program, not background work.
                elseif t.filter == nil or t.filter == evName then
                    local prev
                    if t.win then prev = term.redirect(t.win) end
                    t.resumes = t.resumes + 1
                    local ok, result = coroutine.resume(t.co, ...)
                    if prev then term.redirect(prev) end
                    if not ok then
                        if t.isShell then
                            error(result, 0)
                        end
                        if t.kind == "service" then services.setStatus(t.name, "crashed", tostring(result)) end
                        logger.log("service", "error", tostring(t.name) .. " crashed: " .. tostring(result))
                        for j, x in ipairs(s.threads) do if x == t then table.remove(s.threads, j) break end end
                    else
                        t.filter = result
                    end
                end
            end
        end
    end

    resumeAll()
    while true do
        local shellAlive = false
        for _, t in ipairs(s.threads) do
            if t.isShell then shellAlive = true end
        end
        if not shellAlive then
            break
        end
        local ev = { os.pullEventRaw() }
        resumeAll((table.unpack or unpack)(ev))
    end
    _G.NYX_SCHED = nil
end

return services
