-- /bin/whoami.lua : affiche l'utilisateur courant

local nyxlib = dofile("/lib/nyxlib.lua")
local passwd = nyxlib.loadPasswd()
print(passwd.username or "inconnu")
