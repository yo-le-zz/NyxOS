-- CCTchat Client - Désinstallateur NyxOS

local paths = {
    "/bin/cct-client.lua",
    "/lib/cctchat",
    "/etc/cctchat"
}


term.clear()
term.setCursorPos(1, 1)

term.setTextColor(colors.red)
print("=========================================")
print("  Desinstallation de CCTchat - Client")
print("=========================================")

term.setTextColor(colors.white)


local installed = false

for _, path in ipairs(paths) do
    if fs.exists(path) then
        installed = true
        break
    end
end


if not installed then
    print("CCTchat Client n'est pas installe.")
    return
end


for _, path in ipairs(paths) do
    if fs.exists(path) then
        fs.delete(path)
        print("Supprime : " .. path)
    end
end


term.setTextColor(colors.lime)
print("")
print("CCTchat Client a ete desinstalle.")
term.setTextColor(colors.white)