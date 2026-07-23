-- /bin/apt.lua : gestionnaire de paquets NyxOS
--
-- Usage :
--   apt install <url|chemin>   (ex: apt install https://exemple.com/install.lua)
--   apt install ./disk         (installe depuis install.lua present sur le disque)
--   apt remove <paquet>        (supprime les fichiers, garde la config /etc)
--   apt purge <paquet>         (supprime tout, y compris la config)
--   apt list                   (liste les paquets installes)
--   apt info <paquet>          (details sur un paquet installe)
--
-- apt sait installer deux types d'installeurs :
--  1) Un script simple qui ecrit lui-meme ses fichiers avec fs.open(..., "w")
--     (ex: exemples/paquet_hello/install.lua).
--  2) Un installeur "disquette" a plusieurs fichiers (un peu comme CCRF :
--     install.lua + fichiers voisins sur le disque), qui utilise
--     fs.getDir(shell.getRunningProgram()) pour retrouver ses fichiers
--     voisins, et fs.copy/fs.makeDir pour les installer. Pour que ca marche,
--     apt execute reellement l'installeur via shell.run (et pas juste load()
--     + pcall()) afin que shell.getRunningProgram() renvoie le bon chemin.

local nyxlib = dofile("/lib/nyxlib.lua")

local args = {...}
local cmd = args[1]

local function usage()
    print("Usage :")
    print("  apt install <url|chemin>")
    print("  apt remove <paquet>")
    print("  apt purge <paquet>")
    print("  apt list")
    print("  apt info <paquet>")
end

local function normalize(path)
    return "/" .. fs.combine("", path)
end

-- Execute `fn` en interceptant temporairement fs.open (ecriture),
-- fs.copy, fs.move, fs.makeDir et fs.delete, afin de savoir exactement
-- quels fichiers/dossiers un installeur a touches sur le disque, meme
-- s'il ne fait que des fs.copy/fs.makeDir (comme un installeur type
-- disquette CCRF) plutot que d'ecrire lui-meme le contenu des fichiers.
local function withTrackedFs(fn)
    local written = {}
    local dirs = {}

    local orig = {
        open = fs.open,
        copy = fs.copy,
        move = fs.move,
        delete = fs.delete,
        makeDir = fs.makeDir,
    }

    fs.open = function(path, mode)
        local handle = orig.open(path, mode)
        if handle and (mode == "w" or mode == "a" or mode == "wb" or mode == "ab") then
            written[normalize(path)] = true
        end
        return handle
    end

    fs.copy = function(src, dst)
        orig.copy(src, dst)
        written[normalize(dst)] = true
    end

    fs.move = function(src, dst)
        orig.move(src, dst)
        written[normalize(dst)] = true
        written[normalize(src)] = nil
        dirs[normalize(src)] = nil
    end

    fs.delete = function(path)
        orig.delete(path)
        written[normalize(path)] = nil
        dirs[normalize(path)] = nil
    end

    fs.makeDir = function(path)
        orig.makeDir(path)
        dirs[normalize(path)] = true
    end

    local ok, err = pcall(fn)

    fs.open = orig.open
    fs.copy = orig.copy
    fs.move = orig.move
    fs.delete = orig.delete
    fs.makeDir = orig.makeDir

    local files, dirList = {}, {}
    for p in pairs(written) do table.insert(files, p) end
    for p in pairs(dirs) do table.insert(dirList, p) end

    return ok, err, files, dirList
end

-- Un fichier ecrit directement a la racine ("/") est considere comme une
-- commande executable et deplace automatiquement dans /bin
local function relocateFiles(files)
    local final = {}
    for _, path in ipairs(files) do
        local dir = fs.getDir(path)
        local name = fs.getName(path)
        if dir == "" or dir == "/" or dir == "." then
            local dest = "/bin/" .. name
            if path ~= dest then
                if fs.exists(dest) then
                    fs.delete(dest)
                end
                fs.move(path, dest)
            end
            table.insert(final, dest)
        else
            table.insert(final, path)
        end
    end
    return final
end

-- Un paquet peut fournir un fichier "control.lua" a cote de son
-- install.lua, un peu comme le fichier control d'un paquet .deb Debian.
-- Il doit renvoyer une table : { name=, version=, description=, depends={} }.
-- Purement optionnel : un install.lua seul reste un paquet valide.
local function loadControl(runPath)
    local dir = fs.getDir(runPath)
    local controlPath = fs.combine(dir, "control.lua")
    if fs.exists(controlPath) then
        local ok, data = pcall(dofile, controlPath)
        if ok and type(data) == "table" then
            return data
        end
    end
    return nil
