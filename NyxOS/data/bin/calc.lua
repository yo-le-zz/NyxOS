-- /bin/calc.lua : command-line calculator
--   calc 2*(3+4)        -> 14
--   calc deg sin(30)    -> 0.5  (degrees)
local m = dofile("/lib/mathexpr.lua")
local args = { ... }
if #args == 0 then
    print("Usage: calc [deg] <expression>      e.g. calc 2*(3+4)^2, calc deg sin(30)")
    print("Functions: sin cos tan asin acos atan sqrt abs floor ceil round exp ln log fact ...")
    print("Constants: pi e tau phi ans")
    return
end
local degrees = false
if args[1] == "deg" then degrees = true table.remove(args, 1) end
local value, err = m.eval(table.concat(args, " "), { degrees = degrees })
if value == nil then
    printError("calc: " .. tostring(err))
else
    print(m.format(value))
end
