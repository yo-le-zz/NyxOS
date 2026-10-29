-- /bin/nyxupdate.lua : check for and install NyxOS updates
-- Usage:
--   nyxupdate                 same as "check"
--   nyxupdate check           look for a newer version (GitHub tags X.Y.Z)
--   nyxupdate install         install the newest version (administrator)
--   nyxupdate status          show the settings
--   nyxupdate repo <owner/name>
--   nyxupdate auto <on|off>   background check on the desktop
--   nyxupdate interval <hours>
local updater = dofile("/lib/updater.lua")
local args = { ... }
local cmd = args[1] or "check"

local function admin()
    local ok, permissions = pcall(dofile, "/lib/permissions.lua")
    if not ok then return false end
    return (permissions.requirePrivileged("changing or installing updates"))
end

if cmd == "check" then
    local info, err = updater.check(true)
    if not info then print("Cannot check: " .. tostring(err)) return end
    print("Installed : " .. info.current)
    print("Latest    : " .. info.latest .. "  (" .. info.repo .. ")")
    print(info.available and "A new version is available. Run: nyxupdate install" or "You are up to date.")
elseif cmd == "install" then
    if not admin() then print("Permission denied: administrator or sudo needed.") return end
    local info, err = updater.check(true)
    if not info then print("Cannot check: " .. tostring(err)) return end
    if not info.available then print("You are up to date (" .. info.current .. ").") return end
    print("Updating " .. info.current .. " -> " .. info.latest .. " ...")
    local ok, e = updater.install(info.tag)
    if not ok then print("Update failed: " .. tostring(e)) print("Nothing was replaced.") end
elseif cmd == "status" then
    local c = updater.config()
    local s = updater.state()
    print("Repository : " .. c.repo)
    print("Auto check : " .. (c.auto and "on" or "off") .. ", every " .. c.interval .. " h")
    print("Installed  : " .. updater.currentVersion())
    print("Last seen  : " .. tostring(s.latest or "never checked"))
elseif cmd == "repo" then
    if not admin() then print("Permission denied: administrator or sudo needed.") return end
    if not args[2] or not args[2]:match("^[%w%-%._]+/[%w%-%._]+$") then print("Usage: nyxupdate repo <owner/name>") return end
    updater.setConfig("updateRepo", args[2])
    print("Repository set to " .. args[2])
elseif cmd == "auto" then
    if not admin() then print("Permission denied: administrator or sudo needed.") return end
    if args[2] ~= "on" and args[2] ~= "off" then print("Usage: nyxupdate auto <on|off>") return end
    updater.setConfig("autoUpdate", args[2] == "on")
    print("Automatic check " .. args[2])
elseif cmd == "interval" then
    if not admin() then print("Permission denied: administrator or sudo needed.") return end
    local h = tonumber(args[2])
    if not h or h < 1 or h > 720 then print("Usage: nyxupdate interval <hours 1-720>") return end
    updater.setConfig("updateInterval", math.floor(h))
    print("Interval set to " .. math.floor(h) .. " h")
else
    print("Usage: nyxupdate [check|install|status|repo <r>|auto <on|off>|interval <h>]")
end
