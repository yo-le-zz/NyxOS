-- /lib/ipc.lua : simple message queues between processes
--   ipc.send("queue", message)       never blocks
--   ipc.receive("queue", timeout)    waits (cooperatively) for a message; nil on timeout
--   ipc.peek("queue"), ipc.count("queue"), ipc.list(), ipc.clear("queue")
-- Queues live in _G.NYX_IPC (shared by every process of the running system),
-- hold at most MAX messages (oldest dropped).
local ipc = {}
local MAX = 256

local function queues()
    _G.NYX_IPC = _G.NYX_IPC or {}
    return _G.NYX_IPC
end

function ipc.send(name, message)
    local q = queues()
    q[name] = q[name] or {}
    table.insert(q[name], message)
    while #q[name] > MAX do table.remove(q[name], 1) end
    os.queueEvent("nyx_ipc", name)
    return true
end

function ipc.receive(name, timeout)
    local q = queues()
    local timer = timeout and os.startTimer(timeout)
    while true do
        if q[name] and #q[name] > 0 then
            if timer then os.cancelTimer(timer) end
            return table.remove(q[name], 1)
        end
        local ev, a = os.pullEvent()
        if ev == "timer" and timer and a == timer then return nil end
    end
end

function ipc.peek(name) local q = queues()[name] return q and q[1] end
function ipc.count(name) local q = queues()[name] return q and #q or 0 end
function ipc.clear(name) queues()[name] = nil end

function ipc.list()
    local out = {}
    for name, q in pairs(queues()) do out[#out + 1] = { name = name, count = #q } end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

return ipc
