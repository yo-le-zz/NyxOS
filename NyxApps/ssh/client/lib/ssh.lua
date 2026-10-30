-- /lib/ssh/ssh.lua : ssh [user@]host [command...]
--   ssh bob@10.0.1.7            interactive shell on that computer
--   ssh bob@server ls /home     run one command and print its output
-- Uses the key from ssh-keygen when the server knows it, else asks for the password.

local net = dofile("/lib/netstack.lua")
local sshlib = dofile("/lib/ssh/sshlib.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local args = { ... }

local session = nyxlib.loadSession()
local me = session.username or "root"
local target = table.remove(args, 1)
if not target then
    print("Usage: ssh [user@]host [command...]")
    return
end
local user, host = sshlib.parseTarget(target, me)

local function home()
    local ok, users = pcall(dofile, "/lib/users.lua")
    local u = ok and users.find(me)
    return u and u.home or ("/home/" .. me)
end

-- Opens the connection and logs in. Returns conn, info or nil, error.
local function login()
    local conn, err = net.connect(host, sshlib.PORT, 4)
    if not conn then return nil, err end
    conn:send({ t = "hello", user = user })
    local ch = conn:receive(5)
    if type(ch) ~= "table" or ch.t ~= "challenge" then conn:close() return nil, "no answer from the ssh server" end

    local secret, fp = sshlib.readKey(home())
    if secret then
        local cnonce = sshlib.nonce()
        conn:send({ t = "auth", method = "key", fp = fp, cnonce = cnonce, proof = sshlib.proof(secret, ch.nonce, cnonce) })
        local r = conn:receive(10)
        if type(r) == "table" and r.t == "ok" then return conn, r end
        if type(r) == "table" and r.final then conn:close() return nil, r.reason end
    end
    if ch.passwords == false then conn:close() return nil, "permission denied (keys only)" end
    for attempt = 1, 3 do
        write(user .. "@" .. tostring(ch.host or host) .. "'s password: ")
        local pass = read("*")
        conn:send({ t = "auth", method = "password", password = pass })
        local r = conn:receive(10)
        if type(r) == "table" and r.t == "ok" then return conn, r end
        print("Permission denied, try again.")
        if type(r) == "table" and r.final then break end
    end
    conn:close()
    return nil, "authentication failed"
end

-- Runs one command; prompts from the remote side are relayed to the user.
local function run(conn, cmd)
    conn:send({ t = "exec", cmd = cmd })
    while true do
        local m, why = conn:receive(300)
        if not m then print("ssh: connection lost (" .. tostring(why) .. ")") return false end
        if m.t == "prompt" then
            write(m.text or "")
            local a = read(m.mask)
            conn:send({ t = "answer", text = a })
        elseif m.t == "out" then
            if m.text and m.text ~= "" then print(m.text) end
            if m.err then printError(m.err) end
        elseif m.t == "done" then return true end
    end
end

local conn, info = login()
if not conn then print("ssh: " .. tostring(info)) return end

if #args > 0 then
    run(conn, table.concat(args, " "))
    conn:send({ t = "bye" })
    conn:close()
    return
end

print("Connected to " .. host .. " as " .. info.user .. ". Type 'exit' to leave.")
while true do
    write(info.user .. "@" .. host .. "$ ")
    local line = read()
    if line == nil or line == "exit" or line == "logout" then break end
    if line ~= "" then
        if not run(conn, line) then break end
    end
end
conn:send({ t = "bye" })
conn:close()
print("Connection to " .. host .. " closed.")
