-- /bin/unset.lua : removes an environment variable (-p: also from ~/.profile)
local env = dofile("/lib/env.lua")
local args = { ... }
local persist = false
if args[1] == "-p" then persist = true table.remove(args, 1) end
if #args == 0 then print("Usage: unset [-p] NAME ...") return end
for _, name in ipairs(args) do
    env.unset(name)
    if persist then env.persist(name, nil) end
end
