-- /bin/reboot.lua : clean reboot for NyxOS (see /bin/shutdown.lua)

local tmp = dofile("/lib/tmp.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local logger = dofile("/lib/logger.lua")

print("Rebooting NyxOS...")
logger.info("power", "clean reboot requested")

tmp.clean()
nyxlib.clearSession()

sleep(0.3)
os.reboot()
