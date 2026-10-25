-- CCTchat - Serveur principal
local dir = fs.getDir(shell.getRunningProgram())
local hash = dofile(fs.combine(dir, "lib/hash.lua"))
local db   = dofile(fs.combine(dir, "lib/db.lua"))
local net  = dofile(fs.combine(dir, "lib/net.lua"))

local PROTOCOL = "cctchat"
local CONFIG_PATH = fs.combine(dir, "data/server.cfg")

db.init(fs.combine(dir, "data/users.db"))
net.open()

-- Nom du serveur : argument de lancement > saisie manuelle > dernier nom utilise
local args = { ... }
local defaultName = "cct-serv-1"
if fs.exists(CONFIG_PATH) then
    local cf = fs.open(CONFIG_PATH, "r")
    local saved = cf.readAll()
    cf.close()
    if saved and saved ~= "" then defaultName = saved end
end

local serverName = args[1]
if not serverName or serverName == "" then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.lime)
    print("=========================================")
    print("        CCTchat - Configuration")
    print("=========================================")
    term.setTextColor(colors.yellow)
    write("Nom de ce serveur [" .. defaultName .. "] : ")
    term.setTextColor(colors.white)
    local input = read()
    serverName = (input ~= "" and input) or defaultName
end

local cf = fs.open(CONFIG_PATH, "w")
cf.write(serverName)
cf.close()

rednet.host(PROTOCOL, serverName)

local clients = {} -- [id] = { user = ..., room = ... }
local rooms = { general = { password = nil } }
local peers = {} -- [id] = true : autres serveurs CCTchat connus (pour le datacenter)

local function log(msg, color)
    term.setTextColor(color or colors.white)
    print(msg)
    term.setTextColor(colors.white)
end

local function logFile(text)
    local f = fs.open(fs.combine(dir, "data/messages.log"), "a")
    f.write("[" .. os.date("%H:%M:%S") .. "] " .. text .. "\n")
    f.close()
end

local function broadcastToRoom(room, msg, exceptId)
    for id, info in pairs(clients) do
        if info.room == room and id ~= exceptId then
            rednet.send(id, msg, PROTOCOL)
        end
    end
end

