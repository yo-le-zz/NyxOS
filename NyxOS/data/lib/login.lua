-- /lib/login.lua : ecran de demarrage NyxOS
--
-- 1) Menu de boot facon CloverOS (choix du mode de demarrage, avec
--    demarrage automatique apres un compte a rebours).
-- 2) Ecran de connexion multi-utilisateur (obligatoire pour entrer dans
--    le shell, sauf choix explicite du "shell de secours").
--
-- Tout est fait avec la librairie Basalt (/lib/basalt.lua) pour une
-- interface graphique soignee. Si Basalt est absent ou plante pour une
-- raison quelconque, chaque etape retombe automatiquement sur un mode
-- texte simple : l'ordinateur ne doit jamais rester bloque au demarrage.

local nyxlib = dofile("/lib/nyxlib.lua")
local users  = dofile("/lib/users.lua")
local theme  = dofile("/lib/theme.lua")

local login = {}
local palette = colors or colours

local function loadBasalt()
    return nyxlib.loadBasalt()
end

------------------------------------------------------------------
-- Menu de demarrage
------------------------------------------------------------------

-- Version texte simple et fiable (pas de dependance a Basalt) : affiche
-- les options puis un simple read(), sans decompte automatique en
-- parallele (CC:Tweaked ne permet pas facilement de lire au clavier et
-- decompter en meme temps sans coroutines/parallel -- inutile de prendre
-- ce risque sur l'ecran de secours texte).
local function bootMenuTextSimple(accent)
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
    pcall(term.setTextColor, accent)
    print("== NyxOS -- " .. nyxlib.getHostname() .. " ==")
    pcall(term.setTextColor, palette.white)
    print("")
    print("1) Demarrer NyxOS (par defaut)")
    print("2) Shell de secours (sans connexion)")
    print("")
    write("Choix (Entree = demarrer normalement) : ")
    local answer = read()
    if answer == "2" then
        return "recovery"
    end
    return "boot"
end

local function bootMenuBasalt(basalt, accent)
    local choice = "boot"
    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()
        local cx, cy = math.floor(w / 2), math.floor(h / 2)

        main:addLabel()
            :setText("NyxOS")
            :setForeground(accent)
            :setPosition(math.max(1, cx - 2), math.max(1, cy - 5))

        main:addLabel()
            :setText(nyxlib.getHostname() .. " -- choisis un mode de demarrage")
            :setForeground(palette.lightGray)
            :setPosition(math.max(1, cx - 18), math.max(1, cy - 3))

        local list = main:addList()
            :setPosition(math.max(1, cx - 15), math.max(1, cy - 1))
            :setSize(30, 3)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setSelectedBackground(accent)
            :setSelectedForeground(palette.black)
            :addItem("Demarrer NyxOS")
            :addItem("Shell de secours (sans connexion)")

        local countdown = main:addLabel()
            :setText("Demarrage automatique dans 5s -- Haut/Bas puis Entree")
            :setForeground(palette.gray)
            :setPosition(math.max(1, cx - 25), math.min(h, cy + 3))

        local selectedIndex = 1
        local remaining = 5
        local finished = false

        local function finish(sel)
            if finished then return end
            finished = true
            if sel == 2 then choice = "recovery" end
            basalt.stop()
        end

        list:onSelect(function(self, index, item)
            selectedIndex = index
        end)

        list:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then
                finish(selectedIndex)
            else
                remaining = -1
            end
        end)

        basalt.schedule(function()
            while remaining > 0 and not finished do
                sleep(1)
                remaining = remaining - 1
                if remaining > 0 then
                    countdown:setText("Demarrage automatique dans " .. remaining .. "s -- Haut/Bas puis Entree")
                end
            end
            if not finished then
                finish(1)
            end
        end)

        list:setFocused(true)
        basalt.run()
    end)
    if not ok then
        return "boot"
    end
    return choice
end

function login.bootMenu()
    local accent = theme.accent()
    local basalt = loadBasalt()
    if basalt then
        return bootMenuBasalt(basalt, accent)
    end
    return bootMenuTextSimple(accent)
end

------------------------------------------------------------------
-- Ecran de connexion
------------------------------------------------------------------

