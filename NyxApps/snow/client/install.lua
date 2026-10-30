-- snow - installer (NyxOS)
local here = fs.getDir(shell.getRunningProgram())
if fs.exists("snow.lua") then fs.delete("snow.lua") end
fs.copy(fs.combine(here, "snow.lua"), "snow.lua")   -- apt moves it to /bin
print("snow installed. Run: snow")
