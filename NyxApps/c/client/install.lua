-- c interpreter (skeleton) - installer
local here = fs.getDir(shell.getRunningProgram())
if not fs.exists("/lib/interp") then fs.makeDir("/lib/interp") end
if fs.exists("/lib/interp/c.lua") then fs.delete("/lib/interp/c.lua") end
fs.copy(fs.combine(here, "c.lua"), "/lib/interp/c.lua")
dofile("/lib/nyxapi.lua").registerInterpreter("c", "c", "/lib/interp/c.lua")
print("c interpreter (skeleton) installed. Run: run file.c")
