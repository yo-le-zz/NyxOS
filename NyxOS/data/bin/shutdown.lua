-- /bin/shutdown.lua : clean shutdown for NyxOS
--
-- CC:Tweaked gives Lua no way to run code exactly at power-off, so a
-- clean shutdown here means: always shut down *through this command*
-- (never rely on holding the terminate combo), which flushes every
-- running service's state, wipes /var/tmp and /var/apt/tmp, clears the
-- login session, and only then calls os.shutdown().

local tmp = dofile("/lib/tmp.lua")
local nyxlib = dofile("/lib/nyxlib.lua")
local logger = dofile("/lib/logger.lua")

print("Shutting down NyxOS...")
logger.info("power", "clean shutdown requested")

tmp.clean()
nyxlib.clearSession()

sleep(0.3)
os.shutdown()
