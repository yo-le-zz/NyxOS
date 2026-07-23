-- install.lua : installeur de NyxOS
-- A executer UNE fois depuis l'ordinateur (le dossier "data" doit etre a cote de ce fichier)

-- Système de log pour conserver les erreurs
local logFile = nil
local logPath = "/install.log"

local function initLog()
    logFile = fs.open(logPath, "w")
    if logFile then
        logFile.write("=== LOG D'INSTALLATION NYXOS ===\n")
        logFile.write("Date: " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n")
        logFile.write("\n")
    end
end

local function log(message)
    if logFile then
        logFile.write(message .. "\n")
        logFile.flush()
    end
end

local function closeLog()
    if logFile then
        logFile.write("\n=== FIN DU LOG ===\n")
        logFile.close()
    end
end

local function clearScreen()
    term.setBackgroundColor((colors or colours).black)
    term.clear()
    term.setCursorPos(1, 1)
end

local function printStatus(message)
    term.setTextColor((colors or colours).white)
    print(message)
    log("[STATUS] " .. message)
end

local function printSuccess(message)
    term.setTextColor((colors or colours).green)
    print(message)
    log("[SUCCESS] " .. message)
    term.setTextColor((colors or colours).white)
end

local function printError(message)
    term.setTextColor((colors or colours).red)
    print(message)
    log("[ERROR] " .. message)
    term.setTextColor((colors or colours).white)
end

local function printInfo(message)
    term.setTextColor((colors or colours).cyan)
    print(message)
    log("[INFO] " .. message)
    term.setTextColor((colors or colours).white)
end

-- Initialisation du log
initLog()

clearScreen()
printInfo("=== Installation de NyxOS ===")
printStatus("")
printInfo("Un fichier de log sera cree: " .. logPath)
printStatus("")
sleep(1)

if fs.exists("/etc/nyx-release") then
    printError("NyxOS semble deja installe sur cet ordinateur.")
    write("Continuer quand meme ? (o/n) ")
    local answer = read()
    if answer ~= "o" and answer ~= "O" then
        printError("Installation annulee.")
        return
    end
    clearScreen()
    printInfo("=== Installation de NyxOS ===")
    printStatus("")
end

-- Le dossier "data" doit se trouver a cote de install.lua
local dataDir = fs.getDir(shell.getRunningProgram())
dataDir = fs.combine(dataDir, "data")

printStatus("Scan du dossier d'installation...")
if not fs.exists(dataDir) then
    printError("Erreur : dossier 'data' introuvable a cote de install.lua")
    printStatus("(cherche dans : " .. dataDir .. ")")
    printStatus("")
    printInfo("Appuyez sur une touche pour continuer...")
    os.pullEvent("key")
    return
end
printSuccess("Dossier 'data' trouve : " .. dataDir)
printStatus("")
sleep(1) -- Délai pour voir le message

printStatus("Creation de l'arborescence...")

local dirs = {
    "/bin",
    "/etc",
    "/etc/apt",
    "/var",
    "/var/apt",
    "/var/apt/tmp",
    "/var/run",
    "/lib",
}
for _, d in ipairs(dirs) do
    if not fs.exists(d) then
        fs.makeDir(d)
        printStatus("  Creation : " .. d)
    else
        printStatus("  Existe deja : " .. d)
    end
end
printSuccess("Arborescence cree.")
printStatus("")

printStatus("Copie des fichiers systeme...")

local function copyDir(src, dst)
    if not fs.exists(src) then return end
    for _, name in ipairs(fs.list(src)) do
        local s = fs.combine(src, name)
        local d = fs.combine(dst, name)
        if fs.isDir(s) then
            if not fs.exists(d) then
                fs.makeDir(d)
            end
            copyDir(s, d)
        else
            if fs.exists(d) then
                fs.delete(d)
            end
            fs.copy(s, d)
            printStatus("  Copie : " .. name)
        end
    end
end

printStatus("  Copie de /bin...")
copyDir(fs.combine(dataDir, "bin"), "/bin")
printStatus("  Copie de /lib...")
copyDir(fs.combine(dataDir, "lib"), "/lib")
printSuccess("Fichiers systeme copies.")
printStatus("")
sleep(0.5) -- Délai pour voir le message

printStatus("Verification des fichiers critiques...")

-- Vérification explicite de basalt.lua
if fs.exists(fs.combine(dataDir, "lib/basalt.lua")) then
    if fs.exists("/lib/basalt.lua") then fs.delete("/lib/basalt.lua") end
    fs.copy(fs.combine(dataDir, "lib/basalt.lua"), "/lib/basalt.lua")
    printStatus("  Installation forcee : basalt.lua")
    -- Test de chargement
    local testOk, testBasalt = pcall(dofile, "/lib/basalt.lua")
    if testOk and testBasalt then
        printSuccess("  basalt.lua charge avec succes")
    else
        printError("  ERREUR: basalt.lua ne peut pas etre charge")
        printError("  Details: " .. tostring(testBasalt))
        printStatus("")
        printInfo("Appuyez sur une touche pour continuer...")
        os.pullEvent("key")
    end
else
    printError("  ERREUR: basalt.lua introuvable dans data/lib")
    printStatus("")
    printInfo("Appuyez sur une touche pour continuer...")
    os.pullEvent("key")
end
sleep(0.5) -- Délai pour voir les messages

printStatus("Configuration des fichiers specifiques...")

-- Copier shellui.lua manuellement pour s'assurer qu'est bien installé
if fs.exists(fs.combine(dataDir, "lib/shellui.lua")) then
    if fs.exists("/lib/shellui.lua") then fs.delete("/lib/shellui.lua") end
    fs.copy(fs.combine(dataDir, "lib/shellui.lua"), "/lib/shellui.lua")
    printStatus("  Installation : shellui.lua")
end

if fs.exists(fs.combine(dataDir, "etc/motd")) then
    if fs.exists("/etc/motd") then fs.delete("/etc/motd") end
    fs.copy(fs.combine(dataDir, "etc/motd"), "/etc/motd")
    printStatus("  Installation : motd")
end

if not fs.exists("/etc/apt/installed.lua") then
    fs.copy(fs.combine(dataDir, "etc/apt/installed.lua"), "/etc/apt/installed.lua")
    printStatus("  Installation : apt/installed.lua")
end

if fs.exists("/startup.lua") then
    fs.delete("/startup.lua")
    printStatus("  Suppression : ancien startup.lua")
end
fs.copy(fs.combine(dataDir, "startup.lua"), "/startup.lua")
printStatus("  Installation : startup.lua")
printSuccess("Configuration terminee.")
printStatus("")

-- A ce stade, /lib/basalt.lua, /lib/users.lua et /lib/theme.lua sont
-- deja copies sur l'ordinateur : on peut les utiliser pour un assistant
-- d'installation graphique (facon CloverOS), avec un repli texte simple
-- si Basalt echoue pour une raison quelconque.

local users = dofile("/lib/users.lua")
local theme = dofile("/lib/theme.lua")
local crypto = dofile("/lib/crypto.lua")

------------------------------------------------------------------
-- Detection peripheriques et chiffrement de disque (optionnel)
------------------------------------------------------------------
local function findDrives()
    local drives = {}
    local sides = {"top", "bottom", "left", "right", "front", "back"}

    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) then
            local p = peripheral.wrap(side)
            if p and p.getMountPath then
                local mount = p.getMountPath()
                if mount then
                    table.insert(drives, { name = side, mount = mount, type = "drive" })
                end
            end
        end
    end

    for _, name in ipairs(peripheral.getNames()) do
        local p = peripheral.wrap(name)
        if p and p.getMountPath then
            local mount = p.getMountPath()
            if mount then
                local found = false
                for _, drive in ipairs(drives) do
                    if drive.name == name then found = true break end
                end
                if not found then
                    table.insert(drives, { name = name, mount = mount, type = "network_drive" })
                end
            end
        end
    end

    return drives
