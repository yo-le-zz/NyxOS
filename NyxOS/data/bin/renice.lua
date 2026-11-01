-- /bin/renice.lua : changes the priority of a running process
-- Usage: renice <N> <pid>
local services = dofile("/lib/services.lua")
local n, pid = tonumber((...)), tonumber((select(2, ...)))
if not n or not pid then print("Usage: renice <N> <pid>   (N: -20..19)") return end
if n < 0 then
    local ok = dofile("/lib/permissions.lua").requirePrivileged("negative priority")
    if not ok then return end
end
local ok, err = services.setNice(pid, n)
print(ok and ("pid " .. pid .. " -> nice " .. n) or ("renice: " .. tostring(err)))
