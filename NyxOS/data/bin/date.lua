-- /bin/date.lua : prints the current date and time (real time)

local args = {...}
local fmt = args[1] or "%d/%m/%Y %H:%M:%S"
print(os.date(fmt, math.floor(os.epoch("utc") / 1000)))
