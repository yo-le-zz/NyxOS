-- install.lua : installeur / metteur a jour de NyxOS
-- Place install.lua et le dossier data/ cote a cote, puis lance : install
--
-- Si NyxOS est deja installe, les fichiers systeme sont mis a jour
-- en preservant utilisateurs, configuration et /home.

local VERSION = "1.0.0"
local palette = colors or colours

------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------

local function getInstallDir()
    local prog = shell.getRunningProgram()
    if prog and prog ~= "" then
        local dir = fs.getDir(prog)
        if dir and dir ~= "" then
            return dir
        end
    end
    return "."
end

local function findDataDir()
    local base = getInstallDir()
    local candidates = {
        fs.combine(base, "data"),
        "data",
        "disk/data",
    }
    for _, path in ipairs(candidates) do
        if fs.isDir(path) then
            return path
        end
    end
    return nil
end

local function loadBasalt(dataDir)
    local paths = {}
    if dataDir then
        table.insert(paths, fs.combine(dataDir, "lib/basalt.lua"))
    end
    table.insert(paths, "/lib/basalt.lua")
    table.insert(paths, "data/lib/basalt.lua")
    table.insert(paths, "disk/data/lib/basalt.lua")
    for _, path in ipairs(paths) do
        if fs.exists(path) then
            local ok, mod = pcall(dofile, path)
            if ok and type(mod) == "table" and mod.getMainFrame then
                return mod
            end
        end
    end
    return nil
end

local function loadThemePresets(dataDir)
    local defaults = {
        { name = "Violet Nyx",      accent = palette.purple },
        { name = "Bleu Ocean",      accent = palette.blue },
        { name = "Cyan",            accent = palette.cyan },
        { name = "Vert Foret",      accent = palette.green },
        { name = "Orange Couchant", accent = palette.orange },
        { name = "Rouge Cramoisi",  accent = palette.red },
        { name = "Magenta",         accent = palette.magenta },
        { name = "Gris Classique",  accent = palette.lightGray },
    }
    if dataDir then
        local themePath = fs.combine(dataDir, "lib/theme.lua")
        if fs.exists(themePath) then
            local ok, theme = pcall(dofile, themePath)
            if ok and theme and theme.presets then
                return theme.presets
            end
        end
    end
    return defaults
end

local function isInstalled()
    return fs.exists("/etc/nyx-release") or fs.exists("/startup.lua")
end

local function getInstalledVersion()
    if not fs.exists("/etc/nyx-release") then
        return "inconnue"
    end
    local f = fs.open("/etc/nyx-release", "r")
    local line = f.readLine() or "inconnue"
    f.close()
    return line
end

local function ensureDir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

local function copyFile(src, dst)
    ensureDir(fs.getDir(dst))
    if fs.exists(dst) then
        fs.delete(dst)
    end
    fs.copy(src, dst)
end

local function copyTree(src, dst, skip)
    skip = skip or {}
    if not fs.isDir(src) then
        return
    end
    ensureDir(dst)
    for _, name in ipairs(fs.list(src)) do
        local srcPath = fs.combine(src, name)
        local dstPath = fs.combine(dst, name)
        if skip[dstPath] or skip[name] then
            -- preserve
        elseif fs.isDir(srcPath) then
            copyTree(srcPath, dstPath, skip)
        else
            copyFile(srcPath, dstPath)
        end
    end
end

local function writeRelease()
    local f = fs.open("/etc/nyx-release", "w")
    f.write("NyxOS " .. VERSION .. "\n")
    f.write("Installe le " .. os.date("%d/%m/%Y %H:%M:%S") .. "\n")
    f.close()
end

-- Fichiers /etc a ne pas ecraser lors d'une mise a jour
local UPDATE_SKIP = {
    ["/etc/passwd"] = true,
    ["/etc/hostname"] = true,
    ["/etc/nyx-theme.lua"] = true,
    ["/etc/nyx-display.lua"] = true,
    ["/etc/encrypt-config.lua"] = true,
    ["/etc/nyx-release"] = true,
    ["/etc/apt/installed.lua"] = true,
}

