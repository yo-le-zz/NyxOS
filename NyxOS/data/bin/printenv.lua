-- /bin/env.lua : prints the environment (env), one variable (printenv NAME)
local env = dofile("/lib/env.lua")
local args = { ... }
if args[1] == "reload" then env.load() print("Environment reloaded.") return end
if args[1] then
    local v = env.get(args[1])
    if v == nil then return end
    print(v)
    return
end
for _, kv in ipairs(env.list()) do print(kv[1] .. "=" .. tostring(kv[2])) end
