-- /bin/export.lua : sets an environment variable
--   export NAME=value        this session
--   export -p NAME=value     also saved in ~/.profile
--   export -g NAME=value     also saved in /etc/environment (administrator)
--   export                   lists the variables
local env = dofile("/lib/env.lua")
local args = { ... }
local persist, global = false, false
while args[1] and args[1]:sub(1, 1) == "-" and #args[1] == 2 do
    local flag = table.remove(args, 1)
    if flag == "-p" then persist = true elseif flag == "-g" then persist, global = true, true
    else print("export: unknown option " .. flag) return end
end
if #args == 0 then
    for _, kv in ipairs(env.list()) do print(kv[1] .. "=" .. tostring(kv[2])) end
    return
end
local text = table.concat(args, " ")
local name, value = text:match("^([%a_][%w_]*)=(.*)$")
if not name then print("Usage: export [-p|-g] NAME=value") return end
if #value >= 2 and ((value:sub(1, 1) == '"' and value:sub(-1) == '"') or (value:sub(1, 1) == "'" and value:sub(-1) == "'")) then
    value = value:sub(2, -2)
end
if global then
    local good, why = dofile("/lib/permissions.lua").requirePrivileged("editing /etc/environment")
    if not good then print(why) return end
end
local ok, err = env.set(name, value)
if not ok then print("export: " .. tostring(err)) return end
if persist then
    local saved, why = env.persist(name, value, global)
    if not saved then print("export: " .. tostring(why)) end
end
