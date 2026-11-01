-- /bin/refuel.lua : burns fuel items from the inventory
-- Usage: refuel [target level]
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local gain = tk.refuel(tonumber((...)))
print("Fuel +" .. gain .. " -> " .. tostring(turtle.getFuelLevel()))
