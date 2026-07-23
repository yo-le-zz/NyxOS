-- /lib/shellui.lua : Shell graphique NyxOS avec Basalt
--
-- Interface shell complete avec :
-- - Zone de sortie scrollable pour les commandes
-- - Champ input pour taper les commandes
-- - Support touch/click sur l'ecran
-- - Historique des commandes (haut/bas)
-- - Execution via shell.run()

local shellui = {}
local palette = colors or colours

local function loadBasalt()
    if not fs.exists("/lib/basalt.lua") then
        return nil
    end
    local ok, mod = pcall(dofile, "/lib/basalt.lua")
    if ok and mod then
        return mod
    end
    return nil
end

-- Capture la sortie d'une commande et la renvoie sous forme de string
local function captureCommand(cmd)
    local oldRedirect = term.redirect
    local output = {}
    
    term.redirect({
        write = function(text)
            table.insert(output, text)
        end,
        blit = function(text, fg, bg)
            table.insert(output, text)
        end,
        clear = function()
            output = {}
        end,
        clearLine = function()
            -- Ignore
        end,
        getCursorPos = function()
            return 1, 1
        end,
        setCursorPos = function(x, y)
            -- Ignore
        end,
        getCursorBlink = function()
            return false
        end,
        setCursorBlink = function(b)
            -- Ignore
        end,
        getSize = function()
            return 51, 19
        end,
        scroll = function(n)
            -- Ignore
        end,
        getTextColor = function()
            return palette.white
        end,
        setTextColor = function(c)
            -- Ignore
        end,
        getBackgroundColor = function()
            return palette.black
        end,
        setBackgroundColor = function(c)
            -- Ignore
        end,
    })
    
    local ok, err = pcall(shell.run, cmd)
    
    term.redirect(oldRedirect)
    
    return table.concat(output), err
end

-- Shell graphique principal
function shellui.run()
    local basalt = loadBasalt()
    if not basalt then
        print("Erreur : Basalt non disponible. Shell graphique impossible.")
        return false
    end

    local theme = dofile("/lib/theme.lua")
    local accent = theme.accent()
    local nyxlib = dofile("/lib/nyxlib.lua")

    local ok = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)
        local w, h = main:getWidth(), main:getHeight()

        -- En-tête avec hostname et utilisateur
        local header = main:addFrame()
            :setPosition(1, 1)
            :setSize(w, 2)
            :setBackground(accent)
        
        header:addLabel()
            :setText("NyxOS - " .. nyxlib.getHostname())
            :setForeground(palette.black)
            :setPosition(2, 1)
        
        local currentUser = nyxlib.getSession() or "guest"
        header:addLabel()
            :setText(currentUser .. "@nyxos")
            :setForeground(palette.black)
            :setPosition(w - #currentUser - 8, 1)

        -- Zone de sortie des commandes (scrollable)
        local outputBox = main:addTextBox()
            :setPosition(2, 4)
            :setSize(w - 3, h - 5)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setText("NyxOS Shell Graphique v1.0\nTape 'help' pour la liste des commandes.\n\n")

        -- Champ input pour les commandes
        local inputLabel = main:addLabel()
            :setText("$")
            :setForeground(accent)
            :setPosition(2, h - 1)
        
        local cmdInput = main:addInput()
            :setPosition(4, h - 1)
            :setSize(w - 6, 1)
            :setBackground(palette.gray)
            :setForeground(palette.white)
            :setPlaceholder("Entrez une commande...")

        -- Historique des commandes
        local history = {}
        local historyIndex = 0

        -- Fonction pour exécuter une commande
        local function executeCommand(cmd)
            if cmd == nil or cmd == "" then
                return
            end

            -- Ajouter à l'historique
            table.insert(history, cmd)
            historyIndex = #history + 1

            -- Afficher la commande dans la sortie
            local currentText = outputBox:getText()
            outputBox:setText(currentText .. "$ " .. cmd .. "\n")

            -- Exécuter la commande et capturer la sortie
            local output, err = captureCommand(cmd)
            
            if output and output ~= "" then
                outputBox:setText(outputBox:getText() .. output .. "\n")
            end
            
            if err and not ok then
                outputBox:setText(outputBox:getText() .. "Erreur: " .. tostring(err) .. "\n")
            end
            
            outputBox:setText(outputBox:getText() .. "\n")
            
            -- Scroll vers le bas
            outputBox:scrollTo("bottom")
            
            -- Vider l'input
            cmdInput:setText("")
        end

        -- Gestion de la touche Entrée
        cmdInput:onKey(function(self, key)
            if key == keys.enter or key == keys.numPadEnter then
                executeCommand(cmdInput:getText())
            elseif key == keys.up then
                -- Navigation dans l'historique (haut)
                if historyIndex > 1 then
                    historyIndex = historyIndex - 1
                    cmdInput:setText(history[historyIndex] or "")
                end
            elseif key == keys.down then
                -- Navigation dans l'historique (bas)
                if historyIndex < #history then
                    historyIndex = historyIndex + 1
                    cmdInput:setText(history[historyIndex] or "")
                else
                    historyIndex = #history + 1
                    cmdInput:setText("")
                end
            end
        end)

        -- Bouton pour exécuter (support touch)
        local runButton = main:addButton()
            :setText("Exécuter")
            :setPosition(w - 10, h - 1)
            :setSize(8, 1)
            :setBackground(accent)
            :setForeground(palette.black)
            :onClick(function()
                executeCommand(cmdInput:getText())
            end)

        -- Focus sur l'input au démarrage
        cmdInput:setFocused(true)

        -- Message d'accueil dans la sortie
        local motd = ""
        if fs.exists("/etc/motd") then
            local f = fs.open("/etc/motd", "r")
            motd = f.readAll()
            f.close()
        end
        if motd and motd ~= "" then
            outputBox:setText(motd .. "\n\n")
        end

        basalt.run()
    end)

    if not ok then
        print("Erreur lors du lancement du shell graphique.")
        return false
    end

    return true
end

-- Version texte de secours (si Basalt échoue)
function shellui.runTextFallback()
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
    
    local nyxlib = dofile("/lib/nyxlib.lua")
    local theme = dofile("/lib/theme.lua")
    local accent = theme.accent()
    
    pcall(term.setTextColor, accent)
    print("=== NyxOS Shell (mode texte) ===")
    pcall(term.setTextColor, palette.white)
    print("Basalt indisponible - utilisation du shell standard.")
    print("")
    
    -- Lancer le shell standard
    shell.run("/bin/shell")
end

return shellui