local function loginText(accent)
    local list = users.load()
    if #list == 0 then
        print("Aucun utilisateur configure. Cree un compte :")
        write("Nom d'utilisateur : ")
        local name = read()
        while not name or name == "" do
            write("Le nom ne peut pas etre vide. Nom d'utilisateur : ")
            name = read()
        end
        write("Mot de passe (optionnel) : ")
        local pass = read("*")
        users.add(name, pass, true)
        return name
    end

    while true do
        term.setBackgroundColor(palette.black)
        term.clear()
        term.setCursorPos(1, 1)
        pcall(term.setTextColor, accent)
        print("NyxOS -- " .. nyxlib.getHostname())
        pcall(term.setTextColor, palette.white)
        print("Utilisateurs : " .. table.concat((function()
            local names = {}
            for _, u in ipairs(list) do table.insert(names, u.username) end
            return names
        end)(), ", "))
        print("")
        write("login: ")
        local name = read()
        local user = users.find(name or "")
        if not user then
            print("Utilisateur inconnu.")
            sleep(1)
        else
            local ok = true
            if user.password and user.password ~= "" then
                write("password: ")
                local pass = read("*")
                ok = users.checkPassword(name, pass)
            end
            if ok then
                return user.username
            else
                print("Mot de passe incorrect.")
                sleep(1)
            end
        end
    end
end

local function loginBasalt(basalt, accent)
    local list = users.load()
    if #list == 0 then
        return nil -- pas d'utilisateur : on laisse le mode texte gerer la creation
    end

    local loggedUser = nil
    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()
        local cx, cy = math.floor(w / 2), math.floor(h / 2)

        main:addLabel()
            :setText("NyxOS -- " .. nyxlib.getHostname())
            :setForeground(accent)
            :setPosition(math.max(1, cx - 12), math.max(1, cy - 6))

        main:addLabel()
            :setText("Utilisateur :")
            :setForeground(palette.white)
            :setPosition(math.max(1, cx - 14), cy - 3)

        local userList = main:addList()
            :setPosition(math.max(1, cx - 14), cy - 2)
            :setSize(28, math.min(6, #list))
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setSelectedBackground(accent)
            :setSelectedForeground(palette.black)
        for _, u in ipairs(list) do
            userList:addItem(u.username)
        end

        local passLabel = main:addLabel()
            :setText("Mot de passe :")
            :setForeground(palette.white)
            :setPosition(math.max(1, cx - 14), cy + math.min(6, #list) + 1)

        local passInput = main:addInput()
            :setPosition(math.max(1, cx - 14), cy + math.min(6, #list) + 2)
            :setSize(28, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setReplaceChar("*")

        local status = main:addLabel()
            :setText("Selectionne ton utilisateur, entre le mot de passe puis valide.")
            :setForeground(palette.lightGray)
            :setPosition(math.max(1, cx - 25), cy + math.min(6, #list) + 4)

        local selected = list[1]
        userList:onSelect(function(self, index, item)
            selected = list[index]
        end)

        local function attempt()
            if not selected then return end
            if users.checkPassword(selected.username, passInput:getText()) then
                loggedUser = selected.username
                basalt.stop()
            else
                status:setText("Mot de passe incorrect, reessaie.")
                pcall(function() passInput:setText("") end)
            end
        end

        passInput:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then
                attempt()
            end
        end)

        local loginButton = main:addButton()
            :setText("Se connecter")
            :setPosition(math.max(1, cx - 8), cy + math.min(6, #list) + 6)
            :setSize(16, 1)
            :setBackground(accent)
            :setForeground(palette.black)
            :onClick(function() attempt() end)

        passInput:setFocused(true)
        basalt.run()
    end)
    if not ok then
        return nil
    end
    return loggedUser
end

-- Renvoie le nom de l'utilisateur connecte.
function login.authenticate()
    local accent = theme.accent()
    local basalt = loadBasalt()
    if basalt then
        local name = loginBasalt(basalt, accent)
        if name then
            return name
        end
        -- Basalt a plante, ou aucun utilisateur n'existe encore : on
        -- retombe sur le mode texte pour ne jamais bloquer le demarrage.
    end
    return loginText(accent)
end

return login
