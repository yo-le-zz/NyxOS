-- /bin/service.lua : control NyxOS background services (daemons)
-- Usage:
--   service list
--   service status [name]
--   service enable <name>
--   service disable <name>
--   service logs <name>
--
-- Services actually start/stop as part of the boot scheduler (see
-- /lib/services.lua + /data/startup.lua) since CC:Tweaked has no real
-- background processes -- enabling a service takes effect on next boot.
-- "start"/"stop" here only affect the *current* uptime by nudging the
-- running scheduler's status table; a full effect always needs a reboot.

local services = dofile("/lib/services.lua")
local logger = dofile("/lib/logger.lua")
local permissions = dofile("/lib/permissions.lua")

local args = { ... }
local cmd = args[1]

local function usage()
    print("Usage:")
    print("  service list")
    print("  service status [name]")
    print("  service enable <name>")
    print("  service disable <name>")
    print("  service logs <name>")
end

if not cmd or cmd == "list" then
    local list = services.list()
    if #list == 0 then
        print("No services registered.")
        return
    end
    for _, def in ipairs(list) do
        local st = services.status(def.name)
        local auto = def.autostart and "enabled" or "disabled"
        print(string.format("%-16s %-9s %-8s %s", def.name, st.state, auto, def.description or ""))
    end
    return
end

if cmd == "status" then
    local name = args[2]
    if not name then
        for _, def in ipairs(services.list()) do
            local st = services.status(def.name)
            print(def.name .. ": " .. st.state .. (st.detail and (" (" .. tostring(st.detail) .. ")") or ""))
        end
        return
    end
    local def = services.find(name)
    if not def then
        print("Unknown service: " .. name)
        return
    end
    local st = services.status(name)
    print("Name        : " .. def.name)
    print("Description : " .. (def.description or ""))
    print("Exec        : " .. def.exec)
    print("Autostart   : " .. (def.autostart and "yes" or "no"))
    print("State       : " .. st.state)
    if st.detail then
        print("Detail      : " .. tostring(st.detail))
    end
    return
end

if cmd == "enable" or cmd == "disable" then
    local name = args[2]
    if not name then
        usage()
        return
    end
    local ok, err = permissions.requirePrivileged("managing services")
    if not ok then
        print(err)
        return
    end
    local ok2, err2 = services.setAutostart(name, cmd == "enable")
    if not ok2 then
        print(err2)
        return
    end
    logger.info("service", name .. " " .. cmd .. "d by current user")
    print("Service '" .. name .. "' " .. (cmd == "enable" and "enabled" or "disabled") ..
        " (takes effect on next boot).")
    return
end

if cmd == "logs" then
    local name = args[2]
    if not name then
        usage()
        return
    end
    local lines = logger.filterByTag("service")
    local found = false
    for _, line in ipairs(lines) do
        if line:find(name, 1, true) then
            print(line)
            found = true
        end
    end
    if not found then
        print("No log entries for '" .. name .. "'.")
    end
    return
end

usage()
