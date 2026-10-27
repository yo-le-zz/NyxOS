-- RedioNet Server - uninstaller (NyxOS)
-- Only removes RedioNet's own files. (The previous version wiped EVERY
-- file on the computer except /rom.)

for _, path in ipairs({ "/lib/redionet-server", "/bin/redionet-server.lua", "/redionet-server.lua" }) do
    if fs.exists(path) then
        fs.delete(path)
        print("Removed " .. path)
    end
end
print("RedioNet Server uninstalled.")