end

-- Pour un paquet distant (URL), tente de recuperer un control.lua voisin
-- (meme nom de dossier que install.lua, best-effort : une 404 n'est pas
-- une erreur, le paquet reste installable sans metadonnees).
local function fetchRemoteControl(installUrl)
    if not http then return nil end
    local controlUrl = installUrl:gsub("install%.lua$", "control.lua")
    if controlUrl == installUrl then return nil end
    local response = http.get(controlUrl)
    if not response then return nil end
    local body = response.readAll()
    response.close()
    local fn, err = load(body, "control")
    if not fn then return nil end
    local ok, data = pcall(fn)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

if not cmd then
    usage()
    return
end

if cmd == "install" then
    local source = args[2]
    if not source then
        print("Precise une URL ou un chemin (ex: apt install ./disk)")
        return
    end

    local pkgName = args[3]
    local runPath
    local tempFile = nil
    local control = nil

    if source:match("^https?://") then
        if not http then
            print("L'API http n'est pas activee sur cet ordinateur.")
            return
        end
        control = fetchRemoteControl(source)
        pkgName = pkgName or (control and control.name) or
            source:match("([^/]+)%.lua$") or source:match("([^/]+)/?$") or ("paquet_" .. os.epoch("utc"))
        print("Telechargement de " .. source .. " ...")
        local response, err = http.get(source)
        if not response then
            print("Echec du telechargement : " .. tostring(err))
            return
        end
        local body = response.readAll()
        response.close()

        if not fs.exists("/var/apt/tmp") then
            fs.makeDir("/var/apt/tmp")
        end
        tempFile = "/var/apt/tmp/" .. pkgName .. "_install.lua"
        local f = fs.open(tempFile, "w")
        f.write(body)
        f.close()
        runPath = tempFile
    else
        local path = shell.resolve(source)
        if fs.isDir(path) then
            path = fs.combine(path, "install.lua")
        end
        if not fs.exists(path) then
            print("Fichier introuvable : " .. path)
            return
        end
        control = loadControl(path)
        pkgName = pkgName or (control and control.name) or fs.getName(fs.getDir(path))
        if pkgName == nil or pkgName == "" then
            pkgName = "paquet_" .. os.epoch("utc")
        end
        runPath = path
    end

    if control then
        print("Installation du paquet '" .. pkgName .. "'" ..
            (control.version and (" v" .. tostring(control.version)) or "") .. "...")
        if control.description then
            print("  " .. control.description)
        end
    else
        print("Installation du paquet '" .. pkgName .. "'...")
    end

    -- Execute reellement l'installeur via shell.run : shell.getRunningProgram()
    -- renverra runPath, ce qui permet aux installeurs multi-fichiers (type
    -- CCRF) de retrouver leurs fichiers voisins avec fs.getDir(...).
    local ok, err, files, dirs = withTrackedFs(function()
        return shell.run(runPath)
    end)

    if tempFile and fs.exists(tempFile) then
        fs.delete(tempFile)
    end

    if not ok then
        print("Echec de l'installation : " .. tostring(err))
        return
    end

    files = relocateFiles(files)

    local uninstallScript = nil
    for _, f in ipairs(files) do
        if fs.getName(f) == "uninstall.lua" then
            uninstallScript = f
        end
    end

    local manifest = nyxlib.loadManifest()
    manifest[pkgName] = {
        source = source,
        files = files,
        dirs = dirs,
        uninstallScript = uninstallScript,
        installedAt = os.epoch("utc"),
        version = control and control.version or nil,
        description = control and control.description or nil,
        depends = control and control.depends or nil,
    }
    nyxlib.saveManifest(manifest)

    print("Paquet '" .. pkgName .. "' installe (" .. #files .. " fichier(s), " .. #dirs .. " dossier(s)) :")
    for _, f in ipairs(files) do
        print("  " .. f)
    end
    if uninstallScript then
        print("Script de desinstallation dedie detecte : " .. uninstallScript)
        print("('apt remove/purge " .. pkgName .. "' proposera de l'utiliser)")
    end

elseif cmd == "remove" or cmd == "purge" then
    local pkgName = args[2]
    if not pkgName then
        print("Precise le nom du paquet (voir 'apt list').")
        return
    end

    local manifest = nyxlib.loadManifest()
    local entry = manifest[pkgName]
    if not entry then
        print("Paquet inconnu : " .. pkgName)
        return
    end

    -- Une desinstallation complete efface aussi la config (/etc), soit
    -- parce que c'est un "purge", soit parce que le paquet a son propre
    -- script de desinstallation dedie (ex: uninstall.lua d'un installeur
    -- type CCRF) qui a ete execute avec succes.
    local fullClean = (cmd == "purge")

    if entry.uninstallScript and fs.exists(entry.uninstallScript) then
        print("Ce paquet fournit son propre script de desinstallation :")
        print("  " .. entry.uninstallScript)
        write("L'utiliser pour une desinstallation propre ? (o/n) ")
        local ans = read()
        if ans == "o" or ans == "O" then
            print("Execution de " .. entry.uninstallScript .. " ...")
            local ranOk = shell.run(entry.uninstallScript)
            if ranOk then
                print("Script de desinstallation termine.")
                fullClean = true
            else
                print("Le script a rencontre une erreur, nettoyage manuel en secours...")
            end
        end
    end

    local removed = 0
    local remaining = {}
    for _, path in ipairs(entry.files or {}) do
        local isConfig = path:match("^/etc/") ~= nil
        if fs.exists(path) then
            if fullClean or not isConfig then
                fs.delete(path)
                removed = removed + 1
            else
                table.insert(remaining, path)
            end
        end
    end

    -- Nettoie les dossiers crees par le paquet, du plus profond au moins
    -- profond, uniquement s'ils sont vides (on ne supprime jamais un
    -- dossier qui contiendrait encore autre chose).
    if entry.dirs then
        local sorted = {}
        for _, d in ipairs(entry.dirs) do table.insert(sorted, d) end
        table.sort(sorted, function(a, b) return #a > #b end)
        for _, d in ipairs(sorted) do
            local isConfig = d:match("^/etc/") ~= nil
            if fs.exists(d) and fs.isDir(d) and (fullClean or not isConfig) then
                if #fs.list(d) == 0 then
                    fs.delete(d)
                end
            end
        end
    end

    if fullClean then
        manifest[pkgName] = nil
        print("Paquet '" .. pkgName .. "' " .. (cmd == "purge" and "purge" or "supprime completement") ..
            (removed > 0 and (" (" .. removed .. " fichier(s) supprime(s))") or "") .. ".")
    else
        entry.files = remaining
        entry.removed = true
        print("Paquet '" .. pkgName .. "' supprime (" .. removed .. " fichier(s)).")
        if #remaining > 0 then
            print("Config conservee dans /etc. Utilise 'apt purge " .. pkgName .. "' pour tout effacer.")
        end
    end
    nyxlib.saveManifest(manifest)

elseif cmd == "list" then
    local manifest = nyxlib.loadManifest()
    local count = 0
    for name, entry in pairs(manifest) do
        count = count + 1
        local status = entry.removed and " (supprime, config conservee)" or ""
        local extra = entry.uninstallScript and " [uninstall.lua fourni]" or ""
        local version = entry.version and (" v" .. tostring(entry.version)) or ""
        print(name .. version .. status .. extra .. " - " .. #(entry.files or {}) .. " fichier(s)")
    end
    if count == 0 then
        print("Aucun paquet installe.")
    end

elseif cmd == "info" then
    local pkgName = args[2]
    if not pkgName then
        print("Precise le nom du paquet (voir 'apt list').")
        return
    end
    local manifest = nyxlib.loadManifest()
    local entry = manifest[pkgName]
    if not entry then
        print("Paquet inconnu : " .. pkgName)
        return
    end
    print("Paquet       : " .. pkgName)
    if entry.version then
        print("Version      : " .. tostring(entry.version))
    end
    if entry.description then
        print("Description  : " .. tostring(entry.description))
    end
    if entry.depends then
        print("Dependances  : " .. table.concat(entry.depends, ", "))
    end
    print("Source       : " .. tostring(entry.source))
    if entry.installedAt then
        print("Installe le  : " .. os.date("%d/%m/%Y %H:%M:%S", math.floor(entry.installedAt / 1000)))
    end
    print("Fichiers     : " .. #(entry.files or {}))
    print("Dossiers     : " .. #(entry.dirs or {}))
    print("Uninstaller  : " .. (entry.uninstallScript or "aucun"))
    if entry.removed then
        print("Statut       : supprime (config conservee)")
    end

else
    usage()
end
