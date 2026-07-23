-- CCTchat Serveur - Desinstallateur
local installDir = "/cctchat-serv"

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.red)
print("=========================================")
print("  Desinstallation de CCTchat - Serveur")
print("=========================================")
term.setTextColor(colors.white)

if not fs.exists(installDir) and not fs.exists("/cct-serv") then
    print("CCTchat Serveur n'est pas installe.")
    return
end

term.setTextColor(colors.yellow)
write("Supprimer aussi la base de donnees (comptes/messages) ? (o/n) : ")
term.setTextColor(colors.white)
local answer = read()

if fs.exists("/cct-serv") then
    fs.delete("/cct-serv")
end

if answer == "o" or answer == "O" then
    if fs.exists(installDir) then fs.delete(installDir) end
    print("CCTchat Serveur et ses donnees ont ete supprimes.")
else
    if fs.exists(fs.combine(installDir, "libs")) then fs.delete(fs.combine(installDir, "libs")) end
    if fs.exists(fs.combine(installDir, "main.lua")) then fs.delete(fs.combine(installDir, "main.lua")) end
    print("CCTchat Serveur desinstalle, la base de donnees a ete conservee dans " .. installDir .. "/data")
end
