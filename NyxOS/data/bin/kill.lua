-- /bin/kill.lua : stops processes by pid
-- Usage: kill [-9] <pid> [pid...]
-- You can stop your own background jobs. Services and other users' jobs
-- need administrator rights (sudo). The interactive session (pid 1) cannot
-- be killed: use `shutdown`.

local procui = dofile("/lib/procui.lua")
local args = { ... }

local pids = {}
for _, a in ipairs(args) do
    if a:sub(1, 1) ~= "-" then table.insert(pids, a) end
end
if #pids == 0 then
    print("Usage: kill [-9] <pid> [pid...]")
    return
end

for _, pid in ipairs(pids) do
    local ok, msg = procui.killPid(pid)
    print(msg)
end
