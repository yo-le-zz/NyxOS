-- CCRF - lib/ui.lua : affichage terminal

local ui = {}

function ui.center(text, y)
    local w = term.getSize()
    term.setCursorPos(math.floor((w - #text) / 2) + 1, y)
    term.write(text)
end

function ui.clear()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

function ui.title(text)
    ui.clear()
    term.setTextColor(colors.red)
    ui.center(text, 4)
end

function ui.waitAnyKey()
    local _, key = os.pullEvent("key")
    return key
end

-- Retourne true si la touche ENTREE a ete pressee
function ui.waitEnterOrCancel()
    return ui.waitAnyKey() == keys.enter
end

-- Affiche une ligne de log pour un fichier/dossier supprime + la progression
function ui.printStep(path, label, done, total)
    local percent = math.floor((done / total) * 100)
    term.setTextColor(colors.red)
    print("Suppression (" .. label .. ") :")
    term.setTextColor(colors.white)
    print(path)
    term.setTextColor(colors.yellow)
    print(percent .. "%  (" .. done .. "/" .. total .. ")")
    print("")
end

return ui
