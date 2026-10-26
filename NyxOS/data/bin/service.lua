-- /bin/service.lua : control NyxOS background services (daemons)
-- Usage:
--   service list
--   service status [name]
--   service enable <name>
--   service disable <name>
--   service logs <name>
--   service start <name>       start it now (no reboot needed)
--   service stop <name>        stop it now
--   service restart <name>
--   service add <name> <program> [description]
--                              register a program as an autostart service
--   service remove <name>      forget a service
--
-- Services actually start/stop as part of the boot scheduler (see
-- /lib/services.lua + /data/startup.lua (installed as /nyxos.lua)) since CC:Tweaked has no real
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
    print("  service start|stop|restart <name>")
    print("  service add <name> <program> [description]")
    print("  service remove <name>")
end

local function pidOf(name)
    for _, p in ipairs(services.processes()) do
        if p.kind == "service" and p.name == name then return p.pid end
    end
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
    print("Exec        : " .. tostring(def.program or def.exec))
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

if cmd == "start" or cmd == "stop" or cmd == "restart" then
    local name = args[2]
    if not name then usage() return end
    local ok, err = permissions.requirePrivileged("managing services")
    if not ok then print(err) return end
    if not services.find(name) then print("Unknown service: " .. name) return end
    if cmd == "stop" or cmd == "restart" then
        local pid = pidOf(name)
        if pid then
            services.kill(pid)
            print("Service '" .. name .. "' stopped.")
        elseif cmd == "stop" then
            print("Service '" .. name .. "' is not running.")
        end
    end
    if cmd == "start" or cmd == "restart" then
        local pid, serr = services.start(name)
        if pid then
            print("Service '" .. name .. "' started (pid " .. pid .. ").")
            logger.info("service", name .. " " .. cmd .. "ed")
        else
            print(serr)
        end
    end
    return
end

if cmd == "add" then
    local name, program = args[2], args[3]
    if not name or not program then usage() return end
    local ok, err = permissions.requirePrivileged("registering services")
    if not ok then print(err) return end
    local path = shell.resolve(program)
    if not fs.exists(path) then print("No such file: " .. path) return end
    local description = table.concat(args, " ", 4)
    local okReg, regErr = services.register({
        name = name, program = path, description = description, autostart = true,
    })
    if okReg then
        print("Service '" .. name .. "' registered (autostart). Start it now: service start " .. name)
    else
        print(regErr)
    end
    return
end

if cmd == "remove" then
    local name = args[2]
    if not name then usage() return end
    local ok, err = permissions.requirePrivileged("removing services")
    if not ok then print(err) return end
    local pid = pidOf(name)
    if pid then services.kill(pid) end
    print(services.unregister(name) and ("Service '" .. name .. "' removed.") or ("Unknown service: " .. name))
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
