-- /bin/tgo.lua : walks to coordinates (digging) or home
-- Usage: tgo <x> <y> <z> | tgo home
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local a = { ... }
local ok, e
if a[1] == "home" then ok, e = tk.goHome()
else
    local x, y, z = tonumber(a[1]), tonumber(a[2]), tonumber(a[3])
    if not (x and y and z) then print("Usage: tgo <x> <y> <z> | tgo home") return end
    ok, e = tk.goto(x, y, z)
end
print(ok and "Arrived." or ("Stopped: " .. tostring(e)))
