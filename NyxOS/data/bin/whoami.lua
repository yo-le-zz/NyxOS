-- /bin/whoami.lua : prints the current user

local nyxlib = dofile("/lib/nyxlib.lua")
local passwd = nyxlib.loadPasswd()
print(passwd.username or "unknown")
