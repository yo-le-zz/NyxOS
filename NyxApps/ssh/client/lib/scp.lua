-- /lib/ssh/scp.lua : copy a file over ssh
--   scp <local file> [user@]host:<remote path>      upload
--   scp [user@]host:<remote path> <local file>      download
-- Remote paths are relative to the user's home folder (administrators can
-- use absolute paths). Authentication: key, else password.
local net = dofile("/lib/netstack.lua")
local sshlib = dofile("/lib/ssh/sshlib.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local a, b = ...
if not a or not b then
    print("Usage: scp <file> user@host:<path>   |   scp user@host:<path> <file>")
    return
end

local me = nyxlib.loadSession().username or "root"
local function split(s)
    local target, path = s:match("^([^:/]+):(.*)$")
    return target, path
end
local srcT, srcP = split(a)
local dstT, dstP = split(b)
if (srcT and dstT) or (not srcT and not dstT) then
    print("scp: exactly one side must be user@host:path")
    return
end
local target = srcT or dstT
local user, host = sshlib.parseTarget(target, me)

local ok, users = pcall(dofile, "/lib/users.lua")
local u = ok and users.find(me)
local home = u and u.home or ("/home/" .. me)

local conn, err = net.connect(host, sshlib.PORT, 4)
if not conn then print("scp: " .. tostring(err)) return end
conn:send({ t = "hello", user = user })
local ch = conn:receive(5)
if type(ch) ~= "table" or ch.t ~= "challenge" then print("scp: no answer from the ssh server") conn:close() return end

local authed = false
local secret, fp = sshlib.readKey(home)
if secret then
    local cnonce = sshlib.nonce()
    conn:send({ t = "auth", method = "key", fp = fp, cnonce = cnonce, proof = sshlib.proof(secret, ch.nonce, cnonce) })
    local r = conn:receive(10)
    authed = type(r) == "table" and r.t == "ok"
end
if not authed and ch.passwords ~= false then
    for i = 1, 3 do
        write(user .. "@" .. host .. "'s password: ")
        conn:send({ t = "auth", method = "password", password = read("*") })
        local r = conn:receive(10)
        if type(r) == "table" and r.t == "ok" then authed = true break end
        print("Permission denied.")
    end
end
if not authed then print("scp: authentication failed") conn:close() return end

if dstT then
    -- upload
    local localPath = shell and shell.resolve(a) or a
    if not fs.exists(localPath) or fs.isDir(localPath) then print("scp: no such file: " .. a) conn:send({ t = "bye" }) conn:close() return end
    local f = fs.open(localPath, "rb") or fs.open(localPath, "r")
    local data = f.readAll() or ""
    f.close()
    local pos, first = 1, true
    repeat
        local piece = data:sub(pos, pos + sshlib.CHUNK - 1)
        pos = pos + sshlib.CHUNK
        conn:send({ t = "put", path = dstP, data = piece, first = first, last = pos > #data })
        first = false
        local r = conn:receive(10)
        if type(r) ~= "table" or r.t ~= "ack" then
            print("scp: " .. tostring(type(r) == "table" and r.reason or "no answer"))
            conn:close() return
        end
    until pos > #data
    print(string.format("%s -> %s:%s  (%d bytes)", a, host, dstP, #data))
else
    -- download
    conn:send({ t = "get", path = srcP })
    local parts = {}
    while true do
        local r = conn:receive(10)
        if type(r) ~= "table" then print("scp: connection lost") conn:close() return end
        if r.t == "err" then print("scp: " .. tostring(r.reason)) conn:send({ t = "bye" }) conn:close() return end
        parts[#parts + 1] = r.data or ""
        if r.last then break end
    end
    local out = shell and shell.resolve(b) or b
    local f = fs.open(out, "wb") or fs.open(out, "w")
    if not f then print("scp: cannot write " .. out) conn:close() return end
    local data = table.concat(parts)
    f.write(data)
    f.close()
    print(string.format("%s:%s -> %s  (%d bytes)", host, srcP, b, #data))
end
conn:send({ t = "bye" })
conn:close()
