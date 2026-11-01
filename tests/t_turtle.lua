-- turtlekit / tunnel / quarry on a fake turtle in a block grid
H.idleForce = false
local function host(path) local f = assert(H.hostloadfile(path)) return f() end
local C = host(HARNESS_DIR .. "/common.lua")
C.stage(REPO .. "/NyxOS/data/lib", "lib") C.stage(REPO .. "/NyxOS/data/bin", "bin") C.stage(REPO .. "/NyxOS/data/etc", "etc")
local fails = 0
local function check(n, c) if not c then fails = fails + 1 end H.say(c and "PASS" or "FAIL", n) end
H.runCo(function()
  -- world: stone everywhere except the turtle's cell; position tracked independently
  local px, py, pz, pd = 0, 0, 0, 0
  local DX = { [0] = 0, 1, 0, -1 } local DZ = { [0] = -1, 0, 1, 0 }
  local air = { ["0,0,0"] = true }
  local function key(x, y, z) return x .. "," .. y .. "," .. z end
  local inv = { 0 } local fuel = 500
  local function solid(x, y, z) return not air[key(x, y, z)] end
  local function dig(x, y, z) if solid(x, y, z) then air[key(x, y, z)] = true inv[1] = (inv[1] or 0) + 1 return true end return false end
  local function mv(x, y, z) if solid(x, y, z) then return false end px, py, pz = x, y, z fuel = fuel - 1 return true end
  turtle = {
    forward = function() return mv(px + DX[pd], py, pz + DZ[pd]) end,
    back = function() return mv(px - DX[pd], py, pz - DZ[pd]) end,
    up = function() return mv(px, py + 1, pz) end, down = function() return mv(px, py - 1, pz) end,
    turnRight = function() pd = (pd + 1) % 4 return true end, turnLeft = function() pd = (pd - 1) % 4 return true end,
    detect = function() return solid(px + DX[pd], py, pz + DZ[pd]) end, detectUp = function() return solid(px, py + 1, pz) end,
    detectDown = function() return solid(px, py - 1, pz) end,
    dig = function() return dig(px + DX[pd], py, pz + DZ[pd]) end, digUp = function() return dig(px, py + 1, pz) end,
    digDown = function() return dig(px, py - 1, pz) end,
    attack = function() return false end, attackUp = function() return false end, attackDown = function() return false end,
    getFuelLevel = function() return fuel end, getFuelLimit = function() return 20000 end,
    getItemCount = function(s) return s == 1 and inv[1] or 0 end, getItemDetail = function() return nil end,
    getItemSpace = function() return 64 end, select = function() end, drop = function() inv[1] = 0 return true end,
    refuel = function() return true end, transferTo = function() return true end,
  }
  sleep = function() end
  fs.delete("/var/turtle.lua")
  local tk = dofile("/lib/turtlekit.lua")
  check("start", select(1, tk.pos()) == 0)
  check("goto", tk.goto(2, 1, -3) and px == 2 and py == 1 and pz == -3)
  check("tracked", select(3, tk.pos()) == -3 and select(2, tk.pos()) == 1)
  tk.goto(0, 0, 0) tk.face(0)
  check("home", px == 0 and py == 0 and pz == 0)
  check("face", tk.pos() and select(4, tk.pos()) == 0 and pd == 0)
  H.runProgram("bin/tunnel.lua", "3", "1", "2")
  check("tunnel dug 3 ahead", air[key(0, 0, -1)] and air[key(0, 0, -2)] and air[key(0, 0, -3)])
  check("tunnel height", air[key(0, 1, -3)])
  tk = dofile("/lib/turtlekit.lua")
  tk.goto(0, 0, 0) tk.face(0)
  H.say("Q", H.runProgram("bin/quarry.lua", "2", "2", "1"))
  H.say("SCR", H.dump(), air[key(0,-1,-1)], air[key(1,-1,0)], air[key(1,-1,-1)], air[key(0,-1,0)])
  check("quarry cells", air[key(0, -1, -1)] and air[key(1, -1, 0)] and air[key(1, -1, -1)] and air[key(0, -1, 0)])
  check("quarry back home", px == 0 and py == 0 and pz == 0)
  check("fuel used", fuel < 500)
end, 200000)
H.say(fails == 0 and "ALL PASS" or ("FAILURES: " .. fails))
