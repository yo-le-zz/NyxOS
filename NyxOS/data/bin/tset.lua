-- /bin/tset.lua : sets the turtle's coordinates / home
-- Usage: tset <x> <y> <z> [north|east|south|west] | tset gps | tset home
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local a = { ... }
if a[1] == "gps" then print(tk.locate(5) and "Located by GPS." or "No GPS fix.") return end
if a[1] == "home" then tk.setHome() print("Home = current position.") return end
local x, y, z = tonumber(a[1]), tonumber(a[2]), tonumber(a[3])
if not (x and y and z) then print("Usage: tset <x> <y> <z> [dir] | tset gps | tset home") return end
local dirs = { north = 0, east = 1, south = 2, west = 3 }
tk.set(x, y, z, dirs[a[4] or ""])
print("Position set.")
