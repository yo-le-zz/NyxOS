-- /bin/nice.lua : runs a command in the background with a priority
-- Usage: nice [-n N] [-l MAXWAKEUPS] <command> [args...]    (N: -20..19, lower = first)
local services = dofile("/lib/services.lua")
local args = { ... }
local n, limit = 0, nil
while args[1] and (args[1] == "-n" or args[1] == "-l") do
    local flag = table.remove(args, 1)
    local v = tonumber(table.remove(args, 1))
    if not v then print("nice: number expected after " .. flag) return end
    if flag == "-n" then n = v else limit = v end
end
if #args == 0 then print("Usage: nice [-n N] [-l MAXWAKEUPS] <command> [args...]") return end
if n < 0 then
    local ok = dofile("/lib/permissions.lua").requirePrivileged("negative priority")
    if not ok then return end
end
local pid, err = services.spawn({ cmd = table.concat(args, " "), nice = n, maxResumes = limit })
if pid then print("[" .. pid .. "] " .. args[1] .. " (nice " .. n .. (limit and (", limit " .. limit) or "") .. ")")
else print("nice: " .. tostring(err)) end
