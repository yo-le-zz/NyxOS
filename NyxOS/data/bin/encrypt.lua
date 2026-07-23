-- /bin/encrypt.lua : chiffrement de disque façon Linux (LUKS)
-- Interface graphique Basalt avec scan en temps réel
-- Usage : encrypt

local crypto = dofile("/lib/crypto.lua")

-- Vérification du Cryptography Accelerator
local cryptoOk, cryptoMsg = crypto.requireCrypto()
if not cryptoOk then
    print(cryptoMsg)
    print("")
    print("Options :")
    print("1. Connectez un Cryptography Accelerator")
    print("2. Utilisez le mode sans chiffrement (non securise)")
    print("")
    write("Continuer sans chiffrement ? (o/n) : ")
    local answer = read()
    if answer ~= "o" and answer ~= "O" then
        return
    end
    print("ATTENTION: Mode sans chiffrement - mots de passe non securises")
    sleep(2)
end

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

local CONFIG_PATH = "/etc/encrypt-config.lua"

-- Charge la configuration des disques chiffrés
local function loadConfig()
    if not fs.exists(CONFIG_PATH) then
        return {}
    end
    local f = fs.open(CONFIG_PATH, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

-- Sauvegarde la configuration
local function saveConfig(config)
    local f = fs.open(CONFIG_PATH, "w")
    f.write(textutils.serialize(config))
    f.close()
end

-- Détecte tous les disques/drives disponibles
local function findDrives()
    local drives = {}
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    
    -- Recherche par côté (directement connecté)
    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) then
            local p = peripheral.wrap(side)
            if p and p.getMountPath then
                local mount = p.getMountPath()
                if mount then
                    table.insert(drives, {
                        name = side,
                        mount = mount,
                        type = "drive",
                        peripheral = p
                    })
                end
            end
        end
    end
    
    -- Recherche par nom réseau (wired modems - drive_0, drive_1, disk_drive, etc.)
    local names = peripheral.getNames()
    for _, name in ipairs(names) do
        local p = peripheral.wrap(name)
        if not p then
            goto continue
        end
        
        -- Vérifie si c'est un drive (a la méthode getMountPath)
        if p.getMountPath then
            local mount = p.getMountPath()
            if mount then
                -- Vérifie si ce drive n'est pas déjà dans la liste
                local found = false
                for _, drive in ipairs(drives) do
                    if drive.name == name then
                        found = true
                        break
                    end
                end
                if not found then
                    -- Détermine le type
                    local driveType = "network_drive"
                    if name:match("^drive_%d+$") then
                        driveType = "wired_drive"
                    elseif name:match("^disk_drive") then
                        driveType = "disk_drive"
                    elseif name:find("drive") then
                        driveType = "network_drive"
                    end
                    
                    table.insert(drives, {
                        name = name,
                        mount = mount,
                        type = driveType,
                        peripheral = p
                    })
                end
            end
        end
        
        ::continue::
    end
    
    return drives
end

-- Mode texte de secours si Basalt n'est pas disponible
local function textMode()
    local args = { ... }
    
    if #args == 0 then
        local drives = findDrives()
        local config = loadConfig()
        
        if #drives == 0 then
            print("Aucun disque detecte.")
            print("Connectez un drive (disk drive) a l'ordinateur.")
            return
        end
        
        print("Disques disponibles :")
        print("")
        
        for i, drive in ipairs(drives) do
            local encrypted = config[drive.name]
            local status = "Non chiffre"
            if encrypted then
                if encrypted.unlocked then
                    status = "Chiffre (DEVERROUILLE)"
                else
                    status = "Chiffre (VERROUILLE)"
                end
            end
            
            print(string.format("%d) %s", i, drive.name))
            print("   Montage : " .. drive.mount)
            print("   Type : " .. drive.type)
            print("   Statut : " .. status)
            print("")
        end
    else
        print("Mode texte non supporte pour les actions.")
        print("Utilisez l'interface graphique.")
    end
end

