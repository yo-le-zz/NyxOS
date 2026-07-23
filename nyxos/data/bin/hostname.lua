-- /bin/hostname.lua : affiche ou change le nom de l'ordinateur

local nyxlib = dofile("/lib/nyxlib.lua")
local args = {...}

if args[1] then
    nyxlib.setHostname(args[1])
    print("Nom d'hote change en : " .. args[1])
else
    print(nyxlib.getHostname())
end
