-- /bin/hosts.lua : the /etc/hosts name table
--   hosts                     lists it
--   hosts add <ip> <name>     adds / replaces a name (administrator)
--   hosts del <name>
local net = dofile("/lib/netstack.lua")
local args = { ... }
local map = net.readHosts()
if not args[1] then
    local names = {}
    for n in pairs(map) do names[#names + 1] = n end
    table.sort(names)
    print("127.0.0.1 localhost")
    for _, n in ipairs(names) do if n ~= "localhost" then print(map[n] .. " " .. n) end end
    return
end
local permissions = dofile("/lib/permissions.lua")
local good, why = permissions.requirePrivileged("editing /etc/hosts")
if not good then print(why) return end
if args[1] == "add" and net.isIp(args[2]) and args[3] and args[3]:match("^[%w%-%._]+$") then
    map[args[3]:lower()] = args[2]
    print(net.writeHosts(map) and "Added." or "Cannot write /etc/hosts")
elseif args[1] == "del" and args[2] then
    map[args[2]:lower()] = nil
    print(net.writeHosts(map) and "Removed." or "Cannot write /etc/hosts")
else
    print("Usage: hosts [add <ip> <name> | del <name>]")
end
