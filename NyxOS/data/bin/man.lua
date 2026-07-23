-- /bin/man.lua : affiche l'aide des commandes NyxOS, avec un vrai pager
-- (defilement complet, pas seulement les dernieres lignes).
-- Usage : man [commande]

local nyxlib = dofile("/lib/nyxlib.lua")
local themeOk, theme = pcall(dofile, "/lib/theme.lua")
local palette = colors or colours

local pages = {
    tree = {
        "tree [-L profondeur] [chemin]",
        "Affiche l'arborescence des fichiers façon Unix `tree`, avec le",
        "nombre de dossiers/fichiers a la fin.",
        "",
        "Exemples :",
        "  tree",
        "  tree /home",
        "  tree -L 2 /",
    },
    apt = {
        "apt install|remove|purge|list|info - gestionnaire de paquets NyxOS.",
        "",
        "  apt install <url|chemin>   telecharge/execute un install.lua",
        "  apt install ./disk         installe depuis un dossier local",
        "  apt install ./disk nom     force le nom du paquet",
        "  apt remove <paquet>        supprime les fichiers, garde /etc",
        "  apt purge <paquet>         supprime tout, y compris /etc",
        "  apt list                   liste les paquets installes",
        "  apt info <paquet>          details sur un paquet",
        "",
        "Un paquet peut fournir un fichier control.lua (a cote de son",
        "install.lua) avec {name=, version=, description=, depends={}},",
        "un peu comme le fichier control d'un .deb Debian. Voir la doc",
        "docs/PACKAGING.md pour creer tes propres paquets/disquettes.",
    },
    cat = { "cat <fichier...>", "Affiche le contenu d'un ou plusieurs fichiers." },
    echo = { "echo <texte>", "Affiche le texte donne." },
    touch = { "touch <fichier>", "Cree un fichier vide s'il n'existe pas." },
    pwd = { "pwd", "Affiche le dossier courant." },
    whoami = { "whoami", "Affiche l'utilisateur actuellement connecte." },
    hostname = { "hostname [nom]", "Affiche ou change le nom de l'ordinateur." },
    uname = { "uname", "Affiche les informations systeme." },
    date = { "date [format]", "Affiche la date et l'heure." },
    uptime = { "uptime", "Affiche le temps ecoule depuis le demarrage." },
    df = { "df", "Affiche l'espace disque disponible." },
    find = { "find [dossier] -name <motif>", "Recherche des fichiers." },
    grep = { "grep <motif> <fichier>", "Recherche du texte dans un fichier." },
    head = { "head [-n N] <fichier>", "Affiche les N premieres lignes." },
    tail = { "tail [-n N] <fichier>", "Affiche les N dernieres lignes." },
    wc = { "wc <fichier>", "Compte lignes/mots/caracteres." },
    passwd = {
        "passwd [utilisateur]",
        "Change le mot de passe. Sans argument : change ton propre mot de",
        "passe (l'ancien est demande s'il y en a un). Avec un nom",
        "d'utilisateur : change le mot de passe d'un autre compte, reserve",
        "aux administrateurs.",
    },
    adduser = {
        "adduser <nom> [admin]",
        "Cree un nouvel utilisateur NyxOS (reserve aux administrateurs).",
        "Ajoute 'admin' a la fin pour en faire un administrateur.",
        "",
        "Exemples :",
        "  adduser bob",
        "  adduser alice admin",
    },
    deluser = {
        "deluser <nom>",
        "Supprime un utilisateur NyxOS (reserve aux administrateurs).",
        "Refuse de supprimer le dernier administrateur du systeme.",
    },
    users = { "users", "Liste les utilisateurs configures sur cet ordinateur." },
    display = { "display [scan|scale <n>]", "Gere l'ecran (moniteur) connecte." },
    neofetch = { "neofetch", "Affiche un resume du systeme avec le logo NyxOS." },
    man = {
        "man <commande>",
        "Affiche l'aide d'une commande NyxOS dans un pager.",
        "",
        "Deplacement dans le pager :",
        "  Haut/Bas ou fleches   defiler d'une ligne",
        "  Espace / Page suiv.   page suivante",
        "  Page prec.            page precedente",
        "  q ou Entree           quitter",
    },
}

local function sortedNames()
    local names = {}
    for name in pairs(pages) do table.insert(names, name) end
    table.sort(names)
    return names
end

