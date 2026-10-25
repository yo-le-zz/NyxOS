-- CCTchat Serveur - Installateur
local baseDir = fs.getDir(shell.getRunningProgram())
local installDir = "/cctchat-serv"

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
print("   Installation de CCTchat - Serveur")
print("=========================================")
term.setTextColor(colors.white)

if fs.exists(installDir) then
    print("Une installation existe deja dans " .. installDir)
else
    fs.makeDir(installDir)
end

copyDir(fs.combine(baseDir, "libs"), fs.combine(installDir, "libs"))

if not fs.exists(fs.combine(installDir, "data")) then
    copyDir(fs.combine(baseDir, "data"), fs.combine(installDir, "data"))
    print("Dossier data cree (base de donnees vierge).")
else
    print("Dossier data existant conserve (comptes deja presents).")
end

fs.copy(fs.combine(baseDir, "main.lua"), fs.combine(installDir, "main.lua"))

local f = fs.open("/cct-serv", "w")
f.write('shell.run("' .. installDir .. '/main.lua", ...)\n')
f.close()

term.setTextColor(colors.lime)
print("")
print("Installation terminee !")
term.setTextColor(colors.white)
print("Tapez 'cct-serv' pour lancer le serveur (nom demande a chaque fois).")
print("Ou 'cct-serv NomDuServeur' pour lui donner un nom directement.")
