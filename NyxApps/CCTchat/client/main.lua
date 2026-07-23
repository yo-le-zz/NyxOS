-- CCTchat - Client principal
local dir = fs.getDir(shell.getRunningProgram())
local net = dofile(fs.combine(dir, "libs/net.lua"))
local ui  = dofile(fs.combine(dir, "libs/ui.lua"))

local PROTOCOL = "cctchat"
net.open()

local serverId = nil
local serverName = nil
local username = nil

-- Attend une reponse dont l'action fait partie de `actions`, en ignorant
-- les autres messages du protocole (ex: sync entre serveurs) qui pourraient
-- arriver au meme moment.
local function waitForActions(actions, timeout)
    local deadline = os.clock() + (timeout or 5)
    while true do
        local remaining = deadline - os.clock()
        if remaining <= 0 then return nil, nil end
        local id, msg = rednet.receive(PROTOCOL, remaining)
        if msg and type(msg) == "table" and actions[msg.action] then
            return id, msg
        end
    end
end

-- Recherche de tous les serveurs CCTchat repondant sur le reseau (datacenters)
local function discoverServers()
    rednet.broadcast({ action = "discover" }, PROTOCOL)
    local found = {}
    local seen = {}
    local timer = os.startTimer(2)
    while true do
        local ev, a, b, c = os.pullEvent()
        if ev == "rednet_message" then
            local senderId, message, protocol = a, b, c
            if protocol == PROTOCOL and type(message) == "table"
               and message.action == "discover_reply" and not seen[senderId] then
                seen[senderId] = true
                table.insert(found, { id = senderId, name = message.name or ("Serveur " .. senderId) })
            end
        elseif ev == "timer" and a == timer then
            break
        end
    end
    return found
end

local function selectServer()
    while true do
        ui.header("CCTchat - Recherche des serveurs...")
        local servers = discoverServers()

        ui.header("CCTchat - Serveurs disponibles")
        if #servers == 0 then
            ui.print("Aucun serveur trouve sur le reseau.", colors.red)
            print("")
            print("Appuyez sur Entree pour relancer la recherche.")
            read()
        else
            for i, s in ipairs(servers) do
                print(i .. ") " .. s.name)
            end
            print("")
            print("R) Relancer la recherche")
            local choice = ui.ask("Choix : ")
            if choice:upper() == "R" then
                -- on relance simplement la boucle
            else
                local idx = tonumber(choice)
                if idx and servers[idx] then
                    serverId = servers[idx].id
                    serverName = servers[idx].name
                    return
                end
            end
        end
    end
end

-- Menu de connexion / inscription. Renvoie "ok", "quit" ou "changeserver".
local function menu()
    while true do
        ui.header("CCTchat - " .. serverName)
        print("1) Se connecter")
        print("2) Creer un compte")
        print("3) Changer de serveur")
        print("4) Quitter")
        local choice = ui.ask("Choix : ")

        if choice == "1" or choice == "2" then
            local user = ui.ask("Pseudo : ")
            local pass = ui.askPassword("Mot de passe : ")
            local action = (choice == "1") and "login" or "register"
            rednet.send(serverId, { action = action, user = user, pass = pass }, PROTOCOL)
            local _, resp = waitForActions(
                { login_ok = true, login_fail = true, register_ok = true, register_fail = true }, 5)

            if not resp then
                ui.print("Le serveur ne repond pas.", colors.red)
                sleep(2)
            elseif resp.action == "login_ok" then
                username = resp.user
                return "ok"
            elseif resp.action == "register_ok" then
                ui.print("Compte cree ! Vous pouvez maintenant vous connecter.", colors.green)
                sleep(2)
            elseif resp.action == "login_fail" or resp.action == "register_fail" then
                ui.print("Erreur : " .. resp.reason, colors.red)
                sleep(2)
            end

        elseif choice == "3" then
            return "changeserver"
        elseif choice == "4" then
            return "quit"
        end
    end
end

