-- /bin/display.lua : gere l'ecran (moniteur) connecte
-- Usage :
--   display          affiche l'ecran actuellement configure
--   display scan      relance la detection (ecran branche a chaud)
--   display scale <n> change l'echelle de texte de l'ecran connecte

local nyxdisplay = dofile("/lib/display.lua")
local args = {...}

if args[1] == "scan" then
    local ok = nyxdisplay.setup(false)
    if not ok then
        print("Aucun ecran (moniteur) detecte.")
    end
    return
end

if args[1] == "scale" then
    local scale = tonumber(args[2])
    if not scale then
        print("Usage : display scale <nombre>")
        return
    end
    local mon = nyxdisplay.findMonitor()
    if not mon then
        print("Aucun ecran connecte.")
        return
    end
    local cfg = nyxdisplay.loadConfig()
    cfg.scale = scale
    nyxdisplay.saveConfig(cfg)
    mon.setTextScale(scale)
    print("Echelle de texte mise a " .. scale .. ".")
    return
end

local cfg = nyxdisplay.loadConfig()
if cfg.side then
    print("Ecran actif      : " .. cfg.side)
    print("Type             : " .. (cfg.advanced and "Advanced Monitor (couleur)" or "Monitor standard"))
    print("Echelle de texte : " .. tostring(cfg.scale))
else
    print("Aucun ecran configure. Utilise 'display scan' pour en detecter un.")
end
