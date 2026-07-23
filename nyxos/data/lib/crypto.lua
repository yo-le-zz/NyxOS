-- /lib/crypto.lua : module de cryptographie pour NyxOS
-- Utilise le Cryptography Accelerator de CC: Tweaked si disponible
-- Fournit des fonctions de hash (SHA-256) et de chiffrement (AES)

local crypto = {}

-- Détecte et retourne le Cryptography Accelerator connecté
local function findCryptoAccelerator()
    local sides = {"top", "bottom", "left", "right", "front", "back"}
    
    -- Recherche par côté (directement connecté)
    for _, side in ipairs(sides) do
        if peripheral.isPresent(side) then
            local p = peripheral.wrap(side)
            if p and p.encrypt then
                return p, side
            end
        end
    end
    
    -- Cherche dans les périphériques réseau (wired modems)
    local names = peripheral.getNames()
    for _, name in ipairs(names) do
        local p = peripheral.wrap(name)
        if not p then
            goto continue
        end
        
        -- Vérifie si le nom contient "cryptographic_accelerator" (avec ou sans numéro _0, _1, etc.)
        if name:lower():find("cryptographic_accelerator") then
            if p.encrypt then
                return p, name
            end
        end
        
        -- Vérifie aussi si le périphérique a la méthode encrypt (pour les périphériques avec noms différents)
        if p.encrypt then
            return p, name
        end
        
        ::continue::
    end
    
    return nil, nil
end

-- Cache du Cryptography Accelerator
local cryptoDevice, cryptoDeviceName = findCryptoAccelerator()

-- Vérifie si le Cryptography Accelerator est disponible
function crypto.isAvailable()
    if cryptoDevice then
        return true, cryptoDeviceName
    end
    -- Réessayer la détection (peut avoir été branché à chaud)
    cryptoDevice, cryptoDeviceName = findCryptoAccelerator()
    return cryptoDevice ~= nil, cryptoDeviceName
end

-- Fonction pour bloquer si pas de Cryptography Accelerator
-- Retourne true si disponible, false sinon avec message d'erreur
function crypto.requireCrypto()
    local ok, name = crypto.isAvailable()
    if ok then
        return true, name
    else
        return false, "ERREUR: Cryptography Accelerator non detecte. Connectez un peripherique 'cryptographic_accelerator' pour continuer."
    end
end

-- Hash un mot de passe avec SHA-256
-- Retourne le hash en hexadécimal
function crypto.hash(password)
    if not password or password == "" then
        return ""
    end
    
    local ok, device = crypto.isAvailable()
    if ok and device then
        local success, result = pcall(function()
            return device.sha256(password)
        end)
        if success and result then
            return result
        end
    end
    
    -- Fallback : hash amélioré basé sur les caractères (moins sécurisé mais unique)
    -- Génère un hash de 64 caractères pour compatibilité avec SHA-256
    local hash1 = 0
    local hash2 = 0
    local hash3 = 0
    local hash4 = 0
    
    for i = 1, #password do
        local byte = string.byte(password, i)
        hash1 = ((hash1 * 31) + byte) % 2147483647
        hash2 = ((hash2 * 37) + byte + i) % 2147483647
        hash3 = ((hash3 * 41) + byte * i) % 2147483647
        hash4 = ((hash4 * 43) + bit32.bxor(byte, i)) % 2147483647
    end
    
    local h1 = string.format("%08x", hash1)
    local h2 = string.format("%08x", hash2)
    local h3 = string.format("%08x", hash3)
    local h4 = string.format("%08x", hash4)
    
    -- Combine les 4 hashes pour obtenir 64 caractères uniques
    return h1 .. h2 .. h3 .. h4
end

-- Génère une clé aléatoire pour le chiffrement
function crypto.generateKey()
    local ok, device = crypto.isAvailable()
    if ok and device then
        local success, result = pcall(function()
            return device.random(32) -- 32 bytes = 256 bits
        end)
        if success and result then
            return result
        end
    end
    
    -- Fallback : clé pseudo-aléatoire
    local key = {}
    for i = 1, 32 do
        key[i] = math.random(0, 255)
    end
    return string.char(unpack(key))
end

-- Chiffre des données avec AES
-- data : string à chiffrer
-- key : clé de chiffrement (32 bytes pour AES-256)
-- Retourne les données chiffrées
function crypto.encrypt(data, key)
    if not data or not key then
        return nil, "Données ou clé manquantes"
    end
    
    local ok, device = crypto.isAvailable()
    if ok and device then
        local success, result = pcall(function()
            return device.encrypt(data, key)
        end)
        if success and result then
            return result
        else
            return nil, "Échec du chiffrement"
        end
    end
    
    -- Fallback : XOR simple (non sécurisé, seulement pour compatibilité)
    local encrypted = {}
    local keyLen = #key
    for i = 1, #data do
        encrypted[i] = string.char(bit32.bxor(string.byte(data, i), string.byte(key, (i - 1) % keyLen + 1)))
    end
    return table.concat(encrypted)
end

-- Déchiffre des données avec AES
-- data : données chiffrées
-- key : clé de déchiffrement (32 bytes pour AES-256)
-- Retourne les données déchiffrées
function crypto.decrypt(data, key)
    if not data or not key then
        return nil, "Données ou clé manquantes"
    end
    
    local ok, device = crypto.isAvailable()
    if ok and device then
        local success, result = pcall(function()
            return device.decrypt(data, key)
        end)
        if success and result then
            return result
        else
            return nil, "Échec du déchiffrement"
        end
    end
    
    -- Fallback : XOR simple (non sécurisé, seulement pour compatibilité)
    local decrypted = {}
    local keyLen = #key
    for i = 1, #data do
        decrypted[i] = string.char(bit32.bxor(string.byte(data, i), string.byte(key, (i - 1) % keyLen + 1)))
    end
    return table.concat(decrypted)
end

-- Vérifie un mot de passe par rapport à son hash
function crypto.verifyPassword(password, hash)
    if not hash or hash == "" then
        return true -- Pas de mot de passe configuré
    end
    if not password or password == "" then
        return false
    end
    local computedHash = crypto.hash(password)
    return computedHash == hash
end

return crypto