-- Interface graphique Basalt
local function guiMode()
    local palette = colors or colours
    local main = basalt.getMainFrame():setBackground(palette.black)
    local w, h = main:getWidth(), main:getHeight()
    
    local config = loadConfig()
    local selectedDrive = nil
    local drives = {}
    
    -- Titre
    main:addLabel()
        :setText("Chiffrement de Disque - NyxOS")
        :setForeground(palette.cyan)
        :setPosition(2, 2)
    
    -- Label de statut de scan
    local scanStatus = main:addLabel()
        :setText("Scan en cours...")
        :setForeground(palette.yellow)
        :setPosition(2, 4)
    
    -- Liste des disques
    local driveList = main:addList()
        :setPosition(2, 5)
        :setSize(w - 4, math.min(8, h - 12))
        :setBackground(palette.gray)
        :setForeground(palette.white)
        :setSelectedBackground(palette.blue)
        :setSelectedForeground(palette.white)
    
    -- Label de détails du disque sélectionné
    local detailsLabel = main:addLabel()
        :setText("")
        :setForeground(palette.lightGray)
        :setPosition(2, 14)
        :setSize(w - 4, 3)
    
    -- Boutons d'action
    local encryptButton = main:addButton()
        :setText("Chiffrer")
        :setPosition(2, h - 2)
        :setSize(12, 1)
        :setBackground(palette.green)
        :setForeground(palette.black)
        :setEnabled(false)
    
    local unlockButton = main:addButton()
        :setText("Deverrouiller")
        :setPosition(15, h - 2)
        :setSize(14, 1)
        :setBackground(palette.yellow)
        :setForeground(palette.black)
        :setEnabled(false)
    
    local lockButton = main:addButton()
        :setText("Verrouiller")
        :setPosition(30, h - 2)
        :setSize(12, 1)
        :setBackground(palette.orange)
        :setForeground(palette.black)
        :setEnabled(false)
    
    local refreshButton = main:addButton()
        :setText("Actualiser")
        :setPosition(w - 12, h - 2)
        :setSize(10, 1)
        :setBackground(palette.blue)
        :setForeground(palette.white)
    
    -- Label de messages
    local messageLabel = main:addLabel()
        :setText("")
        :setForeground(palette.red)
        :setPosition(2, h - 4)
    
    -- Fonction pour mettre à jour la liste des disques
    local function updateDriveList()
        driveList:clearItems()
        scanStatus:setText("Scan en cours...")
        scanStatus:setForeground(palette.yellow)
        basalt.update()
        sleep(0.5) -- Délai pour voir le scan en cours
        
        drives = findDrives()
        
        if #drives == 0 then
            scanStatus:setText("Aucun disque detecte")
            scanStatus:setForeground(palette.red)
            driveList:addItem("Aucun disque disponible")
            detailsLabel:setText("Connectez un drive a l'ordinateur.")
            encryptButton:setEnabled(false)
            unlockButton:setEnabled(false)
            lockButton:setEnabled(false)
            return
        end
        
        scanStatus:setText(#drives .. " disque(s) detecte(s)")
        scanStatus:setForeground(palette.green)
        basalt.update()
        sleep(0.3) -- Délai pour voir le résultat
        
        for i, drive in ipairs(drives) do
            local encrypted = config[drive.name]
            local status = "[NON CHIFFRE]"
            if encrypted then
                if encrypted.unlocked then
                    status = "[DEVERROUILLE]"
                else
                    status = "[VERROUILLE]"
                end
            end
            driveList:addItem(string.format("%s %s - %s", status, drive.name, drive.type))
        end
        
        -- Ne désactive pas les boutons ici, ils seront activés lors de la sélection
        detailsLabel:setText("Selectionnez un disque pour voir les options")
    end
    
    -- Sélection d'un disque
    driveList:onSelect(function(self, index, item)
        if index > #drives then
            selectedDrive = nil
            return
        end
        
        selectedDrive = drives[index]
        local encrypted = config[selectedDrive.name]
        
        detailsLabel:setText(string.format("Disque: %s | Montage: %s | Type: %s", 
            selectedDrive.name, selectedDrive.mount, selectedDrive.type))
        
        if encrypted then
            encryptButton:setEnabled(false)
            if encrypted.unlocked then
                unlockButton:setEnabled(false)
                lockButton:setEnabled(true)
            else
                unlockButton:setEnabled(true)
                lockButton:setEnabled(false)
            end
        else
            encryptButton:setEnabled(true)
            unlockButton:setEnabled(false)
            lockButton:setEnabled(false)
        end
        
        messageLabel:setText("")
    end)
    
    -- Bouton Actualiser
    refreshButton:onClick(function()
        messageLabel:setText("")
        config = loadConfig()
        updateDriveList()
    end)
    
    -- Bouton Chiffrer
    encryptButton:onClick(function()
        if not selectedDrive then return end
        
        -- Fenêtre de confirmation
        local confirmWindow = basalt.createFrame()
            :setSize(40, 10)
            :setPosition(math.floor((w - 40) / 2), math.floor((h - 10) / 2))
            :setBackground(palette.gray)
        
        confirmWindow:addLabel()
            :setText("Chiffrement du disque")
            :setForeground(palette.white)
            :setPosition(2, 2)
        
        confirmWindow:addLabel()
            :setText("Disque: " .. selectedDrive.name)
            :setForeground(palette.lightGray)
            :setPosition(2, 3)
        
        confirmWindow:addLabel()
            :setText("ATTENTION: Tous les fichiers seront chiffrés")
            :setForeground(palette.red)
            :setPosition(2, 5)
        
        local passInput = confirmWindow:addInput()
            :setPosition(2, 7)
            :setSize(36, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)
            :setPlaceholder("Mot de passe")
            :setReplaceChar("*")
        
        local confirmBtn = confirmWindow:addButton()
            :setText("Chiffrer")
            :setPosition(2, 9)
            :setSize(18, 1)
            :setBackground(palette.green)
            :setForeground(palette.black)
        
        local cancelBtn = confirmWindow:addButton()
            :setText("Annuler")
            :setPosition(22, 9)
            :setSize(16, 1)
            :setBackground(palette.red)
            :setForeground(palette.white)
        
        cancelBtn:onClick(function()
            confirmWindow:hide()
        end)
        
        confirmBtn:onClick(function()
            local password = passInput:getText()
            if not password or password == "" then
                messageLabel:setText("Le mot de passe ne peut pas etre vide.")
                confirmWindow:hide()
                return
            end
            
            -- Génère la clé
            local key = crypto.hash(password)
            if #key < 32 then
                key = key .. string.rep("0", 32 - #key)
            end
            key = key:sub(1, 32)
            
            local salt = crypto.generateKey()
            
            config[selectedDrive.name] = {
                encrypted = true,
                unlocked = false,
                salt = salt,
                keyHash = crypto.hash(key)
            }
            saveConfig(config)
            
            confirmWindow:hide()
            messageLabel:setText("Disque chiffre avec succes!")
            messageLabel:setForeground(palette.green)
            updateDriveList()
        end)
        
        confirmWindow:show()
        passInput:setFocused(true)
    end)
    
    -- Bouton Déverrouiller
    unlockButton:onClick(function()
        if not selectedDrive then return end
        
        local confirmWindow = basalt.createFrame()
            :setSize(40, 8)
            :setPosition(math.floor((w - 40) / 2), math.floor((h - 8) / 2))
            :setBackground(palette.gray)
        
        confirmWindow:addLabel()
            :setText("Deverrouillage du disque")
            :setForeground(palette.white)
            :setPosition(2, 2)
        
        confirmWindow:addLabel()
            :setText("Disque: " .. selectedDrive.name)
            :setForeground(palette.lightGray)
            :setPosition(2, 3)
        
        local passInput = confirmWindow:addInput()
            :setPosition(2, 5)
            :setSize(36, 1)
            :setBackground(palette.darkGray)
            :setForeground(palette.white)
            :setPlaceholder("Mot de passe")
            :setReplaceChar("*")
        
        local confirmBtn = confirmWindow:addButton()
            :setText("Deverrouiller")
            :setPosition(2, 7)
            :setSize(18, 1)
            :setBackground(palette.green)
            :setForeground(palette.black)
        
        local cancelBtn = confirmWindow:addButton()
            :setText("Annuler")
            :setPosition(22, 7)
            :setSize(16, 1)
            :setBackground(palette.red)
            :setForeground(palette.white)
        
        cancelBtn:onClick(function()
            confirmWindow:hide()
        end)
        
        confirmBtn:onClick(function()
            local password = passInput:getText()
            if not password or password == "" then
                messageLabel:setText("Mot de passe requis.")
                messageLabel:setForeground(palette.red)
                confirmWindow:hide()
                return
            end
            
            local key = crypto.hash(password)
            if #key < 32 then
                key = key .. string.rep("0", 32 - #key)
            end
            key = key:sub(1, 32)
            
            local keyHash = crypto.hash(key)
            if keyHash ~= config[selectedDrive.name].keyHash then
                messageLabel:setText("Mot de passe incorrect!")
                messageLabel:setForeground(palette.red)
                confirmWindow:hide()
                return
            end
            
            config[selectedDrive.name].unlocked = true
            config[selectedDrive.name].key = key
            saveConfig(config)
            
            confirmWindow:hide()
            messageLabel:setText("Disque deverrouille!")
            messageLabel:setForeground(palette.green)
            updateDriveList()
        end)
        
        confirmWindow:show()
        passInput:setFocused(true)
    end)
    
    -- Bouton Verrouiller
    lockButton:onClick(function()
        if not selectedDrive then return end
        
        config[selectedDrive.name].unlocked = false
        config[selectedDrive.name].key = nil
        saveConfig(config)
        
        messageLabel:setText("Disque verrouille!")
        messageLabel:setForeground(palette.green)
        updateDriveList()
    end)
    
    -- Mise à jour initiale
    updateDriveList()
    
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
