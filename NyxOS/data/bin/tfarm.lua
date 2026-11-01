-- /bin/tfarm.lua : harvests and replants a rectangular crop field below the turtle's path
-- Usage: tfarm <width> <length>      (crops one block below; seeds in slot 1; chest behind start)
if not turtle then print("Not a turtle.") return end
local tk = dofile("/lib/turtlekit.lua")
local w, l = tonumber((...)), tonumber((select(2, ...)))
if not (w and l) then print("Usage: tfarm <width> <length>") return end
local x0, y0, z0, d0 = tk.pos()
tk.setHome(x0, y0, z0, (d0 + 2) % 4)
local DX = { [0] = 0, 1, 0, -1 }
local DZ = { [0] = -1, 0, 1, 0 }
local right = (d0 + 1) % 4
local function tend()
    local ok, info = turtle.inspectDown()
    local ripe = ok and info.state and info.state.age and info.state.age >= 7
    if ok and not ripe then return end
    if ok then turtle.digDown() end
    turtle.select(1) turtle.placeDown()
end
for col = 0, w - 1 do
    for i = 0, l - 1 do
        local row = (col % 2 == 0) and i or (l - 1 - i)
        local ok = tk.goto(x0 + col * DX[right] + row * DX[d0], y0, z0 + col * DZ[right] + row * DZ[d0], false)
        if ok then tend() end
    end
end
tk.goHome()
tk.dump(1)   -- keep the seeds slot
print("Farm tended.")
