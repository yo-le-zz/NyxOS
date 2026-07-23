-- /lib/display.lua
-- Gestion de l'affichage sur un ecran (moniteur) externe.
--
-- Detecte automatiquement un moniteur branche (peu importe le cote ou le
-- nom reseau via modem : "top", "left", "monitor_0", ...), determine s'il
-- s'agit d'un Advanced Monitor (couleur) ou d'un Monitor standard, puis
-- redirige le terminal dessus. Si aucun moniteur n'est trouve, NyxOS
-- continue d'utiliser l'ecran natif de l'ordinateur normalement.

local nyxdisplay = {}

local CONFIG_PATH = "/etc/nyx-display.lua"

local function loadConfig()
    if not fs.exists(CONFIG_PATH) then
        return {}
    end
    local f = fs.open(CONFIG_PATH, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

local function saveConfig(cfg)
    local f = fs.open(CONFIG_PATH, "w")
    f.write(textutils.serialize(cfg))
    f.close()
end

nyxdisplay.loadConfig = loadConfig
nyxdisplay.saveConfig = saveConfig

-- Cherche un peripherique de type "monitor", quel que soit le cote ou le
-- nom reseau sur lequel il est connecte (detection automatique de la
-- position). Renvoie l'objet moniteur et son nom/cote.
function nyxdisplay.findMonitor()
    if not peripheral then
        return nil
    end
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "monitor" then
            local mon = peripheral.wrap(name)
            if mon then
                return mon, name
            end
        end
    end
    return nil
end

-- Detecte le moniteur, l'initialise (echelle de texte, couleurs) et y
-- redirige le terminal courant. quiet=true evite les messages de log.
-- Renvoie ok, side, isAdvanced
function nyxdisplay.setup(quiet)
    local mon, name = nyxdisplay.findMonitor()
    if not mon then
        return false
    end

    local isAdvanced = false
    local ok = pcall(function()
        isAdvanced = mon.isColour()
    end)
    if not ok then
        isAdvanced = false
    end

    local cfg = loadConfig()
    cfg.side = name
    cfg.advanced = isAdvanced
    cfg.scale = cfg.scale or (isAdvanced and 0.5 or 1)
    saveConfig(cfg)

    pcall(mon.setTextScale, cfg.scale)
    term.redirect(mon)

    local palette = colors or colours
    if palette then
        pcall(term.setBackgroundColor, palette.black)
        pcall(term.setTextColor, palette.white)
    end
    term.clear()
    term.setCursorPos(1, 1)

    if not quiet then
        print("Ecran detecte : " .. name ..
            (isAdvanced and " (Advanced Monitor)" or " (Monitor standard)"))
    end

    return true, name, isAdvanced
end

return nyxdisplay
