-- CCRF - ComputerCraftResetFactory
-- reset.lua : lance le reset usine (et "ccrf config" pour la configuration)
-- Installe dans /ccrf_data/reset.lua, appelable via la commande /ccrf

local BASE = "/ccrf_data"
local ui = dofile(BASE .. "/lib/ui.lua")
local permissions = dofile(BASE .. "/lib/permissions.lua")
local scanner = dofile(BASE .. "/lib/scanner.lua")

local LOG_PATH = BASE .. "/data/logs/reset.log"

local function writeLog(totalFiles, totalDirs, cancelled)
    local f = fs.open(LOG_PATH, "a")
    if f then
        local date = os.date("%Y-%m-%d %H:%M:%S")
        if cancelled then
            f.writeLine(date .. " - RESET ANNULE")
        else
            f.writeLine(date .. " - RESET : " .. totalFiles .. " fichiers, " .. totalDirs .. " dossiers supprimes")
        end
        f.close()
    end
end

local args = { ... }
local config = permissions.loadConfig()

-- ============================================================
-- Sous-commande : reset config
-- ============================================================
if args[1] == "config" then
    if not permissions.checkPassword(config) then
        print("Mot de passe incorrect.")
        return
    end

    while true do
        print("")
        print("=== CCRF CONFIG ===")
        print("1) Voir la blacklist")
        print("2) Ajouter un chemin")
        print("3) Retirer un chemin")
        print("4) Definir / changer le mot de passe")
        print("5) Quitter")
        write("> ")
        local choice = read()

        if choice == "1" then
            print("Blacklist actuelle :")
            if #config.blacklist == 0 then
                print("  (vide)")
            else
                for i, path in ipairs(config.blacklist) do
                    print("  " .. i .. ") " .. path)
                end
            end

        elseif choice == "2" then
            write("Chemin a ajouter : ")
            local path = read():gsub("^/", "")
            if path ~= "" and not permissions.CORE_NAMES[path] then
                table.insert(config.blacklist, path)
                permissions.saveConfig(config)
                print("Ajoute : " .. path)
            else
                print("Chemin invalide ou protege par le systeme.")
            end

        elseif choice == "3" then
            if #config.blacklist == 0 then
                print("La blacklist est vide.")
            else
                for i, path in ipairs(config.blacklist) do
                    print("  " .. i .. ") " .. path)
                end
                write("Numero a retirer : ")
                local num = tonumber(read())
                if num and config.blacklist[num] then
                    local removed = table.remove(config.blacklist, num)
                    permissions.saveConfig(config)
                    print("Retire : " .. removed)
                else
                    print("Numero invalide.")
                end
            end

        elseif choice == "4" then
            write("Nouveau mot de passe (vide = aucun) : ")
            local pass = read("*")
            config.password = (pass == "") and "" or permissions.simpleHash(pass)
            permissions.saveConfig(config)
            print("Mot de passe mis a jour.")

        elseif choice == "5" then
            break
        else
            print("Choix invalide.")
        end
    end
    return
end

-- ============================================================
-- Reset usine complet
-- ============================================================
ui.title("RESET USINE (CCRF)")
term.setTextColor(colors.white)
ui.center("Tout sera supprime sauf /rom, les disques et CCRF", 6)
ui.center("ENTREE = confirmer", 8)

if not ui.waitEnterOrCancel() then
    ui.clear()
    term.setTextColor(colors.red)
    ui.center("ANNULE", 5)
    sleep(1.5)
    return
end

if not permissions.checkPassword(config) then
    ui.clear()
    term.setTextColor(colors.red)
    ui.center("MOT DE PASSE INCORRECT", 5)
    sleep(1.5)
    return
end

ui.clear()
term.setTextColor(colors.yellow)
ui.center("SCAN EN COURS...", 2)

local function isProtected(path)
    return permissions.isProtected(path, config)
end

local files, dirs = scanner.scan("", isProtected)
local totalFiles, totalDirs = #files, #dirs
local total = totalFiles + totalDirs

ui.clear()
term.setTextColor(colors.white)
ui.center("Fichiers a supprimer : " .. totalFiles, 3)
ui.center("Dossiers a supprimer : " .. totalDirs, 4)
ui.center("Total : " .. total .. " elements", 5)

if total == 0 then
    term.setTextColor(colors.green)
    ui.center("Rien a supprimer.", 8)
    sleep(2)
    return
end

term.setTextColor(colors.orange)
ui.center("ENTREE = confirmer la suppression", 8)
ui.center("Autre touche = annuler", 9)

if not ui.waitEnterOrCancel() then
    ui.clear()
    term.setTextColor(colors.red)
    ui.center("ANNULE", 5)
    sleep(1.5)
    writeLog(0, 0, true)
    return
end

ui.clear()
local done = 0

for _, file in ipairs(files) do
    done = done + 1
    ui.printStep(file, "fichier", done, total)
    pcall(fs.delete, file)
end

for _, dir in ipairs(dirs) do
    done = done + 1
    ui.printStep(dir, "dossier", done, total)
    pcall(fs.delete, dir)
end

writeLog(totalFiles, totalDirs, false)

ui.clear()
term.setTextColor(colors.green)
ui.center("RESET TERMINE", 5)
sleep(2)
ui.clear()
os.reboot()
