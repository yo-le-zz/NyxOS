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
        else
            -- libraries are always refreshed; data/ is only copied when new
            -- (see below), so existing accounts are never overwritten.
            if fs.exists(d) then fs.delete(d) end
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

copyDir(fs.combine(baseDir, "lib"), fs.combine(installDir, "lib"))

if not fs.exists(fs.combine(installDir, "data")) then
    copyDir(fs.combine(baseDir, "data"), fs.combine(installDir, "data"))
    print("Dossier data cree (base de donnees vierge).")
else
    print("Dossier data existant conserve (comptes deja presents).")
end

if fs.exists(fs.combine(installDir, "main.lua")) then fs.delete(fs.combine(installDir, "main.lua")) end
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
