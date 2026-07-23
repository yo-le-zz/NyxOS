-- /lib/theme.lua : couleur d'accent choisie a l'installation (facon CloverOS)
-- Stockee dans /etc/nyx-theme.lua : { name = "...", accent = colors.xxx }

local theme = {}
local PATH = "/etc/nyx-theme.lua"
local palette = colors or colours

-- Palette de couleurs proposee a l'installation, inspiree du choix de
-- theme de CloverOS (https://github.com/PalorderSoftWorksOfficial/CloverOS)
theme.presets = {
    { name = "Violet Nyx",     accent = palette.purple },
    { name = "Bleu Ocean",     accent = palette.blue },
    { name = "Cyan",           accent = palette.cyan },
    { name = "Vert Foret",     accent = palette.green },
    { name = "Orange Couchant",accent = palette.orange },
    { name = "Rouge Cramoisi", accent = palette.red },
    { name = "Magenta",        accent = palette.magenta },
    { name = "Gris Classique", accent = palette.lightGray },
}

local DEFAULT = { name = theme.presets[1].name, accent = theme.presets[1].accent }

function theme.load()
    if not fs.exists(PATH) then
        return DEFAULT
    end
    local f = fs.open(PATH, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" and data.accent then
        return data
    end
    return DEFAULT
end

function theme.save(data)
    local f = fs.open(PATH, "w")
    f.write(textutils.serialize(data))
    f.close()
end

-- Renvoie juste la couleur d'accent (avec repli si l'ordinateur n'est pas
-- un Advanced Computer/Monitor en couleur -- colors.xxx existe quand meme
-- comme constante, mais on repli sur "white" si jamais accent est nil).
function theme.accent()
    local t = theme.load()
    return t.accent or palette.white
end

return theme
