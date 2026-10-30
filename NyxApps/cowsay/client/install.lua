-- cowsay - installer (NyxOS)
local here = fs.getDir(shell.getRunningProgram())
if fs.exists("cowsay.lua") then fs.delete("cowsay.lua") end
fs.copy(fs.combine(here, "cowsay.lua"), "cowsay.lua")   -- apt moves it to /bin
print("cowsay installed. Run: cowsay")
