-- fortune - uninstaller (NyxOS)
if fs.exists("/bin/fortune.lua") then fs.delete("/bin/fortune.lua") end
print("fortune uninstalled.")
