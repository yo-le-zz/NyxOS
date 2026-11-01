-- /lib/turtlekit.lua : toolkit for turtles (position tracking, safe moves, fuel, inventory)
--
-- Coordinates: x grows east, z grows south, y grows up; dir 0=north(-z) 1=east(+x) 2=south(+z) 3=west(-x).
-- State is saved in /var/turtle.lua after every move, so a reboot keeps the position.
-- Set the origin with `tset x y z [dir]` (or GPS: tk.locate()).
local tk = {}
local STATE = "/var/turtle.lua"
local DX = { [0] = 0, 1, 0, -1 }
local DZ = { [0] = -1, 0, 1, 0 }

local st = { x = 0, y = 0, z = 0, dir = 0, home = { x = 0, y = 0, z = 0, dir = 0 } }

local function save()
    if not fs.exists("/var") then fs.makeDir("/var") end
    local f = fs.open(STATE, "w") f.write(textutils.serialize(st)) f.close()
end

function tk.load()
    if fs.exists(STATE) then
        local f = fs.open(STATE, "r") local t = textutils.unserialize(f.readAll()) f.close()
        if type(t) == "table" then for k, v in pairs(t) do st[k] = v end end
    end
    return st
end

function tk.state() return st end
function tk.pos() return st.x, st.y, st.z, st.dir end
function tk.set(x, y, z, dir)
    st.x, st.y, st.z = x, y, z
    if dir then st.dir = dir % 4 end
    save()
end
function tk.setHome(x, y, z, dir)
    st.home = { x = x or st.x, y = y or st.y, z = z or st.z, dir = dir or st.dir }
    save()
end

-- GPS (needs a modem and GPS hosts). Returns true on success.
function tk.locate(timeout)
    if not gps then return false end
    local x, y, z = gps.locate(timeout or 2)
    if not x then return false end
    tk.set(x, y, z)
    return true
end

function tk.fuel()
    local l = turtle.getFuelLevel()
    return l == "unlimited" and math.huge or l
end

function tk.refuel(limit)
    local before = turtle.getFuelLevel()
    if before == "unlimited" then return 0 end
    for slot = 1, 16 do
        if limit and turtle.getFuelLevel() >= limit then break end
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then turtle.refuel() end
    end
    turtle.select(1)
    return turtle.getFuelLevel() - before
end

local function ensureFuel()
    if tk.fuel() > 0 then return true end
    tk.refuel(1)
    return tk.fuel() > 0
end

function tk.turnRight() if turtle.turnRight() then st.dir = (st.dir + 1) % 4 save() return true end return false end
function tk.turnLeft() if turtle.turnLeft() then st.dir = (st.dir - 1) % 4 save() return true end return false end
function tk.face(dir)
    dir = dir % 4
    local diff = (dir - st.dir) % 4
    if diff == 1 then tk.turnRight() elseif diff == 2 then tk.turnRight() tk.turnRight() elseif diff == 3 then tk.turnLeft() end
end

-- Generic move with digging/attacking. dig=false: fail instead of digging.
local function move(go, dig, detect, digf, attack, apply)
    if not ensureFuel() then return false, "out of fuel" end
    for _ = 1, 30 do
        if go() then apply() save() return true end
        if detect() then
            if not dig then return false, "blocked" end
            if not digf() then return false, "undiggable block" end
        else
            attack()
        end
        sleep(0.2)
    end
    return false, "blocked"
end

function tk.forward(dig)
    return move(turtle.forward, dig, turtle.detect, turtle.dig, turtle.attack, function()
        st.x, st.z = st.x + DX[st.dir], st.z + DZ[st.dir]
    end)
end
function tk.back()
    if not ensureFuel() then return false, "out of fuel" end
    if turtle.back() then st.x, st.z = st.x - DX[st.dir], st.z - DZ[st.dir] save() return true end
    return false, "blocked"
end
function tk.up(dig)
    return move(turtle.up, dig, turtle.detectUp, turtle.digUp, turtle.attackUp, function() st.y = st.y + 1 end)
end
function tk.down(dig)
    return move(turtle.down, dig, turtle.detectDown, turtle.digDown, turtle.attackDown, function() st.y = st.y - 1 end)
end

-- Walks to x,y,z (digging by default). Order: up/down first, then x, then z.
function tk.goto(x, y, z, dig)
    if dig == nil then dig = true end
    while st.y < y do local ok, e = tk.up(dig) if not ok then return false, e end end
    while st.y > y do local ok, e = tk.down(dig) if not ok then return false, e end end
    if st.x ~= x then
        tk.face(st.x < x and 1 or 3)
        while st.x ~= x do local ok, e = tk.forward(dig) if not ok then return false, e end end
    end
    if st.z ~= z then
        tk.face(st.z < z and 2 or 0)
        while st.z ~= z do local ok, e = tk.forward(dig) if not ok then return false, e end end
    end
    return true
end

function tk.goHome()
    local h = st.home
    local ok, e = tk.goto(h.x, h.y, h.z)
    if ok then tk.face(h.dir) end
    return ok, e
end

-- Fuel needed to reach x,y,z (Manhattan distance).
function tk.distance(x, y, z) return math.abs(st.x - x) + math.abs(st.y - y) + math.abs(st.z - z) end

function tk.freeSlots()
    local n = 0
    for s = 1, 16 do if turtle.getItemCount(s) == 0 then n = n + 1 end end
    return n
end

-- Merges partial stacks of the same item, then moves everything to the front.
function tk.sort()
    for a = 1, 16 do
        local da = turtle.getItemDetail(a)
        if da then
            for b = a + 1, 16 do
                local db = turtle.getItemDetail(b)
                if db and db.name == da.name and turtle.getItemSpace(a) > 0 then
                    turtle.select(b) turtle.transferTo(a)
                end
            end
        end
    end
    local free = 1
    for s = 1, 16 do
        if turtle.getItemCount(s) > 0 then
            if s ~= free then turtle.select(s) turtle.transferTo(free) end
            free = free + 1
        end
    end
    turtle.select(1)
end

-- Drops everything into the inventory in front (a chest), keeping `keep` slots (default 0).
function tk.dump(keep, drop)
    drop = drop or turtle.drop
    for s = (keep or 0) + 1, 16 do
        if turtle.getItemCount(s) > 0 then turtle.select(s) drop() end
    end
    turtle.select(1)
end

-- Empties the inventory at home (chest in front of the home position), then comes back.
-- Returns to the previous position afterwards.
function tk.unloadAtHome(keep)
    local x, y, z, d = st.x, st.y, st.z, st.dir
    local ok, e = tk.goHome()
    if not ok then return false, e end
    tk.dump(keep)
    return tk.goto(x, y, z) and (tk.face(d) or true)
end

-- Is there enough fuel to go on and still come back to home?
function tk.canContinue(margin)
    local f = tk.fuel()
    return f == math.huge or f > tk.distance(st.home.x, st.home.y, st.home.z) + (margin or 10)
end

tk.load()
return tk
