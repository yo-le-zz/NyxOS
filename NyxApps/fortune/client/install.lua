-- fortune - installer (NyxOS)
local here = fs.getDir(shell.getRunningProgram())
if fs.exists("fortune.lua") then fs.delete("fortune.lua") end
fs.copy(fs.combine(here, "fortune.lua"), "fortune.lua")   -- apt moves it to /bin
print("fortune installed. Run: fortune")
