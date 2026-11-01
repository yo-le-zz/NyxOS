-- /bin/tstatus.lua : turtle position, fuel, inventory
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local x, y, z, d = tk.pos()
local names = { [0] = "north", "east", "south", "west" }
local f = tk.fuel()
print(string.format("Pos  %d,%d,%d facing %s", x, y, z, names[d]))
local h = tk.state().home
print(string.format("Home %d,%d,%d", h.x, h.y, h.z))
print("Fuel " .. (f == math.huge and "unlimited" or (f .. "/" .. turtle.getFuelLimit())))
print("Free slots " .. tk.freeSlots() .. "/16")
