-- /bin/net.lua : rednet helper commands
-- Usage:
--   net open                       opens every attached modem for rednet
--   net host <protocol> <name>      hosts a protocol under a friendly name
--   net discover <protocol>          looks up computers hosting a protocol
--   net send <id> <protocol> <msg>    sends a rednet message
--   net dhcp serve <name>            announces this computer via nyxnet.dhcp
--   net dhcp discover                 lists computers announced via nyxnet.dhcp

local network = dofile("/lib/network.lua")
local args = { ... }
local cmd = args[1]

if not peripheral or #peripheral.getNames() == 0 then
    -- Not fatal: openAllModems() below will just find nothing and
    -- rednet calls will report their own errors.
end

if cmd == "open" then
    local opened = network.openAllModems()
    if #opened == 0 then
        print("No modem found.")
    else
        print("Opened: " .. table.concat(opened, ", "))
    end
    return
end

if cmd == "host" and args[2] and args[3] then
    network.openAllModems()
    rednet.host(args[2], args[3])
    print("Hosting '" .. args[3] .. "' on protocol '" .. args[2] .. "'.")
    return
end

if cmd == "discover" and args[2] then
    network.openAllModems()
    local ids = { rednet.lookup(args[2]) }
    if #ids == 0 then
        print("No computer found for protocol '" .. args[2] .. "'.")
    else
        print(table.concat(ids, ", "))
    end
    return
end

if cmd == "send" and args[2] and args[3] and args[4] then
    network.openAllModems()
    rednet.send(tonumber(args[2]), args[4], args[3])
    print("Sent.")
    return
end

if cmd == "dhcp" and args[2] == "serve" then
    network.dhcpServe(args[3] or ("computer_" .. os.getComputerID()))
    print("Announcing via " .. network.DHCP_PROTOCOL .. " as '" .. (args[3] or "computer_" .. os.getComputerID()) .. "'.")
    return
end

if cmd == "dhcp" and args[2] == "discover" then
    local ids = network.dhcpDiscover()
    if #ids == 0 then
        print("No NyxOS computer announced.")
    else
        print(table.concat(ids, ", "))
    end
    return
end

print("Usage:")
print("  net open")
print("  net host <protocol> <name>")
print("  net discover <protocol>")
print("  net send <id> <protocol> <message>")
print("  net dhcp serve <name>")
print("  net dhcp discover")
