-- RedioNet Client - uninstaller (NyxOS)
for _, path in ipairs({ "/lib/redionet", "/bin/redionet.lua", "/redionet.lua" }) do
    if fs.exists(path) then
        fs.delete(path)
        print("Removed " .. path)
    end
end
print("RedioNet Client uninstalled.")
