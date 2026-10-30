-- todo - installer (NyxOS)
local here = fs.getDir(shell.getRunningProgram())
if fs.exists("todo.lua") then fs.delete("todo.lua") end
fs.copy(fs.combine(here, "todo.lua"), "todo.lua")   -- apt moves it to /bin
print("todo installed. Run: todo")
