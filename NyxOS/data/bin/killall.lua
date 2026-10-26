-- /bin/killall.lua : stops every process with exactly this name
-- Usage: killall <name>

local procui = dofile("/lib/procui.lua")
local args = { ... }

if not args[1] then
    print("Usage: killall <name>")
    return
end

local count = procui.killMatching(args[1], true)
if count == 0 then print("killall: no process named '" .. args[1] .. "'.") end
