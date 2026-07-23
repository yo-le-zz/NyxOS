-- /lib/nyxlib.lua
-- Fonctions utilitaires partagees par NyxOS

local nyxlib = {}

local MANIFEST_PATH = "/etc/apt/installed.lua"
local PASSWD_PATH = "/etc/passwd"
local SESSION_PATH = "/var/run/session.lua"

-- Lecture/ecriture generique de tables serialisees (utilise par le
-- manifeste apt, /etc/passwd, la config d'ecran, etc.)
function nyxlib.loadTable(path)
    if not fs.exists(path) then
        return {}
    end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

function nyxlib.saveTable(path, data)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(data))
    f.close()
end

function nyxlib.loadManifest()
    return nyxlib.loadTable(MANIFEST_PATH)
end

function nyxlib.saveManifest(manifest)
    nyxlib.saveTable(MANIFEST_PATH, manifest)
end

-- Session : quel utilisateur est actuellement connecte (ecrit par
-- /lib/login.lua au demarrage). Fichier volatile, efface a l'extinction
-- (il vit dans /var/run comme boot.time).
function nyxlib.loadSession()
    return nyxlib.loadTable(SESSION_PATH)
end

function nyxlib.saveSession(username)
    if not fs.exists("/var/run") then
        fs.makeDir("/var/run")
    end
    nyxlib.saveTable(SESSION_PATH, { username = username })
end

function nyxlib.clearSession()
    if fs.exists(SESSION_PATH) then
        fs.delete(SESSION_PATH)
    end
end

-- Compatibilite : /etc/passwd contient maintenant une LISTE
-- d'utilisateurs (voir /lib/users.lua). Ces deux fonctions restent
-- fournies pour les commandes qui ne s'interessent qu'a
-- "l'utilisateur courant" (whoami, passwd, neofetch...) : elles
-- renvoient/mettent a jour l'utilisateur actuellement connecte
-- (ou, a defaut de session, le premier compte du systeme).
function nyxlib.loadPasswd()
    local ok, users = pcall(dofile, "/lib/users.lua")
    if not ok or not users then
        return nyxlib.loadTable(PASSWD_PATH)
    end
    local session = nyxlib.loadSession()
    if session.username then
        local u = users.find(session.username)
        if u then
            return u
        end
    end
    local list = users.load()
    return list[1] or {}
end

function nyxlib.savePasswd(passwd)
    local ok, users = pcall(dofile, "/lib/users.lua")
    if ok and users and passwd and passwd.username then
        local list = users.load()
        local found = false
        for i, u in ipairs(list) do
            if u.username == passwd.username then
                list[i] = passwd
                found = true
                break
            end
        end
        if not found then
            table.insert(list, passwd)
        end
        users.save(list)
        return
    end
    nyxlib.saveTable(PASSWD_PATH, passwd)
end

-- Lit /etc/hostname (fichier texte simple, pas serialise)
function nyxlib.getHostname()
    if not fs.exists("/etc/hostname") then
        return "nyxos"
    end
    local f = fs.open("/etc/hostname", "r")
    local name = f.readAll()
    f.close()
    return (name:gsub("%s+$", ""))
end

function nyxlib.setHostname(name)
    local f = fs.open("/etc/hostname", "w")
    f.write(name)
    f.close()
end

-- Formate un nombre d'octets en Ko/Mo/Go lisibles
function nyxlib.formatSize(bytes)
    if not bytes then
        return "?"
    end
    local units = { "o", "Ko", "Mo", "Go" }
    local i = 1
    while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
    end
    return string.format("%.1f%s", bytes, units[i])
end

return nyxlib
