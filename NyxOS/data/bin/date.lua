-- /bin/date.lua : affiche la date et l'heure courantes (temps reel)

local args = {...}
local fmt = args[1] or "%d/%m/%Y %H:%M:%S"
print(os.date(fmt, math.floor(os.epoch("utc") / 1000)))
