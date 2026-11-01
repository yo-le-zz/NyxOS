-- python interpreter (skeleton) - installer
local here = fs.getDir(shell.getRunningProgram())
if not fs.exists("/lib/interp") then fs.makeDir("/lib/interp") end
if fs.exists("/lib/interp/python.lua") then fs.delete("/lib/interp/python.lua") end
fs.copy(fs.combine(here, "python.lua"), "/lib/interp/python.lua")
dofile("/lib/nyxapi.lua").registerInterpreter("python", "py", "/lib/interp/python.lua")
print("python interpreter (skeleton) installed. Run: run file.py")
