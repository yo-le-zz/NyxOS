-- /bin/bg.lua : runs a command in the background
-- Usage: bg <command> [args...]      (same as: <command> [args...] &)

local services = dofile("/lib/services.lua")
local args = { ... }

if #args == 0 then
    print("Usage: bg <command> [args...]   (or: <command> &)")
    return
end

local pid, err = services.spawn({ cmd = table.concat(args, " ") })
if pid then
    print("[" .. pid .. "] " .. args[1] .. " running in the background (see: jobs, ps, kill " .. pid .. ")")
else
    print("bg: " .. tostring(err))
end
