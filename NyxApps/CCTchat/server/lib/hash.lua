-- CCTchat - Hashage des mots de passe
-- Pas du niveau militaire, mais suffisant pour un serveur de jeu :
-- sel aleatoire + de multiples tours de hachage.

local M = {}
local MOD = 4294967291 -- grand nombre premier < 2^32

local function rawHash(str)
    local h = 5381
    for i = 1, #str do
        local c = string.byte(str, i)
        h = (h * 33 + c) % MOD
    end
    return h
end

function M.randomSalt()
    math.randomseed((os.epoch and os.epoch("utc")) or os.time())
    local salt = ""
    for i = 1, 8 do
        salt = salt .. string.char(math.random(33, 126))
    end
    return salt
end

function M.hashPassword(password, salt)
    local h = salt .. password .. salt
    for i = 1, 500 do
        h = tostring(rawHash(h .. salt))
    end
    return h
end

return M
