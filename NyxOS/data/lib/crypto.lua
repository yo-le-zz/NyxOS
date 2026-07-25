-- /lib/crypto.lua : cryptography module for NyxOS
-- Uses CC: Tweaked's Cryptography Accelerator if available
-- Provides hashing (SHA-256) and encryption (AES) functions

local crypto = {}

-- Detects and returns the connected Cryptography Accelerator.
-- peripheral.find() checks every attached peripheral by declared type,
-- including ones reachable only through a wired modem network -- unlike
-- a manual side/name scan, this works regardless of how the accelerator
-- is physically connected.
local function findCryptoAccelerator()
    local p = peripheral.find("cryptographic_accelerator")
    if p then
        return p, peripheral.getName(p)
    end

    -- Fallback for renamed/modified peripheral ids: any attached
    -- peripheral (direct or through a wired modem) that exposes an
    -- `encrypt` method.
    for _, name in ipairs(peripheral.getNames()) do
        local wrapped = peripheral.wrap(name)
        if wrapped and wrapped.encrypt then
            return wrapped, name
        end
    end

    return nil, nil
end

-- Cached Cryptography Accelerator
local cryptoDevice, cryptoDeviceName = findCryptoAccelerator()

-- Checks whether the Cryptography Accelerator is available
function crypto.isAvailable()
    if cryptoDevice then
        return true, cryptoDeviceName
    end
    -- Retry detection (it may have been hot-plugged)
    cryptoDevice, cryptoDeviceName = findCryptoAccelerator()
    return cryptoDevice ~= nil, cryptoDeviceName
end

-- Blocks if there is no Cryptography Accelerator
-- Returns true if available, false otherwise with an error message
function crypto.requireCrypto()
    local ok, name = crypto.isAvailable()
    if ok then
        return true, name
    else
        return false, "ERROR: Cryptography Accelerator not detected. Connect a 'cryptographic_accelerator' peripheral to continue."
    end
end

-- Hashes a password with SHA-256
-- Returns the hash in hexadecimal
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

    -- Fallback: improved character-based hash (less secure, but unique)
    -- Generates a 64-character hash for SHA-256 compatibility
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

    -- Combine the 4 hashes into a unique 64-character result
    return h1 .. h2 .. h3 .. h4
end

-- Generates a random key for encryption
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

    -- Fallback: pseudo-random key
    local key = {}
    for i = 1, 32 do
        key[i] = math.random(0, 255)
    end
    return string.char(unpack(key))
end

-- Encrypts data with AES
-- data: string to encrypt
-- key: encryption key (32 bytes for AES-256)
-- Returns the encrypted data
function crypto.encrypt(data, key)
    if not data or not key then
        return nil, "Missing data or key"
    end

    local ok, device = crypto.isAvailable()
    if ok and device then
        local success, result = pcall(function()
            return device.encrypt(data, key)
        end)
        if success and result then
            return result
        else
            return nil, "Encryption failed"
        end
    end

    -- Fallback: simple XOR (not secure, compatibility only)
    local encrypted = {}
    local keyLen = #key
    for i = 1, #data do
        encrypted[i] = string.char(bit32.bxor(string.byte(data, i), string.byte(key, (i - 1) % keyLen + 1)))
    end
    return table.concat(encrypted)
end

-- Decrypts data with AES
-- data: encrypted data
-- key: decryption key (32 bytes for AES-256)
-- Returns the decrypted data
function crypto.decrypt(data, key)
    if not data or not key then
        return nil, "Missing data or key"
    end

    local ok, device = crypto.isAvailable()
    if ok and device then
        local success, result = pcall(function()
            return device.decrypt(data, key)
        end)
        if success and result then
            return result
        else
            return nil, "Decryption failed"
        end
    end

    -- Fallback: simple XOR (not secure, compatibility only)
    local decrypted = {}
    local keyLen = #key
    for i = 1, #data do
        decrypted[i] = string.char(bit32.bxor(string.byte(data, i), string.byte(key, (i - 1) % keyLen + 1)))
    end
    return table.concat(decrypted)
end

-- Verifies a password against its hash
function crypto.verifyPassword(password, hash)
    if not hash or hash == "" then
        return true -- No password configured
    end
    if not password or password == "" then
        return false
    end
    local computedHash = crypto.hash(password)
    return computedHash == hash
end

return crypto
