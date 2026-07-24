-- /lib/nyxapi.lua : unified NyxOS system API for third-party scripts
--
-- A single entry point third-party packages (NyxApps, community
-- packages...) can dofile() to reach every core NyxOS subsystem, instead
-- of having to know the exact path of each individual /lib/*.lua file.
-- This is the intended extension point: new subsystems should register
-- themselves here so the surface can keep growing without breaking
-- existing callers.
--
--   local nyxapi = dofile("/lib/nyxapi.lua")
--   nyxapi.log.info("myapp", "started")
--   local db = nyxapi.db.open("myapp")
--   if nyxapi.permissions.isPrivileged(nyxapi.session().username) then ... end

local nyxapi = {}

nyxapi.VERSION = "1.0.1"

local function lazy(path)
    local loaded = nil
    return setmetatable({}, {
        __index = function(_, key)
            if not loaded then
                loaded = dofile(path)
            end
            return loaded[key]
        end,
        __call = function(_, ...)
            if not loaded then
                loaded = dofile(path)
            end
            return loaded(...)
        end,
    })
end

nyxapi.core = lazy("/lib/nyxlib.lua")
nyxapi.users = lazy("/lib/users.lua")
nyxapi.permissions = lazy("/lib/permissions.lua")
nyxapi.services = lazy("/lib/services.lua")
nyxapi.log = lazy("/lib/logger.lua")
nyxapi.db = lazy("/lib/db.lua")
nyxapi.network = lazy("/lib/network.lua")
nyxapi.toolkit = lazy("/lib/toolkit.lua")
nyxapi.machine = lazy("/lib/machineid.lua")
nyxapi.theme = lazy("/lib/theme.lua")
nyxapi.display = lazy("/lib/display.lua")
nyxapi.crypto = lazy("/lib/crypto.lua")

-- Convenience: current session (whoever is logged in right now).
function nyxapi.session()
    return nyxapi.core.loadSession()
end

------------------------------------------------------------------
-- Tiny pub/sub event bus, so independent packages/services can talk to
-- each other without hard dependencies on one another -- the "evolutive"
-- part of the system API: new event names can be introduced freely by
-- any package.
------------------------------------------------------------------
local listeners = {}

function nyxapi.on(eventName, callback)
    listeners[eventName] = listeners[eventName] or {}
    table.insert(listeners[eventName], callback)
end

function nyxapi.emit(eventName, ...)
    if not listeners[eventName] then return end
    for _, cb in ipairs(listeners[eventName]) do
        pcall(cb, ...)
    end
end

return nyxapi
