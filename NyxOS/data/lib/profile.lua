-- /lib/profile.lua : computer profiles
--
--   classic : normal computer / advanced computer with a big screen:
--             floating windows, drag & drop, every app
--   tablet  : pocket computers, mini PCs, small monitors, touch screens:
--             full-screen apps, big menu rows, no window dragging
--   server  : no desktop; a text console with the services dashboard
--
-- Stored in /etc/nyx-config.lua as `profile` (the boot interface `uiMode`
-- follows it: server -> "server", otherwise "desktop").

local profile = {}

profile.list = {
    { id = "classic", name = "Classic", description = "Desktop with floating windows" },
    { id = "tablet", name = "Tablet / mini PC", description = "Small screens and touch: full-screen apps" },
    { id = "server", name = "Server", description = "Text console, services dashboard, no desktop" },
}

local function config()
    local ok, nyxlib = pcall(dofile, "/lib/nyxlib.lua")
    if not ok then return {} end
    local okT, cfg = pcall(nyxlib.loadTable, "/etc/nyx-config.lua")
    return okT and type(cfg) == "table" and cfg or {}
end

-- Best guess for this computer: pocket computers and small screens are tablets.
function profile.detect()
    if _G.pocket then return "tablet" end
    local okS, w, h = pcall(term.getSize)
    if okS and w and (w < 40 or (h and h < 14)) then return "tablet" end
    return "classic"
end

function profile.current()
    local cfg = config()
    local p = cfg.profile
    if cfg.uiMode == "server" then p = "server" end
    if p == "classic" or p == "tablet" or p == "server" then return p end
    return profile.detect()
end

function profile.isTablet() return profile.current() == "tablet" end
function profile.isServer() return profile.current() == "server" end

-- Which profile an app module is available in (module.profiles = { "classic" })
function profile.appAllowed(mod, p)
    p = p or profile.current()
    if type(mod.profiles) ~= "table" then return true end
    for _, id in ipairs(mod.profiles) do if id == p then return true end end
    return false
end

-- Table fields for /etc/nyx-config.lua
function profile.fields(p)
    return { profile = p, uiMode = (p == "server") and "server" or "desktop", gui = (p ~= "server") }
end

function profile.set(p)
    if p ~= "classic" and p ~= "tablet" and p ~= "server" then return false, "unknown profile" end
    local nyxlib = dofile("/lib/nyxlib.lua")
    local cfg = nyxlib.loadTable("/etc/nyx-config.lua")
    for k, v in pairs(profile.fields(p)) do cfg[k] = v end
    nyxlib.saveTable("/etc/nyx-config.lua", cfg)
    return true
end

return profile
