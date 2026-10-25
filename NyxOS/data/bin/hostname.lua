-- /bin/hostname.lua : shows or changes the computer's name

local nyxlib = dofile("/lib/nyxlib.lua")
local args = {...}

if args[1] then
    nyxlib.setHostname(args[1])
    print("Hostname changed to: " .. args[1])
else
    print(nyxlib.getHostname())
end
