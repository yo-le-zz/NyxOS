-- c interpreter - uninstaller
dofile("/lib/interpreters.lua").unregister("c")
if fs.exists("/lib/interp/c.lua") then fs.delete("/lib/interp/c.lua") end
print("c interpreter removed.")
