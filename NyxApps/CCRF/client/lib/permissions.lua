-- CCRF - lib/permissions.lua
-- Gestion mot de passe, blacklist et protections NyxOS

local permissions = {}

-- Noms protégés en dur.
-- Impossible à supprimer via CCRF.
permissions.CORE_NAMES = {
    ["rom"] = true,
    ["ccrf"] = true,
    ["ccrf.lua"] = true,
    ["etc"] = true,
}

local CONFIG_PATH = "/etc/ccrf/config.json"


-- Hash simple (pas de vraie crypto)
local function simpleHash(str)
    local hash = 5381

    for i = 1, #str do
        hash = (hash * 33 + string.byte(str, i)) % 2147483647
    end

    return tostring(hash)
end

permissions.simpleHash = simpleHash


function permissions.loadConfig()
    local default = {
        password = "",
        blacklist = {}
    }

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
    local dir = fs.getDir(CONFIG_PATH)

    if not fs.exists(dir) then
        fs.makeDir(dir)
    end

    local f = fs.open(CONFIG_PATH, "w")
    f.write(textutils.serialiseJSON(config))
    f.close()
end


function permissions.checkPassword(config)
    if config.password == "" then
        return true
    end

    write("Mot de passe : ")
    local input = read("*")

    return simpleHash(input) == config.password
end


function permissions.isProtected(path, config)

    -- Protection fichiers système
    if permissions.CORE_NAMES[path] then
        return true
    end


    -- Protection des lecteurs/disques montés
    local ok, isDrive = pcall(fs.isDriveRoot, path)

    if ok and isDrive then
        return true
    end


    -- Protection personnalisée
    for _, blacklisted in ipairs(config.blacklist) do
        if path == blacklisted then
            return true
        end
    end


    return false
end


return permissions