local function deployFiles(dataDir, isUpdate)
    print(isUpdate and "Mise a jour des fichiers systeme..." or "Installation des fichiers...")

    ensureDir("/bin")
    ensureDir("/lib")
    ensureDir("/etc")
    ensureDir("/var")
    ensureDir("/home")

    copyTree(fs.combine(dataDir, "bin"), "/bin")
    copyTree(fs.combine(dataDir, "lib"), "/lib")

    copyFile(fs.combine(dataDir, "startup.lua"), "/startup.lua")

    if fs.exists(fs.combine(dataDir, "etc/motd")) then
        copyFile(fs.combine(dataDir, "etc/motd"), "/etc/motd")
    end

    ensureDir("/etc/apt")
    if not isUpdate or not fs.exists("/etc/apt/installed.lua") then
        if fs.exists(fs.combine(dataDir, "etc/apt/installed.lua")) then
            copyFile(fs.combine(dataDir, "etc/apt/installed.lua"), "/etc/apt/installed.lua")
        end
    end

    if not isUpdate then
        if fs.exists(fs.combine(dataDir, "etc/nyx-release")) then
            copyFile(fs.combine(dataDir, "etc/nyx-release"), "/etc/nyx-release")
        end
    end

    writeRelease()
end

local function applyConfig(config)
    local nyxlib = dofile("/lib/nyxlib.lua")
    local users = dofile("/lib/users.lua")
    local theme = dofile("/lib/theme.lua")

    nyxlib.setHostname(config.hostname)

    theme.save({ name = config.themeName, accent = config.accent })

    if users.count() == 0 then
        local ok, err = users.add(config.username, config.password, true)
        if not ok then
            print("Erreur creation utilisateur : " .. tostring(err))
            return false
        end
    end

    return true
end

------------------------------------------------------------------
-- Assistant texte
------------------------------------------------------------------

local function wizardText(presets, isUpdate)
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)

    if isUpdate then
        print("=== Mise a jour de NyxOS ===")
        print("")
        print("Version installee : " .. getInstalledVersion())
        print("Nouvelle version  : NyxOS " .. VERSION)
        print("")
        print("Les utilisateurs et la configuration seront preserves.")
        print("")
        write("Continuer la mise a jour ? (o/n) : ")
        local answer = read()
        if answer ~= "o" and answer ~= "O" and answer ~= "oui" then
            print("Mise a jour annulee.")
            return nil
        end
        return { update = true }
    end

    print("=== Installation de NyxOS " .. VERSION .. " ===")
    print("")

    write("Nom d'utilisateur (admin) : ")
    local username = read()
    while not username or username == "" do
        write("Le nom ne peut pas etre vide. Nom d'utilisateur : ")
        username = read()
    end

    write("Mot de passe (optionnel, Entree = aucun) : ")
    local password = read("*")

    write("Nom de l'ordinateur [" .. tostring(os.getComputerLabel() or "nyxos") .. "] : ")
    local hostname = read()
    if not hostname or hostname == "" then
        hostname = os.getComputerLabel() or "nyxos"
    end

    print("")
    print("Couleur d'accent :")
    for i, p in ipairs(presets) do
        print("  " .. i .. ") " .. p.name)
    end
    write("Choix [1] : ")
    local choice = tonumber(read()) or 1
    if choice < 1 or choice > #presets then choice = 1 end
    local preset = presets[choice]

    print("")
    write("Confirmer l'installation ? (o/n) : ")
    local confirm = read()
    if confirm ~= "o" and confirm ~= "O" and confirm ~= "oui" then
        print("Installation annulee.")
        return nil
    end

    return {
        update = false,
        username = username,
        password = password or "",
        hostname = hostname,
        themeName = preset.name,
        accent = preset.accent,
    }
end

------------------------------------------------------------------
-- Assistant Basalt
------------------------------------------------------------------

