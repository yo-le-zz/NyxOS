-- /lib/ssh/sshd.lua : NyxOS ssh server (service "sshd", port 22)
--   service enable sshd ; service start sshd
-- Commands run with the identity of the ssh user (the console session is
-- switched to that user while the command runs, then restored).
-- /etc/sshd.lua may contain { passwords = false } to allow keys only, and
-- { allow = { "alice", "bob" } } to limit the users.

local net = dofile("/lib/netstack.lua")
local sshlib = dofile("/lib/ssh/sshlib.lua")
local logger = dofile("/lib/logger.lua")
local users = dofile("/lib/users.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local capture = dofile("/lib/capture.lua")

local function loadConfig()
    local cfg = nyxlib.loadTable("/etc/sshd.lua")
    return {
        passwords = cfg.passwords ~= false,
        allow = type(cfg.allow) == "table" and cfg.allow or nil,
        idle = tonumber(cfg.idle) or 300,
    }
end

local function allowed(cfg, name)
    if not cfg.allow then return true end
    for _, n in ipairs(cfg.allow) do if n == name then return true end end
    return false
end

local function homeOf(user)
    return user.home or ("/home/" .. user.username)
end

-- One client. Runs inside its own coroutine.
local function session(conn, cfg)
    local peer = conn.peer
    local hello = conn:receive(10)
    if type(hello) ~= "table" or hello.t ~= "hello" or type(hello.user) ~= "string" then
        conn:close() return
    end
    local user = users.find(hello.user)
    local nonce = sshlib.nonce()
    conn:send({ t = "challenge", nonce = nonce, host = nyxlib.getHostname(), passwords = cfg.passwords })

    local authed = false
    for attempt = 1, 3 do
        local msg = conn:receive(30)
        if type(msg) ~= "table" or msg.t ~= "auth" then break end
        local good = false
        if user and allowed(cfg, user.username) then
            if msg.method == "key" then
                local secret = sshlib.authorizedSecret(homeOf(user), tostring(msg.fp or ""))
                good = secret ~= nil and sshlib.proof(secret, nonce, tostring(msg.cnonce or "")) == msg.proof
            elseif msg.method == "password" and cfg.passwords then
                good = users.checkPassword(user.username, tostring(msg.password or ""))
            end
        end
        if good then authed = true break end
        logger.warn("sshd", string.format("failed login for '%s' from %s (%s)", tostring(hello.user), peer, tostring(msg.method)))
        sleep(1)
        conn:send({ t = "fail", reason = "permission denied" })
    end
    if not authed then conn:send({ t = "fail", reason = "too many failures", final = true }) conn:close() return end

    local home = homeOf(user)
    local admin = user.admin and true or false
    conn:send({ t = "ok", user = user.username, home = home, admin = admin })
    logger.info("sshd", string.format("%s logged in from %s", user.username, peer))

    local putFile
    while true do
        local msg, why = conn:receive(cfg.idle)
        if not msg then
            if why == "timeout" then logger.info("sshd", user.username .. " idle timeout") end
            break
        end
        if type(msg) ~= "table" then break end
        if msg.t == "bye" then break
        elseif msg.t == "exec" and type(msg.cmd) == "string" then
            logger.info("sshd", user.username .. " exec: " .. (msg.cmd:match("^%S+") or "?"))
            local previous = nyxlib.loadSession()
            nyxlib.saveSession(user.username)
            local ui = {
                prompt = function(soFar, mask)
                    conn:send({ t = "prompt", text = soFar:match("[^\n]*$") or "", mask = mask })
                    local a = conn:receive(120)
                    return type(a) == "table" and a.t == "answer" and tostring(a.text or "") or ""
                end,
            }
            if shell and shell.setDir then pcall(shell.setDir, home) end
            local okRun, output, err = pcall(capture.run, msg.cmd, ui)
            if not okRun then output, err = "", tostring(output) end
            if previous and previous.username then nyxlib.saveSession(previous.username) end
            conn:send({ t = "out", text = output or "", err = err })
            conn:send({ t = "done" })
        elseif msg.t == "put" then
            local path = sshlib.safePath(msg.path, home, admin)
            if not path then conn:send({ t = "err", reason = "permission denied: " .. tostring(msg.path) })
            else
                if msg.first then
                    if putFile then putFile.close() end
                    local dir = fs.getDir(path)
                    if dir ~= "" and not fs.exists(dir) then pcall(fs.makeDir, dir) end
                    putFile = fs.open(path, "wb") or fs.open(path, "w")
                end
                if not putFile then conn:send({ t = "err", reason = "cannot write " .. path })
                else
                    putFile.write(tostring(msg.data or ""))
                    if msg.last then putFile.close() putFile = nil end
                    conn:send({ t = "ack" })
                end
            end
        elseif msg.t == "get" then
            local path = sshlib.safePath(msg.path, home, admin)
            if not path or not fs.exists(path) or fs.isDir(path) then
                conn:send({ t = "err", reason = "no such file: " .. tostring(msg.path) })
            else
                local f = fs.open(path, "rb") or fs.open(path, "r")
                local data = f.readAll() or ""
                f.close()
                local pos = 1
                repeat
                    local piece = data:sub(pos, pos + sshlib.CHUNK - 1)
                    pos = pos + sshlib.CHUNK
                    conn:send({ t = "chunk", data = piece, last = pos > #data })
                until pos > #data
            end
        end
    end
    if putFile then putFile.close() end
    conn:close()
    logger.info("sshd", user.username .. " disconnected")
end

-- Main: an accepting coroutine plus one coroutine per session, resumed
-- only for the events they asked for (the same rule the system follows).
local cfg = loadConfig()
net.up()
local listener = net.listen(sshlib.PORT, "sshd")
logger.info("sshd", "listening on " .. net.myIp() .. ":" .. sshlib.PORT)

local threads = {}
local function spawn(fn)
    local th = { co = coroutine.create(fn) }
    table.insert(threads, th)
    return th
end
spawn(function()
    while true do
        local conn = listener:accept()
        if conn then
            spawn(function()
                local ok, err = pcall(session, conn, cfg)
                if not ok then
                    logger.error("sshd", "session crashed: " .. tostring(err))
                    pcall(conn.close, conn)
                end
            end)
        end
    end
end)

local event = {}
while true do
    for i = #threads, 1, -1 do
        local th = threads[i]
        if th.filter == nil or th.filter == event[1] or event[1] == "terminate" then
            local ok, filter = coroutine.resume(th.co, (table.unpack or unpack)(event))
            if not ok then
                logger.error("sshd", tostring(filter))
                table.remove(threads, i)
            elseif coroutine.status(th.co) == "dead" then
                table.remove(threads, i)
            else
                th.filter = filter
            end
        end
    end
    event = { os.pullEventRaw() }
    if event[1] == "terminate" then break end
end
listener:close()
