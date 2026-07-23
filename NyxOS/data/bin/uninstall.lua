-- /bin/uninstall.lua : désinstallation complète de NyxOS
-- Interface graphique Basalt avec scan en temps réel
-- Usage : uninstall

local nyxlib = dofile("/lib/nyxlib.lua")
local users = dofile("/lib/users.lua")

-- Essai multiple de chargement de Basalt
local basaltOk, basalt = pcall(dofile, "/lib/basalt.lua")
if not basaltOk or not basalt then
    -- Essai depuis le répertoire courant (pour tests depuis disk)
    basaltOk, basalt = pcall(dofile, "data/lib/basalt.lua")
end
if not basaltOk or not basalt then
    -- Essai depuis le chemin relatif
    basaltOk, basalt = pcall(dofile, "../lib/basalt.lua")
end

-- Mode texte de secours si Basalt n'est pas disponible
local function textMode()
    local args = { ... }
    local forceMode = false
    
    for _, arg in ipairs(args) do
        if arg == "--force" then
            forceMode = true
        end
    end
    
    -- Vérifie que NyxOS est installé
    if not fs.exists("/etc/nyx-release") then
        print("NyxOS n'est pas installe sur cet ordinateur.")
        return
    end
    
    -- Affiche les informations de l'installation
    local releaseFile = fs.open("/etc/nyx-release", "r")
    local releaseInfo = releaseFile.readAll()
    releaseFile.close()
    
    print("=== Désinstallation de NyxOS ===")
    print("")
    print(releaseInfo)
    print("")
    
    if not forceMode then
        print("ATTENTION : Cette operation va supprimer COMPLETEMENT NyxOS.")
        print("Les fichiers suivants seront supprimes :")
        print("  - /bin/* (toutes les commandes NyxOS)")
        print("  - /lib/* (toutes les bibliothèques NyxOS)")
        print("  - /etc/* (configuration, utilisateurs)")
        print("  - /home/* (tous les dossiers utilisateurs)")
        print("  - /var/* (données temporaires)")
        print("  - /startup.lua (script de démarrage)")
        print("")
        print("L'ordinateur redémarrera en mode vanilla CC: Tweaked.")
        print("")
        
        -- Liste les utilisateurs pour avertir
        local userList = users.load()
        if #userList > 0 then
            print("Utilisateurs qui seront supprimes :")
            for _, u in ipairs(userList) do
                local adminStr = u.admin and " (admin)" or ""
                print("  - " .. u.username .. adminStr)
            end
            print("")
        end
        
        write("Confirmer la désinstallation ? (tapez 'oui' pour confirmer) : ")
        local answer = read()
        if answer ~= "oui" then
            print("Désinstallation annulee.")
            return
        end
    end
    
    print("")
    print("Suppression des fichiers...")
    
    -- Fonction pour supprimer récursivement un dossier
    local function removeRecursive(path)
        if not fs.exists(path) then
            return
        end
        if fs.isDir(path) then
            for _, name in ipairs(fs.list(path)) do
                local item = fs.combine(path, name)
                removeRecursive(item)
            end
            fs.delete(path)
        else
            fs.delete(path)
        end
    end
    
    -- Supprime les dossiers NyxOS
    local dirsToRemove = {
        "/bin",
        "/lib",
        "/etc",
        "/home",
        "/var",
    }
    
    for _, dir in ipairs(dirsToRemove) do
        if fs.exists(dir) then
            print("  Suppression de " .. dir .. "...")
            removeRecursive(dir)
        end
    end
    
    -- Supprime le startup.lua
    if fs.exists("/startup.lua") then
        print("  Suppression de /startup.lua...")
        fs.delete("/startup.lua")
    end
    
    -- Nettoie les fichiers restants à la racine qui pourraient appartenir à NyxOS
    local rootFiles = fs.list("/")
    local nyxFiles = {".DS_Store", "rom"} -- fichiers à préserver
    for _, name in ipairs(rootFiles) do
        local path = "/" .. name
        if fs.isDir(path) then
            -- Préserve les dossiers système CC: Tweaked
            if name ~= "rom" and name ~= ".DS_Store" then
                print("  Suppression de " .. path .. "...")
                removeRecursive(path)
            end
        else
            -- Préserve les fichiers système
            local preserve = false
            for _, preserveName in ipairs(nyxFiles) do
                if name == preserveName then
                    preserve = true
                    break
                end
            end
            if not preserve then
                print("  Suppression de " .. path .. "...")
                fs.delete(path)
            end
        end
    end
    
    print("")
    print("Désinstallation terminee avec succes.")
    print("")
    print("NyxOS a été completement supprime de cet ordinateur.")
    print("L'ordinateur redémarrera en mode vanilla CC: Tweaked.")
    print("")
    print("Appuyez sur une touche pour redémarrer...")
    os.pullEvent("key")
    
    print("Redémarrage...")
    os.reboot()
