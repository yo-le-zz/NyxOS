-- /bin/profile.lua : shows or changes the computer profile
--   profile                 current profile
--   profile classic|tablet|server    changes it (applies at next boot)
--   profile detect          suggests a profile for this screen
local profile = dofile("/lib/profile.lua")
local arg = ({ ... })[1]
if not arg then
    print("Profile: " .. profile.current())
    for _, p in ipairs(profile.list) do print(string.format("  %-8s %s", p.id, p.description)) end
    print("Usage: profile classic|tablet|server|detect")
    return
end
if arg == "detect" then print("Suggested: " .. profile.detect()) return end
local good, why = dofile("/lib/permissions.lua").requirePrivileged("changing the profile")
if not good then print(why) return end
local ok, err = profile.set(arg)
if ok then print("Profile set to " .. arg .. ". Reboot to apply: reboot") else print("profile: " .. tostring(err)) end
