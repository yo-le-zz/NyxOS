-- /lib/ssh/sshlib.lua : shared parts of the NyxOS ssh client and server
--
-- Protocol (messages are Lua tables over a /lib/netstack.lua connection to port 22):
--   C: {t="hello", user=...}
--   S: {t="challenge", nonce=..., host=...}
--   C: {t="auth", method="key", fp=..., cnonce=..., proof=sha256(secret..nonce..cnonce)}
--      or {t="auth", method="password", password=...}
--   S: {t="ok", home=..., user=..., admin=bool} | {t="fail", reason=...}
--   C: {t="exec", cmd=...}  S: {t="prompt", text=..., mask=...}* / {t="answer"} from C
--                           S: {t="out", text=..., err=...} {t="done"}
--   C: {t="put", path=..., data=..., first=bool, last=bool}   S: {t="ack"} | {t="err", reason}
--   C: {t="get", path=...}   S: {t="chunk", data=..., last=bool} | {t="err", reason}
--   C: {t="bye"}
--
-- SECURITY NOTE: nothing is encrypted. A key login never sends the secret
-- (only a proof for one challenge). A password login sends the password in
-- clear on the network: prefer keys, and copy keys with a disk if the
-- network is not trusted.

local sshlib = {}
local crypto = dofile("/lib/crypto.lua")

sshlib.PORT = 22
sshlib.CHUNK = 6000

function sshlib.nonce()
    local t = {}
    for i = 1, 16 do t[i] = string.format("%02x", math.random(0, 255)) end
    return table.concat(t) .. string.format("%x", os.epoch("utc"))
end

function sshlib.proof(secret, nonce, cnonce)
    return crypto.sha256(secret .. ":" .. nonce .. ":" .. cnonce)
end

function sshlib.fingerprint(secret)
    return crypto.sha256("nyx-ssh-key:" .. secret):sub(1, 32)
end

function sshlib.newSecret()
    local t = {}
    for i = 1, 32 do t[i] = string.format("%02x", math.random(0, 255)) end
    -- the OS RNG of CC is weak: mix in the time and the computer id
    return crypto.sha256(table.concat(t) .. os.epoch("utc") .. os.getComputerID() .. tostring({})):sub(1, 48)
end

-- Where a user keeps keys
function sshlib.keyPath(home) return home .. "/.ssh/id" end
function sshlib.authPath(home) return home .. "/.ssh/authorized_keys" end

function sshlib.readKey(home)
    local path = sshlib.keyPath(home)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local secret = f.readLine()
    f.close()
    if secret and #secret >= 16 then return secret, sshlib.fingerprint(secret) end
end

-- authorized_keys: one "<fingerprint> <secret>" per line
function sshlib.authorizedSecret(home, fp)
    local path = sshlib.authPath(home)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    while true do
        local line = f.readLine()
        if not line then break end
        local lfp, secret = line:match("^(%x+)%s+(%x+)")
        if lfp == fp then f.close() return secret end
    end
    f.close()
end

function sshlib.addAuthorized(home, secret)
    local dir = home .. "/.ssh"
    if not fs.exists(dir) then fs.makeDir(dir) end
    local fp = sshlib.fingerprint(secret)
    if sshlib.authorizedSecret(home, fp) then return true, "already authorized" end
    local f = fs.open(sshlib.authPath(home), "a")
    if not f then return false, "cannot write authorized_keys" end
    f.writeLine(fp .. " " .. secret)
    f.close()
    return true
end

-- Normalises a user path. Relative paths start in the home folder. Returns
-- the absolute path, or nil when a non-admin leaves their home folder.
function sshlib.safePath(path, home, admin)
    if type(path) ~= "string" or path == "" then return nil end
    local full
    if path:sub(1, 1) == "/" then full = "/" .. fs.combine("", path)
    else full = "/" .. fs.combine(home, path) end
    if admin then return full end
    local h = "/" .. fs.combine("", home)
    if full == h or full:sub(1, #h + 1) == h .. "/" then return full end
    return nil
end

-- Splits "user@host" / "host"
function sshlib.parseTarget(text, defaultUser)
    local user, host = tostring(text):match("^([^@]+)@(.+)$")
    if not user then return defaultUser, text end
    return user, host
end

return sshlib
