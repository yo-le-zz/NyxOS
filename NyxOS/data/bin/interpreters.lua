-- /bin/interpreters.lua : lists / manages registered interpreters
-- Usage: interpreters | interpreters add <name> <ext> <program> | interpreters remove <name>
local args = { ... }
local interp = dofile("/lib/interpreters.lua")
if args[1] == "add" and args[4] then
    interp.register(args[2], args[3], args[4]) print("Registered " .. args[2])
elseif args[1] == "remove" and args[2] then
    print(interp.unregister(args[2]) and "Removed" or "Not found")
else
    local list = interp.list()
    if #list == 0 then print("No interpreter installed (try: apt install python, apt install c).") end
    for _, e in ipairs(list) do print(string.format("%-10s .%-5s %s", e.name, e.ext, e.program)) end
end
