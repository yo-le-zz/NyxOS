-- CCRF - lib/permissions.lua : mot de passe, blacklist, protections

local permissions = {}

-- Noms proteges EN DUR dans le code : impossibles a supprimer ou a retirer
-- via la config, meme via la blacklist utilisateur. Ca evite que CCRF
-- s'auto-supprime pendant un reset.
permissions.CORE_NAMES = {
    ["rom"] = true,
    ["ccrf"] = true,
    ["ccrf_data"] = true,
}

local CONFIG_PATH = "/ccrf_data/config.json"

-- Hash simple (pas de la vraie crypto, juste pour eviter un mot de passe en clair)
local function simpleHash(str)
    local hash = 5381
    for i = 1, #str do
        hash = (hash * 33 + string.byte(str, i)) % 2147483647
    end
    return tostring(hash)
end
permissions.simpleHash = simpleHash

function permissions.loadConfig()
    local default = { password = "", blacklist = {} }
    if not fs.exists(CONFIG_PATH) then
        return default
    end
    local f = fs.open(CONFIG_PATH, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialiseJSON, content)
    if not ok or type(data) ~= "table" then
        return default
    end
    data.password = data.password or ""
    data.blacklist = data.blacklist or {}
    return data
end

function permissions.saveConfig(config)
    local f = fs.open(CONFIG_PATH, "w")
    f.write(textutils.serialiseJSON(config))
    f.close()
end

-- Demande le mot de passe au clavier (masque) et le compare au hash stocke.
-- Retourne true si aucun mot de passe n'est defini, ou si la saisie correspond.
function permissions.checkPassword(config)
    if config.password == "" then
        return true
    end
    write("Mot de passe : ")
    local input = read("*")
    return simpleHash(input) == config.password
end

-- Un chemin est protege si : nom core (rom/ccrf/reset/uninstall),
-- racine de disque monte, ou present dans la blacklist utilisateur.
function permissions.isProtected(path, config)
    if permissions.CORE_NAMES[path] then
        return true
    end
    local ok, isDrive = pcall(fs.isDriveRoot, path)
    if ok and isDrive then
        return true
    end
    for _, blacklisted in ipairs(config.blacklist) do
        if path == blacklisted then
            return true
        end
    end
    return false
end

return permissions
