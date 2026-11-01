-- python interpreter - uninstaller
dofile("/lib/interpreters.lua").unregister("python")
if fs.exists("/lib/interp/python.lua") then fs.delete("/lib/interp/python.lua") end
print("python interpreter removed.")
