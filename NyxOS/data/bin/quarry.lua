-- /bin/quarry.lua : digs a rectangular pit (width to the right, length forward, depth down)
-- Usage: quarry <width> <length> [depth]
-- Home = start position, facing backwards: put a chest behind the turtle before starting.
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local w, l, depth = tonumber((...)), tonumber((select(2, ...))), tonumber((select(3, ...))) or 1
if not (w and l) then print("Usage: quarry <width> <length> [depth]") return end
local x0, y0, z0, d0 = tk.pos()
tk.setHome(x0, y0, z0, (d0 + 2) % 4)
local DX = { [0] = 0, 1, 0, -1 }
local DZ = { [0] = -1, 0, 1, 0 }
local right = (d0 + 1) % 4
local aborted = false
for layer = 1, depth do
    for col = 0, w - 1 do
        for i = 0, l - 1 do
            local row = (col % 2 == 0) and i or (l - 1 - i)
            local tx = x0 + col * DX[right] + row * DX[d0]
            local tz = z0 + col * DZ[right] + row * DZ[d0]
            if not tk.canContinue(10) then print("Low fuel: going home.") aborted = true break end
            if tk.freeSlots() == 0 then tk.unloadAtHome() end
            local ok, e = tk.goto(tx, y0 - layer, tz)
            if not ok then print("Stopped: " .. tostring(e)) aborted = true break end
        end
        if aborted then break end
    end
    if aborted then break end
end
tk.goHome()
tk.dump()
print(aborted and "Quarry stopped." or "Quarry done.")
