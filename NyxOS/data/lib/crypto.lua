-- /lib/crypto.lua : cryptography module for NyxOS
-- Hashing (SHA-256, implemented in software so it never depends on which
-- peripherals are attached) and encryption (AES through CC: Tweaked's
-- Cryptography Accelerator when available, a weak XOR fallback otherwise).

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

------------------------------------------------------------------
-- SHA-256 (pure Lua)
------------------------------------------------------------------
-- The old crypto.hash() asked the accelerator for the digest when one was
-- plugged in and otherwise fell back to a home-made 4x32-bit checksum.
-- Those two produce DIFFERENT strings, so plugging in (or removing) the
-- accelerator after creating an account made the stored password stop
-- matching: the user was locked out. A real SHA-256 is the same algorithm
-- in software or hardware, so one implementation is used everywhere and
-- the digest never depends on which peripherals are attached.

local band, bxor, rshift, rrotate = bit32.band, bit32.bxor, bit32.rshift, bit32.rrotate
local bnot = bit32.bnot
local MOD = 4294967296

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function be32(n)
    return string.char(math.floor(n / 16777216) % 256, math.floor(n / 65536) % 256,
        math.floor(n / 256) % 256, n % 256)
end

-- Returns the SHA-256 digest of `msg` as 64 lowercase hex characters.
function crypto.sha256(msg)
    msg = tostring(msg)
    local len = #msg
    local bits = len * 8
    msg = msg .. "\128" .. string.rep("\0", (55 - len) % 64)
        .. be32(math.floor(bits / MOD)) .. be32(bits % MOD)

    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local w = {}

    for chunk = 1, #msg, 64 do
        for i = 0, 15 do
            local b1, b2, b3, b4 = string.byte(msg, chunk + i * 4, chunk + i * 4 + 3)
            w[i + 1] = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        end
        for i = 17, 64 do
            local w15, w2 = w[i - 15], w[i - 2]
            local s0 = bxor(rrotate(w15, 7), rrotate(w15, 18), rshift(w15, 3))
            local s1 = bxor(rrotate(w2, 17), rrotate(w2, 19), rshift(w2, 10))
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD
        end

        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 1, 64 do
            local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local t1 = (h + S1 + ch + K[i] + w[i]) % MOD
            local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local t2 = (S0 + maj) % MOD
            h, g, f, e = g, f, e, (d + t1) % MOD
            d, c, b, a = c, b, a, (t1 + t2) % MOD
        end

        h0, h1, h2, h3 = (h0 + a) % MOD, (h1 + b) % MOD, (h2 + c) % MOD, (h3 + d) % MOD
        h4, h5, h6, h7 = (h4 + e) % MOD, (h5 + f) % MOD, (h6 + g) % MOD, (h7 + h) % MOD
    end

    return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", h0, h1, h2, h3, h4, h5, h6, h7)
end

-- Plain SHA-256 hex digest. Deterministic on purpose: /bin/encrypt.lua
-- derives disk keys from it, so it must never be salted or randomised.
-- (For stored account passwords use crypto.hashPassword instead.)
-- An empty input returns "" (kept from the previous behaviour).
function crypto.hash(password)
    if not password or password == "" then
        return ""
    end
    return crypto.sha256(password)
end

-- The pre-1.0.3 software fallback: a 32-character home-made checksum.
-- Kept ONLY so accounts created on a computer without an accelerator can
-- still log in once (they are re-hashed on that first login).
local function legacyHash(password)
    local hash1, hash2, hash3, hash4 = 0, 0, 0, 0
    for i = 1, #password do
        local byte = string.byte(password, i)
        hash1 = ((hash1 * 31) + byte) % 2147483647
        hash2 = ((hash2 * 37) + byte + i) % 2147483647
        hash3 = ((hash3 * 41) + byte * i) % 2147483647
        hash4 = ((hash4 * 43) + bit32.bxor(byte, i)) % 2147483647
    end
    return string.format("%08x%08x%08x%08x", hash1, hash2, hash3, hash4)
end

local PASSWORD_PREFIX = "$nyx1$"
local PASSWORD_ROUNDS = 16 -- cheap stretching: a few ms on a CC computer

local function randomHex(bytes)
    local out = {}
    for i = 1, bytes do
        out[i] = string.format("%02x", math.random(0, 255))
    end
    return table.concat(out)
end

local function stretch(salt, password)
    local digest = crypto.sha256(salt .. ":" .. password)
    for _ = 2, PASSWORD_ROUNDS do
        digest = crypto.sha256(digest .. salt .. password)
    end
    return digest
end

-- Hashes a password for storage in /etc/passwd:
--   $nyx1$<16 hex chars of salt>$<64 hex chars of digest>
-- The salt means two users with the same password get different strings.
-- Returns "" for an empty password (= account without password).
function crypto.hashPassword(password)
    if not password or password == "" then
        return ""
    end
    local salt = randomHex(8)
    return PASSWORD_PREFIX .. salt .. "$" .. stretch(salt, password)
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
    return string.char((table.unpack or unpack)(key))
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

-- Verifies a password against a stored hash. Returns ok, needsUpgrade:
-- needsUpgrade is true when the password is right but the stored string is
-- in an older format (plain SHA-256 from the accelerator, the old 32-char
-- software checksum, or even plain text), so the caller can re-hash it
-- with crypto.hashPassword.
function crypto.verifyPassword(password, stored)
    if not stored or stored == "" then
        return true, false -- No password configured
    end
    if not password or password == "" then
        return false, false
    end

    if stored:sub(1, #PASSWORD_PREFIX) == PASSWORD_PREFIX then
        local salt, digest = stored:match("^%$nyx1%$(%x+)%$(%x+)$")
        if not salt then
            return false, false
        end
        return stretch(salt, password) == digest, false
    end

    local lowered = stored:lower()
    if lowered == crypto.sha256(password) or lowered == legacyHash(password) then
        return true, true
    end
    if stored == password then -- very old installs kept plain text
        return true, true
    end
    return false, false
end

return crypto
