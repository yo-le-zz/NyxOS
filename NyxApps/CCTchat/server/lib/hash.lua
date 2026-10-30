-- CCTchat - Hashage des mots de passe
-- NyxOS present : SHA-256 sale (/lib/crypto.lua), plusieurs tours.
-- Sinon (ancien CC:Tweaked sans NyxOS) : l'ancien hachage maison.
-- Chaque compte retient son algorithme ("algo"), donc les anciens comptes
-- continuent de fonctionner.

local M = {}
local MOD = 4294967291

local function rawHash(str)
    local h = 5381
    for i = 1, #str do
        h = (h * 33 + string.byte(str, i)) % MOD
    end
    return h
end

local crypto
if fs.exists("/lib/crypto.lua") then
    local ok, lib = pcall(dofile, "/lib/crypto.lua")
    if ok and type(lib) == "table" and lib.sha256 then crypto = lib end
end

M.preferred = crypto and "s256" or "djb"

function M.randomSalt()
    math.randomseed((os.epoch and os.epoch("utc")) or os.time())
    local salt = ""
    for i = 1, 12 do salt = salt .. string.char(math.random(33, 126)) end
    return salt
end

function M.hashPassword(password, salt, algo)
    algo = algo or M.preferred
    if algo == "s256" and crypto then
        local h = salt .. ":" .. password
        for i = 1, 40 do h = crypto.sha256(h .. salt) end
        return h
    end
    local h = salt .. password .. salt
    for i = 1, 500 do h = tostring(rawHash(h .. salt)) end
    return h
end

return M