local function roomList()
    local list = {}
    local counts = {}
    for name, _ in pairs(rooms) do counts[name] = 0 end
    for _, info in pairs(clients) do
        if info.room and counts[info.room] ~= nil then
            counts[info.room] = counts[info.room] + 1
        end
    end
    for name, roomInfo in pairs(rooms) do
        table.insert(list, {
            name = name,
            count = counts[name] or 0,
            protected = roomInfo.password ~= nil,
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Annonce ce serveur aux autres serveurs CCTchat du reseau (datacenter)
rednet.broadcast({ action = "server_hello", name = serverName }, PROTOCOL)

term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.lime)
print("=========================================")
print("   CCTchat - Serveur '" .. serverName .. "' demarre")
print("=========================================")
term.setTextColor(colors.white)
print("Protocole : " .. PROTOCOL)
print("En attente de connexions...\n")

while true do
    local id, message = rednet.receive(PROTOCOL)

    if type(message) == "table" and message.action then

        ----------------------------------------------------------------
        -- Decouverte / synchronisation entre serveurs (datacenter)
        ----------------------------------------------------------------
        if message.action == "server_hello" then
            if not peers[id] then
                peers[id] = true
                log("[peer] Nouveau serveur detecte : " .. (message.name or tostring(id)), colors.magenta)
            end
            rednet.send(id, { action = "server_hello_ack", name = serverName }, PROTOCOL)
            rednet.send(id, { action = "sync_bulk", users = db.getAllUsers() }, PROTOCOL)

        elseif message.action == "server_hello_ack" then
            if not peers[id] then
                peers[id] = true
                log("[peer] Lien etabli avec : " .. (message.name or tostring(id)), colors.magenta)
                rednet.send(id, { action = "sync_bulk", users = db.getAllUsers() }, PROTOCOL)
            end

        elseif message.action == "sync_bulk" then
            local added = 0
            for name, info in pairs(message.users or {}) do
                if not db.userExists(name) and info.hash and info.salt then
                    db.addUser(name, info.hash, info.salt)
                    added = added + 1
                end
            end
            if added > 0 then
                log("[sync] " .. added .. " compte(s) synchronise(s) depuis " .. tostring(id), colors.magenta)
            end

        elseif message.action == "sync_user" then
            if message.user and message.hash and message.salt and not db.userExists(message.user) then
                db.addUser(message.user, message.hash, message.salt)
                log("[sync] Compte synchronise : " .. message.user, colors.magenta)
            end

        ----------------------------------------------------------------
        -- Decouverte cote client
        ----------------------------------------------------------------
        elseif message.action == "discover" then
            rednet.send(id, { action = "discover_reply", name = serverName }, PROTOCOL)

        elseif message.action == "ping" then
            rednet.send(id, { action = "pong" }, PROTOCOL)

        ----------------------------------------------------------------
        -- Comptes
        ----------------------------------------------------------------
        elseif message.action == "register" then
            if not message.user or message.user == "" or not message.pass or message.pass == "" then
                rednet.send(id, { action = "register_fail", reason = "Pseudo ou mot de passe invalide." }, PROTOCOL)
            elseif db.userExists(message.user) then
                rednet.send(id, { action = "register_fail", reason = "Ce pseudo est deja pris." }, PROTOCOL)
            else
                local salt = hash.randomSalt()
                local h = hash.hashPassword(message.pass, salt)
                db.addUser(message.user, h, salt)
                rednet.send(id, { action = "register_ok" }, PROTOCOL)
                log("[+] Nouveau compte cree : " .. message.user, colors.cyan)

                -- On previent tous les autres serveurs connus pour tout synchroniser
                for peerId, _ in pairs(peers) do
                    rednet.send(peerId, { action = "sync_user", user = message.user, hash = h, salt = salt }, PROTOCOL)
                end
            end

        elseif message.action == "login" then
            local u = db.getUser(message.user or "")
            if not u then
                rednet.send(id, { action = "login_fail", reason = "Pseudo inconnu." }, PROTOCOL)
            elseif hash.hashPassword(message.pass or "", u.salt) ~= u.hash then
                rednet.send(id, { action = "login_fail", reason = "Mot de passe incorrect." }, PROTOCOL)
            else
                for cid, info in pairs(clients) do
                    if info.user == message.user then clients[cid] = nil end
                end
                clients[id] = { user = message.user, room = nil }
                rednet.send(id, { action = "login_ok", user = message.user }, PROTOCOL)
                log("[>] " .. message.user .. " connecte (id " .. id .. ")", colors.green)
            end

        ----------------------------------------------------------------
        -- Salons
        ----------------------------------------------------------------
        elseif message.action == "list_rooms" then
            rednet.send(id, { action = "room_list", rooms = roomList() }, PROTOCOL)

        elseif message.action == "create_room" then
            local info = clients[id]
            local name = message.room
            if not info then
                -- pas connecte, on ignore
            elseif not name or name == "" then
                rednet.send(id, { action = "create_room_fail", reason = "Nom invalide." }, PROTOCOL)
            elseif rooms[name] then
                rednet.send(id, { action = "create_room_fail", reason = "Ce salon existe deja." }, PROTOCOL)
            else
                local pwd = message.password
                rooms[name] = { password = (pwd and pwd ~= "" and pwd) or nil }
                rednet.send(id, { action = "create_room_ok" }, PROTOCOL)
                log("[#] Salon cree : " .. name .. " (par " .. info.user .. ")"
                    .. (rooms[name].password and " [protege]" or ""), colors.cyan)
            end

        elseif message.action == "join_room" then
            local info = clients[id]
            local name = message.room
            local roomInfo = rooms[name]
            if not info then
                -- pas connecte
            elseif not roomInfo then
                rednet.send(id, { action = "join_room_fail", reason = "Salon introuvable." }, PROTOCOL)
            elseif roomInfo.password and roomInfo.password ~= (message.password or "") then
                rednet.send(id, { action = "join_room_fail", reason = "Mot de passe incorrect." }, PROTOCOL)
            else
                if info.room then
                    broadcastToRoom(info.room, { action = "system", text = info.user .. " a quitte le salon." }, id)
                end
                info.room = name
                rednet.send(id, { action = "join_room_ok", room = name }, PROTOCOL)
                broadcastToRoom(name, { action = "system", text = info.user .. " a rejoint le salon." }, id)
                log("[#] " .. info.user .. " a rejoint '" .. name .. "'", colors.green)
            end

        elseif message.action == "leave_room" then
            local info = clients[id]
            if info and info.room then
                broadcastToRoom(info.room, { action = "system", text = info.user .. " a quitte le salon." }, id)
                info.room = nil
            end

        elseif message.action == "chat" then
            local info = clients[id]
            if info and info.room and message.text and message.text ~= "" then
                local out = { action = "chat", user = info.user, text = message.text, time = os.time() }
                broadcastToRoom(info.room, out, nil)
                log("[" .. info.room .. "] <" .. info.user .. "> " .. message.text, colors.white)
                logFile("[" .. info.room .. "] <" .. info.user .. "> " .. message.text)
            end

        elseif message.action == "logout" then
            local info = clients[id]
            if info then
                if info.room then
                    broadcastToRoom(info.room, { action = "system", text = info.user .. " a quitte le salon." }, id)
                end
                clients[id] = nil
                log("[<] " .. info.user .. " deconnecte", colors.orange)
            end
        end
    end
end