end

local function showCryptoStatus()
    print("")
    local cryptoAvailable, cryptoName = crypto.isAvailable()
    if cryptoAvailable then
        printSuccess("Cryptography Accelerator detecte : " .. (cryptoName or "?"))
        printStatus("  SHA-256 materiel et chiffrement AES disponibles.")
    else
        printInfo("Cryptography Accelerator non detecte.")
        printStatus("  Les mots de passe utiliseront un hash logiciel (moins securise).")
        printStatus("  Branchez un peripherique 'cryptographic_accelerator' pour plus de securite.")
    end
    print("")
end

local function promptDiskEncryption()
    local drives = findDrives()
    if #drives == 0 then
        printInfo("Aucun disque/drive detecte pour le chiffrement.")
        printStatus("  Vous pourrez chiffrer un disque plus tard avec la commande 'encrypt'.")
        return
    end

    print("Disques detectes :")
    for i, d in ipairs(drives) do
        print("  " .. i .. ") " .. d.name .. "  ->  " .. d.mount)
    end
    print("")
    write("Chiffrer un disque maintenant ? (o/n, entree = non) : ")
    local answer = read()
    if answer ~= "o" and answer ~= "O" then
        printStatus("Chiffrement de disque ignore.")
        return
    end

    write("Numero du disque a chiffrer : ")
    local num = tonumber(read())
    if not num or not drives[num] then
        printError("Choix invalide, chiffrement annule.")
        return
    end

    local drive = drives[num]
    write("Mot de passe de chiffrement du disque : ")
    local encPass = read("*")
    print("")
    if encPass == nil or encPass == "" then
        printError("Mot de passe vide, chiffrement annule.")
        return
    end

    local key = crypto.hash(encPass)
    if #key < 32 then
        key = key .. string.rep("0", 32 - #key)
    end
    key = key:sub(1, 32)
    local salt = crypto.generateKey()

    local config = {}
    config[drive.name] = {
        encrypted = true,
        unlocked = false,
        salt = salt,
        keyHash = crypto.hash(key),
    }

    local f = fs.open("/etc/encrypt-config.lua", "w")
    f.write(textutils.serialize(config))
    f.close()

    printSuccess("Disque '" .. drive.name .. "' configure pour le chiffrement.")
    printStatus("  Deverrouillez-le apres le reboot avec : encrypt " .. drive.name .. " open")
end

------------------------------------------------------------------
-- Etape texte (fiable, toujours disponible)
------------------------------------------------------------------
local function textWizard()
    print("")
    write("Nom d'utilisateur : ")
    local username = read()
    while username == nil or username == "" do
        write("Le nom ne peut pas etre vide. Nom d'utilisateur : ")
        username = read()
    end

    write("Mot de passe (optionnel, entree pour aucun) : ")
    local password = read("*")

    write("Nom de l'ordinateur (hostname, entree pour 'nyxos') : ")
    local hostname = read()
    if hostname == nil or hostname == "" then
        hostname = "nyxos"
    end

    print("")
    print("Couleur d'accent :")
    for i, preset in ipairs(theme.presets) do
        print("  " .. i .. ") " .. preset.name)
    end
    write("Choix (entree pour 1) : ")
    local choice = tonumber(read())
    local preset = theme.presets[choice] or theme.presets[1]

    return username, password, hostname, preset
end

------------------------------------------------------------------
-- Etape graphique (Basalt), facon assistant CloverOS : ecrans
-- "Bienvenue -> Compte -> Theme -> Recapitulatif", navigables au
-- clavier/souris.
------------------------------------------------------------------
local function basaltWizard()
    local basaltOk, basalt = pcall(dofile, "/lib/basalt.lua")
    if not basaltOk or not basalt then
        return nil
    end

    local result = nil
    local ok = pcall(function()
        local palette = colors or colours
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()

        local accentPreview = theme.presets[1].accent
        local selectedPresetIndex = 1

        main:addLabel()
            :setText("Installation de NyxOS")
            :setForeground(accentPreview)
            :setPosition(3, 2)

        main:addLabel()
            :setText("Nom d'utilisateur :")
            :setForeground(palette.white)
            :setPosition(3, 5)
        local userInput = main:addInput()
            :setPosition(3, 6)
            :setSize(30, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setPlaceholder("ex: alice")

        main:addLabel()
            :setText("Mot de passe (optionnel) :")
            :setForeground(palette.white)
            :setPosition(3, 8)
        local passInput = main:addInput()
            :setPosition(3, 9)
            :setSize(30, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setReplaceChar("*")

        main:addLabel()
            :setText("Nom de l'ordinateur :")
            :setForeground(palette.white)
            :setPosition(3, 11)
        local hostInput = main:addInput()
            :setPosition(3, 12)
            :setSize(30, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setPlaceholder("nyxos")

        main:addLabel()
            :setText("Couleur d'accent :")
            :setForeground(palette.white)
            :setPosition(3, 14)
        local themeList = main:addList()
            :setPosition(3, 15)
            :setSize(30, math.min(6, #theme.presets))
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setSelectedBackground(accentPreview)
            :setSelectedForeground(palette.black)
        for _, preset in ipairs(theme.presets) do
            themeList:addItem(preset.name)
        end
        themeList:onSelect(function(self, index, item)
            selectedPresetIndex = index
        end)

        local status = main:addLabel()
            :setText("")
            :setForeground(palette.red)
            :setPosition(3, h - 3)

        local installButton = main:addButton()
            :setText("Installer NyxOS")
            :setPosition(3, h - 1)
            :setSize(20, 1)
            :setBackground(accentPreview)
            :setForeground(palette.black)
            :onClick(function()
                local username = userInput:getText()
                if username == nil or username == "" then
                    status:setText("Le nom d'utilisateur ne peut pas etre vide.")
                    return
                end
                local hostname = hostInput:getText()
                if hostname == nil or hostname == "" then
                    hostname = "nyxos"
                end
                result = {
                    username = username,
                    password = passInput:getText(),
                    hostname = hostname,
                    preset = theme.presets[selectedPresetIndex] or theme.presets[1],
                }
                basalt.stop()
            end)

        userInput:setFocused(true)
        basalt.run()
    end)

    if not ok then
        return nil
    end
    return result
end

print("")
printInfo("Lancement de l'assistant d'installation...")
printStatus("")

showCryptoStatus()

local wizardResult = basaltWizard()

local username, password, hostname, preset
if wizardResult then
    username = wizardResult.username
    password = wizardResult.password
    hostname = wizardResult.hostname
    preset = wizardResult.preset
else
    -- Basalt indisponible/echoue : assistant texte classique.
    clearScreen()
    printInfo("=== Installation de NyxOS ===")
    printStatus("")
    printStatus("Basalt non disponible. Assistant texte.")
    printStatus("")
    username, password, hostname, preset = textWizard()
end

clearScreen()
printInfo("=== Installation de NyxOS ===")
printStatus("")
printStatus("Configuration de l'utilisateur et du systeme...")

local nyxlib = dofile("/lib/nyxlib.lua")
nyxlib.setHostname(hostname)
printStatus("  Hostname defini : " .. hostname)

-- Reinitialise completement /etc/passwd (installation propre) puis cree
-- le premier compte, administrateur par defaut.
if fs.exists("/etc/passwd") then
    fs.delete("/etc/passwd")
end
users.add(username, password, true)
printStatus("  Utilisateur cree : " .. username)

theme.save({ name = preset.name, accent = preset.accent })
printStatus("  Theme defini : " .. preset.name)

printStatus("")
printStatus("Configuration du chiffrement de disque (optionnel)...")
promptDiskEncryption()

local releaseFile = fs.open("/etc/nyx-release", "w")
releaseFile.write("NyxOS 1.0\nInstalle le " .. os.date("%d/%m/%Y") .. "\n")
releaseFile.close()
printStatus("  Fichier release cree")
printSuccess("")
printSuccess("Installation terminee !")
printStatus("")
printStatus("Utilisateur '" .. username .. "' cree (administrateur).")
printStatus("Theme : " .. preset.name)
printStatus("")
printInfo("Redemarre l'ordinateur (commande 'reboot') pour finaliser.")
printInfo("Au demarrage : choisis 'Demarrer NyxOS' dans le menu de boot puis connecte-toi.")
printStatus("")
printInfo("Log de l'installation disponible dans: " .. logPath)
printStatus("")
printInfo("Appuyez sur une touche pour continuer...")
os.pullEvent("key")

-- Fermeture du log
closeLog()