local function wizardBasalt(basalt, presets, isUpdate)
    local result = nil -- nil = echec, false = annule, table = ok
    local accent = presets[1].accent

    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()
        local cx = math.floor(w / 2)

        if isUpdate then
            main:addLabel()
                :setText("Mise a jour NyxOS")
                :setForeground(accent)
                :setPosition(math.max(1, cx - 8), 2)

            main:addLabel()
                :setText("Version actuelle : " .. getInstalledVersion())
                :setForeground(palette.white)
                :setPosition(2, 5)

            main:addLabel()
                :setText("Nouvelle version : NyxOS " .. VERSION)
                :setForeground(palette.lightGray)
                :setPosition(2, 7)

            main:addLabel()
                :setText("Utilisateurs et configuration preserves.")
                :setForeground(palette.gray)
                :setPosition(2, 10)

            main:addButton()
                :setText("Mettre a jour")
                :setPosition(math.max(1, cx - 8), h - 4)
                :setSize(16, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(function()
                    result = { update = true }
                    basalt.stop()
                end)

            main:addButton()
                :setText("Annuler")
                :setPosition(math.max(1, cx - 8), h - 2)
                :setSize(16, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :onClick(function()
                    result = false
                    basalt.stop()
                end)
        else
            local y = 2
            main:addLabel()
                :setText("Installation NyxOS " .. VERSION)
                :setForeground(accent)
                :setPosition(math.max(1, cx - 10), y)
            y = y + 3

            main:addLabel()
                :setText("Utilisateur (admin) :")
                :setForeground(palette.white)
                :setPosition(2, y)
            local userInput = main:addInput()
                :setPosition(2, y + 1)
                :setSize(w - 4, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
            y = y + 3

            main:addLabel()
                :setText("Mot de passe (optionnel) :")
                :setForeground(palette.white)
                :setPosition(2, y)
            local passInput = main:addInput()
                :setPosition(2, y + 1)
                :setSize(w - 4, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setReplaceChar("*")
            y = y + 3

            main:addLabel()
                :setText("Nom de l'ordinateur :")
                :setForeground(palette.white)
                :setPosition(2, y)
            local hostInput = main:addInput()
                :setPosition(2, y + 1)
                :setSize(w - 4, 1)
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setText(tostring(os.getComputerLabel() or "nyxos"))
            y = y + 3

            main:addLabel()
                :setText("Couleur d'accent :")
                :setForeground(palette.white)
                :setPosition(2, y)
            local themeList = main:addList()
                :setPosition(2, y + 1)
                :setSize(w - 4, math.min(#presets, 5))
                :setBackground(palette.gray)
                :setForeground(palette.white)
                :setSelectedBackground(accent)
                :setSelectedForeground(palette.black)
            for _, p in ipairs(presets) do
                themeList:addItem(p.name)
            end

            local selectedTheme = 1
            themeList:onSelect(function(self, index)
                selectedTheme = index
            end)

            local status = main:addLabel()
                :setText("Remplis les champs puis valide.")
                :setForeground(palette.lightGray)
                :setPosition(2, h - 4)

            local function submit()
                local username = userInput:getText()
                if not username or username == "" then
                    status:setText("Le nom d'utilisateur est obligatoire.")
                    return
                end
                local selected = selectedTheme
                if selected < 1 or selected > #presets then selected = 1 end
                local preset = presets[selected]
                result = {
                    update = false,
                    username = username,
                    password = passInput:getText() or "",
                    hostname = hostInput:getText() or "nyxos",
                    themeName = preset.name,
                    accent = preset.accent,
                }
                basalt.stop()
            end

            main:addButton()
                :setText("Installer")
                :setPosition(math.max(1, cx - 8), h - 2)
                :setSize(16, 1)
                :setBackground(accent)
                :setForeground(palette.black)
                :onClick(submit)

            userInput:setFocused(true)
        end

        basalt.run()
    end)

    if not ok then
        return nil
    end
    if result == false then
        return false
    end
    return result
end

------------------------------------------------------------------
-- Point d'entree
------------------------------------------------------------------

local function main()
    local dataDir = findDataDir()
    if not dataDir then
        print("Erreur : dossier data/ introuvable.")
        print("Place install.lua et le dossier data/ dans le meme repertoire.")
        return
    end

    local updateMode = isInstalled()
    local presets = loadThemePresets(dataDir)
    local basalt = loadBasalt(dataDir)

    local config
    if basalt then
        config = wizardBasalt(basalt, presets, updateMode)
        if config == false then
            print("Operation annulee.")
            return
        end
    else
        print("Basalt indisponible, mode texte.")
    end
    if not config then
        config = wizardText(presets, updateMode)
    end

    if not config then
        return
    end

    deployFiles(dataDir, config.update or updateMode)

    if not config.update and not updateMode then
        if not applyConfig(config) then
            return
        end
    end

    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
    if config.update or updateMode then
        print("Mise a jour terminee ! NyxOS " .. VERSION .. " est pret.")
    else
        print("Installation terminee ! NyxOS " .. VERSION .. " est pret.")
        print("Premier compte : " .. config.username .. " (administrateur)")
    end
    print("")
    print("Redemarrez l'ordinateur : reboot")
end

main()
