-- /bin/pkill.lua : stops processes whose name matches a pattern
-- Usage: pkill <pattern>
-- Example: pkill chat     (stops every process whose name contains "chat")

local procui = dofile("/lib/procui.lua")
local args = { ... }

if not args[1] then
    print("Usage: pkill <pattern>")
    return
end

local count = procui.killMatching(args[1], false)
if count == 0 then print("pkill: no process matches '" .. args[1] .. "'.") end
