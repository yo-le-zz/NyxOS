-- CCTchat Client - Desinstallateur
local installDir = "/cctchat-client"

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.red)
print("=========================================")
print("  Desinstallation de CCTchat - Client")
print("=========================================")
term.setTextColor(colors.white)

if not fs.exists(installDir) and not fs.exists("/cct-client") then
    print("CCTchat Client n'est pas installe.")
    return
end

if fs.exists("/cct-client") then fs.delete("/cct-client") end
if fs.exists(installDir) then fs.delete(installDir) end

print("CCTchat Client a ete desinstalle.")
