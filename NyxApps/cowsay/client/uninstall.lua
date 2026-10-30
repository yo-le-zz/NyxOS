-- cowsay - uninstaller (NyxOS)
if fs.exists("/bin/cowsay.lua") then fs.delete("/bin/cowsay.lua") end
print("cowsay uninstalled.")