-- Construit le texte complet (titre + description) d'une page pour le
-- pager, sous forme de liste de lignes.
local function pageLines(cmd)
    local body = pages[cmd]
    local lines = { cmd, string.rep("-", #cmd) }
    for _, l in ipairs(body) do
        table.insert(lines, l)
    end
    return lines
end

local function indexLines()
    local lines = { "Commandes NyxOS disponibles :", "" }
    for _, name in ipairs(sortedNames()) do
        table.insert(lines, "  " .. name)
    end
    table.insert(lines, "")
    table.insert(lines, "Utilise 'man <commande>' pour plus de details.")
    return lines
end

------------------------------------------------------------------
-- Pager en mode texte pur (fiable, fonctionne toujours) : defilement
-- complet ligne par ligne et page par page grace aux evenements clavier,
-- au lieu d'un simple `print` qui ne laissait voir que les dernieres
-- lignes.
------------------------------------------------------------------
local function runTextPager(lines, accent)
    local w, h = term.getSize()
    local viewHeight = h - 1
    local offset = 0
    local maxOffset = math.max(0, #lines - viewHeight)

    local function draw()
        term.setBackgroundColor(palette.black)
        term.clear()
        for row = 1, viewHeight do
            local line = lines[offset + row]
            if line then
                term.setCursorPos(1, row)
                pcall(term.setTextColor, palette.white)
                term.write(line)
            end
        end
        term.setCursorPos(1, h)
        pcall(term.setTextColor, accent or palette.lightGray)
        term.clearLine()
        term.write("-- ligne " .. (offset + 1) .. "/" .. #lines ..
            " -- Haut/Bas defile, Espace page suivante, q quitte --")
        pcall(term.setTextColor, palette.white)
    end

    draw()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.q or key == keys.enter or key == keys.numPadEnter then
            break
        elseif key == keys.down then
            offset = math.min(maxOffset, offset + 1)
            draw()
        elseif key == keys.up then
            offset = math.max(0, offset - 1)
            draw()
        elseif key == keys.space or key == keys.pageDown then
            offset = math.min(maxOffset, offset + viewHeight)
            draw()
        elseif key == keys.pageUp then
            offset = math.max(0, offset - viewHeight)
            draw()
        end
    end
    term.setBackgroundColor(palette.black)
    term.clear()
    term.setCursorPos(1, 1)
end

------------------------------------------------------------------
-- Pager graphique (Basalt), avec une vraie zone de defilement. Si
-- Basalt est absent ou echoue, on retombe automatiquement sur le pager
-- texte ci-dessus.
------------------------------------------------------------------
local function runBasaltPager(lines, accent)
    if not fs.exists("/lib/basalt.lua") then
        return false
    end
    local ok, basalt = pcall(dofile, "/lib/basalt.lua")
    if not ok or not basalt then
        return false
    end

    local ran = pcall(function()
        local main = basalt.getMainFrame():setBackground(palette.black)

        local scroll = main:addScrollFrame()
            :setBackground(palette.black)
            :setPosition(2, 2)
            :setSize("{parent.width - 2}", "{parent.height - 3}")
            :setScrollBarColor(accent or palette.lightGray)

        for i, line in ipairs(lines) do
            scroll:addLabel()
                :setText(line)
                :setForeground(palette.white)
                :setPosition(1, i)
        end

        local hint = main:addLabel()
            :setText("Haut/Bas ou molette pour defiler -- q ou Entree pour quitter")
            :setForeground(accent or palette.lightGray)
            :setPosition(2, "{parent.height - 1}")

        local function onKey(_, key)
            if key == keys.q or key == keys.enter or key == keys.numPadEnter then
                basalt.stop()
            elseif key == keys.down then
                scroll:setOffsetY(scroll:getOffsetY() + 1)
            elseif key == keys.up then
                scroll:setOffsetY(math.max(0, scroll:getOffsetY() - 1))
            elseif key == keys.space or key == keys.pageDown then
                scroll:setOffsetY(scroll:getOffsetY() + (select(2, term.getSize())))
            elseif key == keys.pageUp then
                scroll:setOffsetY(math.max(0, scroll:getOffsetY() - (select(2, term.getSize()))))
            end
        end

        main:onKey(onKey)
        scroll:onScroll(function(self, direction)
            self:setOffsetY(math.max(0, self:getOffsetY() + direction))
        end)

        basalt.run()
    end)
    return ran
end

local function showPager(lines)
    local accent = nil
    if themeOk and theme then
        local ok, a = pcall(theme.accent)
        if ok then accent = a end
    end
    if not runBasaltPager(lines, accent) then
        runTextPager(lines, accent)
    end
end

------------------------------------------------------------------

local args = { ... }
local cmd = args[1]

if not cmd then
    showPager(indexLines())
    return
end

if pages[cmd] then
    showPager(pageLines(cmd))
else
    print("Pas de page de manuel pour '" .. cmd .. "'.")
end