-- Ecran des salons. Renvoie le nom du salon rejoint, ou "logout".
local function roomMenu()
    while true do
        rednet.send(serverId, { action = "list_rooms" }, PROTOCOL)
        local _, resp = waitForActions({ room_list = true }, 3)

        ui.header("CCTchat - Salons (" .. username .. ")")
        local rooms = (resp and resp.rooms) or {}

        if not resp then
            ui.print("Le serveur ne repond pas.", colors.red)
        elseif #rooms == 0 then
            ui.print("Aucun salon existant pour le moment.", colors.gray)
        else
            for i, r in ipairs(rooms) do
                local tag = r.protected and "  [protege]" or ""
                print(i .. ") " .. r.name .. "  (" .. r.count .. " connecte(s))" .. tag)
            end
        end
        print("")
        print("N) Nouveau salon")
        print("D) Deconnexion")
        local choice = ui.ask("Choix : ")
        local up = choice:upper()

        if up == "D" then
            rednet.send(serverId, { action = "logout" }, PROTOCOL)
            return "logout"

        elseif up == "N" then
            local name = ui.ask("Nom du salon : ")
            if name ~= "" then
                local roomPass = ui.askPassword("Mot de passe (vide = aucun) : ")
                rednet.send(serverId, { action = "create_room", room = name, password = roomPass }, PROTOCOL)
                local _, r2 = waitForActions({ create_room_ok = true, create_room_fail = true }, 3)
                if r2 and r2.action == "create_room_ok" then
                    rednet.send(serverId, { action = "join_room", room = name, password = roomPass }, PROTOCOL)
                    local _, r3 = waitForActions({ join_room_ok = true, join_room_fail = true }, 3)
                    if r3 and r3.action == "join_room_ok" then
                        return r3.room
                    elseif r3 then
                        ui.print("Erreur : " .. (r3.reason or "inconnue"), colors.red)
                        sleep(2)
                    end
                elseif r2 then
                    ui.print("Erreur : " .. (r2.reason or "inconnue"), colors.red)
                    sleep(2)
                end
            end

        else
            local idx = tonumber(choice)
            if idx and rooms[idx] then
                local roomPass = ""
                if rooms[idx].protected then
                    roomPass = ui.askPassword("Mot de passe du salon : ")
                end
                rednet.send(serverId, { action = "join_room", room = rooms[idx].name, password = roomPass }, PROTOCOL)
                local _, r2 = waitForActions({ join_room_ok = true, join_room_fail = true }, 3)
                if r2 and r2.action == "join_room_ok" then
                    return r2.room
                elseif r2 then
                    ui.print("Erreur : " .. (r2.reason or "inconnue"), colors.red)
                    sleep(2)
                end
            end
        end
    end
end

-- Ecran de chat pour un salon donne. Renvoie "rooms", "quit" ou "lost".
local function chatScreen(room)
    ui.header("CCTchat - Salon '" .. room .. "' (" .. username .. ")")
    ui.print("Message puis Entree. /rooms = changer de salon, /quit = deconnexion.", colors.gray)
    print("")

    local running = true
    local lastSeen = os.clock()
    local outcome = nil

    local function listen()
        while running do
            local senderId, message = rednet.receive(PROTOCOL, 1)
            if senderId == serverId then lastSeen = os.clock() end
            if message and type(message) == "table" then
                if message.action == "chat" then
                    if message.user == username then
                        ui.print("[Vous] " .. message.text, colors.cyan)
                    else
                        ui.print("[" .. message.user .. "] " .. message.text, colors.white)
                    end
                elseif message.action == "system" then
                    ui.print("* " .. message.text, colors.yellow)
                end
            end
        end
    end

    local function heartbeat()
        while running do
            rednet.send(serverId, { action = "ping" }, PROTOCOL)
            sleep(3)
        end
    end

    local function watchdog()
        while running do
            sleep(1)
            if os.clock() - lastSeen > 8 then
                running = false
                outcome = "lost"
            end
        end
    end

    local function inputLoop()
        while running do
            local line = ui.ask("> ")
            if running then
                if line == "/quit" then
                    rednet.send(serverId, { action = "logout" }, PROTOCOL)
                    running = false
                    outcome = "quit"
                elseif line == "/rooms" then
                    rednet.send(serverId, { action = "leave_room" }, PROTOCOL)
                    running = false
                    outcome = "rooms"
                elseif line ~= "" then
                    rednet.send(serverId, { action = "chat", text = line }, PROTOCOL)
                end
            end
        end
    end

    parallel.waitForAny(listen, heartbeat, watchdog, inputLoop)

    if outcome == "lost" then
        print("")
        ui.print("Connexion au serveur perdue !", colors.red)
        sleep(2)
    end

    return outcome or "rooms"
end

-- Boucle principale une fois un serveur choisi. Renvoie "quit", "lost" ou "changeserver".
local function connectionLoop()
    while true do
        local result = menu()
        if result == "quit" or result == "changeserver" then
            return result
        end

        -- connecte, on gere les salons
        while true do
            local room = roomMenu()
            if room == "logout" then
                break -- retour au menu de connexion, meme serveur
            end
            local outcome = chatScreen(room)
            if outcome == "lost" then
                return "lost"
            end
            -- outcome == "rooms" -> on retourne au roomMenu
        end
    end
end

while true do
    selectServer()
    local outcome = connectionLoop()
    if outcome == "quit" then
        ui.print("A bientot !", colors.lime)
        break
    end
    -- "lost" ou "changeserver" -> on relance la recherche de serveurs
end
