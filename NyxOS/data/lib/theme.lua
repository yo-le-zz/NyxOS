-- /lib/theme.lua : accent colour chosen at install time (CloverOS-style)
-- Stored in /etc/nyx-theme.lua : { name = "...", accent = colors.xxx }

local theme = {}
local PATH = "/etc/nyx-theme.lua"
local palette = colors or colours

-- Theme palette offered at install time, inspired by CloverOS's theme
-- picker (https://github.com/PalorderSoftWorksOfficial/CloverOS)
theme.presets = {
    { name = "Nyx Violet",     accent = palette.purple },
    { name = "Ocean Blue",     accent = palette.blue },
    { name = "Cyan",           accent = palette.cyan },
    { name = "Forest Green",   accent = palette.green },
    { name = "Sunset Orange",  accent = palette.orange },
    { name = "Crimson Red",    accent = palette.red },
    { name = "Magenta",        accent = palette.magenta },
    { name = "Classic Grey",   accent = palette.lightGray },
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

-- Returns just the accent colour (with a fallback if the computer isn't
-- an Advanced Computer/Monitor in colour -- colors.xxx still exists as a
-- constant, but we fall back to "white" if accent happens to be nil).
function theme.accent()
    local t = theme.load()
    return t.accent or palette.white
end

return theme
