-- /bin/tunnel.lua : digs a tunnel in front of the turtle
-- Usage: tunnel <length> [width] [height]     (width to the right, height up; default 1x2)
-- Unloads at home (chest in front of home) when full, stops when fuel is too low to return.
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local len, w, h = tonumber((...)), tonumber((select(2, ...))) or 1, tonumber((select(3, ...))) or 2
if not len then print("Usage: tunnel <length> [width] [height]") return end
local x0, y0, z0, d0 = tk.pos()
tk.setHome(x0, y0, z0, (d0 + 2) % 4)  -- chest behind the start: home faces back
for i = 1, len do
    if not tk.canContinue(5) then print("Low fuel: stopping at " .. (i - 1)) break end
    if tk.freeSlots() == 0 then tk.unloadAtHome() end
    local ok, e = tk.forward(true)
    if not ok then print("Stopped: " .. tostring(e)) break end
    -- dig the column (height) and the extra width at this step
    for lvl = 1, h - 1 do tk.up(true) end
    for lvl = 1, h - 1 do tk.down(true) end
    if w > 1 then
        tk.turnRight()
        for _ = 1, w - 1 do tk.forward(true) for lvl = 1, h - 1 do tk.up(true) end for lvl = 1, h - 1 do tk.down(true) end end
        tk.turnLeft() tk.turnLeft()
        for _ = 1, w - 1 do tk.forward(true) end
        tk.turnRight()
    end
end
print("Tunnel done.")
