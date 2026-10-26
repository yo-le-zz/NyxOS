-- /lib/procui.lua : shared helpers for ps / jobs / kill / pkill / top
-- and for the desktop's Task Manager.

local services = dofile("/lib/services.lua")
local nyxlib = dofile("/lib/nyxlib.lua")

local procui = {}

-- mode: "pid" (things with a pid), "all" (plus listed-only parts of the
-- system), "job" (background jobs only)
function procui.snapshot(mode)
    local out = {}
    for _, p in ipairs(services.processes()) do
        if mode == "all"
            or (mode == "pid" and p.pid > 0)
            or (mode == "job" and p.kind == "job") then
            table.insert(out, p)
        end
    end
    return out
end

local function age(p)
    local seconds = math.max(0, math.floor((os.epoch("utc") - (p.started or os.epoch("utc"))) / 1000))
    if seconds >= 3600 then return string.format("%dh%02dm", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
    if seconds >= 60 then return string.format("%dm%02ds", math.floor(seconds / 60), seconds % 60) end
    return seconds .. "s"
end
procui.age = age

function procui.print(list)
    print(string.format("%-4s %-12s %-6s %-8s %-6s %s", "PID", "NAME", "KIND", "USER", "AGE", "STATE"))
    for _, p in ipairs(list) do
        print(string.format("%-4s %-12s %-6s %-8s %-6s %s",
            p.pid > 0 and p.pid or "-", tostring(p.name):sub(1, 12), p.kind, tostring(p.user):sub(1, 8), age(p), p.state))
    end
end

-- Can the current user stop this process? Jobs of your own: yes.
-- Services, system, other users' jobs: administrators only.
local function allowed(p)
    local session = nyxlib.loadSession()
    if p.kind == "job" and p.user == session.username then
        return true
    end
    local permissions = dofile("/lib/permissions.lua")
    local ok, err = permissions.requirePrivileged("stopping " .. tostring(p.name))
    return ok, err
end

function procui.killPid(pid)
    pid = tonumber(pid)
    if not pid then return false, "kill: not a pid." end
    local target
    for _, p in ipairs(services.processes()) do
        if p.pid == pid then target = p end
    end
    if not target then return false, "kill: no such process: " .. pid end
    local ok, err = allowed(target)
    if not ok then return false, "kill: " .. tostring(err) end
    local killed, msg = services.kill(pid)
    if killed then return true, "killed " .. pid .. " (" .. target.name .. ")" end
    return false, "kill: " .. tostring(msg)
end

-- exact=false: substring match; exact=true: whole name
function procui.killMatching(pattern, exact)
    local count = 0
    for _, p in ipairs(services.processes()) do
        local hit = p.pid > 0 and p.killable and ((exact and p.name == pattern) or (not exact and p.name:find(pattern, 1, true)))
        if hit then
            local ok, msg = procui.killPid(p.pid)
            print(msg)
            if ok then count = count + 1 end
        end
    end
    return count
end

return procui
