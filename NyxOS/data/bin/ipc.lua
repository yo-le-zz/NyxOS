-- /bin/ipc.lua : message queues between processes
-- Usage: ipc send <queue> <text...> | ipc recv <queue> [timeout] | ipc list | ipc clear <queue>
local ipc = dofile("/lib/ipc.lua")
local a = { ... }
if a[1] == "send" and a[3] then ipc.send(a[2], table.concat(a, " ", 3)) print("sent")
elseif a[1] == "recv" and a[2] then
    local m = ipc.receive(a[2], tonumber(a[3]) or 5)
    print(m ~= nil and tostring(m) or "(timeout)")
elseif a[1] == "clear" and a[2] then ipc.clear(a[2]) print("cleared")
elseif a[1] == "list" or not a[1] then
    local l = ipc.list()
    if #l == 0 then print("No queue.") end
    for _, q in ipairs(l) do print(string.format("%-16s %d message(s)", q.name, q.count)) end
else print("Usage: ipc send <queue> <text> | recv <queue> [timeout] | list | clear <queue>") end