end

-- Interface graphique Basalt
local function guiMode()
    -- Vérifie que NyxOS est installé
    if not fs.exists("/etc/nyx-release") then
        print("NyxOS n'est pas installe sur cet ordinateur.")
        return
    end
    
    local palette = colors or colours
    local main = basalt.getMainFrame():setBackground(palette.black)
    local w, h = main:getWidth(), main:getHeight()
    
    -- Charge les informations de l'installation
    local releaseFile = fs.open("/etc/nyx-release", "r")
    local releaseInfo = releaseFile.readAll()
    releaseFile.close()
    
    -- Charge la liste des utilisateurs
    local userList = users.load()
    
    -- Titre
    main:addLabel()
        :setText("Désinstallation de NyxOS")
        :setForeground(palette.red)
        :setPosition(2, 2)
    
    -- Informations de l'installation
    local infoLabel = main:addLabel()
        :setText(releaseInfo)
        :setForeground(palette.lightGray)
        :setPosition(2, 4)
    
    -- Label de statut de scan
    local scanStatus = main:addLabel()
        :setText("Scan des fichiers en cours...")
        :setForeground(palette.yellow)
        :setPosition(2, 7)
    
    -- Liste des fichiers/dossiers à supprimer
    local fileList = main:addList()
        :setPosition(2, 8)
        :setSize(w - 4, math.min(6, h - 18))
        :setBackground(palette.gray)
        :setForeground(palette.white)
        :setSelectedBackground(palette.blue)
        :setSelectedForeground(palette.white)
    
    -- Liste des utilisateurs
    local userListDisplay = main:addList()
        :setPosition(2, 15)
        :setSize(w - 4, math.min(4, h - 22))
        :setBackground(palette.darkGray)
        :setForeground(palette.white)
        :setSelectedBackground(palette.purple)
        :setSelectedForeground(palette.white)
    
    -- Label d'avertissement
    local warningLabel = main:addLabel()
        :setText("ATTENTION: Cette operation est IRREVERSIBLE")
        :setForeground(palette.red)
        :setPosition(2, h - 6)
    
    -- Boutons
    local uninstallButton = main:addButton()
        :setText("Désinstaller")
        :setPosition(2, h - 2)
        :setSize(15, 1)
        :setBackground(palette.red)
        :setForeground(palette.white)
    
    local cancelButton = main:addButton()
        :setText("Annuler")
        :setPosition(19, h - 2)
        :setSize(12, 1)
        :setBackground(palette.gray)
        :setForeground(palette.white)
    
    -- Label de progression
    local progressLabel = main:addLabel()
        :setText("")
        :setForeground(palette.green)
        :setPosition(w - 25, h - 2)
    
    -- Fonction pour scanner les fichiers
    local function scanFiles()
        fileList:clearItems()
        scanStatus:setText("Scan des fichiers en cours...")
        scanStatus:setForeground(palette.yellow)
        basalt.update()
        sleep(0.5) -- Délai pour voir le scan en cours
        
        local items = {
            "/bin/* (commandes)",
            "/lib/* (bibliothèques)",
            "/etc/* (configuration)",
            "/home/* (utilisateurs)",
            "/var/* (temporaire)",
            "/startup.lua (démarrage)"
        }
        
        for i, item in ipairs(items) do
            fileList:addItem(item)
        end
        
        scanStatus:setText("Scan termine - " .. #items .. " elements trouves")
        scanStatus:setForeground(palette.green)
        basalt.update()
        sleep(0.3) -- Délai pour voir le résultat
    end
    
    -- Fonction pour afficher les utilisateurs
    local function displayUsers()
        userListDisplay:clearItems()
        
        if #userList > 0 then
            for _, u in ipairs(userList) do
                local adminStr = u.admin and " [ADMIN]" or ""
                userListDisplay:addItem(u.username .. adminStr)
            end
        else
            userListDisplay:addItem("Aucun utilisateur")
        end
    end
    
    -- Bouton Annuler
    cancelButton:onClick(function()
        basalt.stop()
        print("Désinstallation annulee.")
    end)
    
    -- Bouton Désinstaller
    uninstallButton:onClick(function()
        -- Fenêtre de confirmation finale
        local confirmWindow = basalt.createFrame()
            :setSize(40, 8)
            :setPosition(math.floor((w - 40) / 2), math.floor((h - 8) / 2))
            :setBackground(palette.gray)
        
        confirmWindow:addLabel()
            :setText("CONFIRMATION FINALE")
            :setForeground(palette.red)
            :setPosition(2, 2)
        
        confirmWindow:addLabel()
            :setText("Toutes les donnees seront PERDUES")
            :setForeground(palette.white)
            :setPosition(2, 3)
        
        confirmWindow:addLabel()
            :setText("Tapez 'CONFIRMER' pour continuer:")
            :setForeground(palette.yellow)
            :setPosition(2, 5)
        
        local confirmInput = confirmWindow:addInput()
            :setPosition(2, 6)
            :setSize(36, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)
        
        local confirmBtn = confirmWindow:addButton()
            :setText("Confirmer")
            :setPosition(2, 7)
            :setSize(18, 1)
            :setBackground(palette.red)
            :setForeground(palette.white)
        
        local cancelBtn = confirmWindow:addButton()
            :setText("Annuler")
            :setPosition(22, 7)
            :setSize(16, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
        
        cancelBtn:onClick(function()
            confirmWindow:hide()
        end)
        
        confirmBtn:onClick(function()
            local input = confirmInput:getText()
            if input ~= "CONFIRMER" then
                return
            end
            
            confirmWindow:hide()
            
            -- Désinstallation
            local function removeRecursive(path)
                if not fs.exists(path) then
                    return
                end
                if fs.isDir(path) then
                    for _, name in ipairs(fs.list(path)) do
                        local item = fs.combine(path, name)
                        removeRecursive(item)
                    end
                    fs.delete(path)
                else
                    fs.delete(path)
                end
            end
            
            local dirsToRemove = {"/bin", "/lib", "/etc", "/home", "/var"}
            
            for i, dir in ipairs(dirsToRemove) do
                if fs.exists(dir) then
                    progressLabel:setText("Suppression de " .. dir .. "...")
                    removeRecursive(dir)
                end
            end
            
            if fs.exists("/startup.lua") then
                progressLabel:setText("Suppression de /startup.lua...")
                fs.delete("/startup.lua")
            end
            
            local rootFiles = fs.list("/")
            for _, name in ipairs(rootFiles) do
                local path = "/" .. name
                if fs.isDir(path) then
                    if name ~= "rom" and name ~= ".DS_Store" then
                        removeRecursive(path)
                    end
                else
                    local preserve = (name == ".DS_Store" or name == "rom")
                    if not preserve then
                        fs.delete(path)
                    end
                end
            end
            
            progressLabel:setText("Termine!")
            progressLabel:setForeground(palette.green)
            
            basalt.stop()
            
            term.clear()
            term.setCursorPos(1, 1)
            print("Désinstallation terminee avec succes.")
            print("Redémarrage...")
            sleep(2)
            os.reboot()
        end)
        
        confirmWindow:show()
        confirmInput:setFocused(true)
    end)
    
    -- Initialisation
    scanFiles()
    displayUsers()
    
    basalt.run()
end

-- Point d'entrée principal
if not basaltOk or not basalt then
    print("Basalt non disponible. Mode texte de secours.")
    textMode(...)
else
    term.clear()
    term.setCursorPos(1, 1)
    guiMode()
end
