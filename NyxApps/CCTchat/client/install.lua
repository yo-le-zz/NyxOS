-- CCTchat Client - Installateur
local baseDir = fs.getDir(shell.getRunningProgram())
local installDir = "/cctchat-client"

local function copyDir(src, dst)
    if not fs.exists(dst) then fs.makeDir(dst) end
    for _, name in ipairs(fs.list(src)) do
        local s = fs.combine(src, name)
        local d = fs.combine(dst, name)
        if fs.isDir(s) then
            copyDir(s, d)
        elseif not fs.exists(d) then
            fs.copy(s, d)
        end
    end
end

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.lime)
print("=========================================")
print("   Installation de CCTchat - Client")
print("=========================================")
term.setTextColor(colors.white)

if not fs.exists(installDir) then
    fs.makeDir(installDir)
end

copyDir(fs.combine(baseDir, "libs"), fs.combine(installDir, "libs"))
copyDir(fs.combine(baseDir, "data"), fs.combine(installDir, "data"))
fs.copy(fs.combine(baseDir, "main.lua"), fs.combine(installDir, "main.lua"))

local f = fs.open("/cct-client", "w")
f.write('shell.run("' .. installDir .. '/main.lua")\n')
f.close()

term.setTextColor(colors.lime)
print("")
print("Installation terminee !")
term.setTextColor(colors.white)
print("Tapez 'cct-client' depuis n'importe quel dossier pour lancer le chat.")
