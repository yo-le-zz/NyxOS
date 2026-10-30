-- /bin/ifconfig.lua : network interfaces and address
--   ifconfig                          shows the configuration
--   ifconfig static <ip> [mask] [gateway] [dns]
--   ifconfig dhcp                     ask a dhcpd for an address (reboot or: service restart netd)
--   ifconfig dns <ip> | gateway <ip> | mask <mask>
--   ifconfig forward <on|off>         forward packets between subnets (router)
--   ifconfig up | down
local net = dofile("/lib/netstack.lua")
local args = { ... }

local function admin()
    local ok, permissions = pcall(dofile, "/lib/permissions.lua")
    if not ok then return false end
    local good, why = permissions.requirePrivileged("changing the network configuration")
    if not good then print(why) end
    return good
end

local cmd = args[1]
if cmd == nil then
    local cfg = net.config()
    local ifaces = net.interfaces()
    print("Computer id : " .. os.getComputerID())
    print("Address     : " .. cfg.ip .. "  mask " .. cfg.mask .. "  (" .. cfg.mode .. (cfg.leased and ", leased" or "") .. ")")
    print("Gateway     : " .. (cfg.gateway or "-") .. "   DNS: " .. (cfg.dns or "-"))
    print("State       : " .. (cfg.up and "up" or "DOWN") .. (cfg.forward and ", forwarding" or ""))
    if cfg.server then print("Server file : " .. cfg.server) end
    if #ifaces == 0 then print("Interfaces  : no modem") end
    for _, i in ipairs(ifaces) do
        print("  " .. i.name .. "  " .. (i.wireless and "wireless" or "wired") .. "  " .. (i.open and "open" or "closed"))
    end
    local s = net.stats()
    print("Packets     : rx " .. s.rx .. "  tx " .. s.tx)
    return
end

if not admin() then return end

if cmd == "static" then
    if not net.isIp(args[2]) then print("Usage: ifconfig static <ip> [mask] [gateway] [dns]") return end
    net.setConfig("mode", "static")
    net.setConfig("ip", args[2])
    if args[3] then if net.isIp(args[3]) then net.setConfig("mask", args[3]) else print("bad mask") return end end
    if args[4] then if net.isIp(args[4]) then net.setConfig("gateway", args[4]) else print("bad gateway") return end end
    if args[5] then if net.isIp(args[5]) then net.setConfig("dns", args[5]) else print("bad dns") return end end
    net.up()
    print("Address " .. args[2] .. " set.")
elseif cmd == "dhcp" then
    net.setConfig("mode", "dhcp")
    print("DHCP mode set. Restart the network daemon: service restart netd")
elseif cmd == "dns" or cmd == "gateway" or cmd == "mask" then
    if not net.isIp(args[2]) then print("Usage: ifconfig " .. cmd .. " <ip>") return end
    net.setConfig(cmd, args[2])
    print(cmd .. " = " .. args[2])
elseif cmd == "forward" then
    if args[2] ~= "on" and args[2] ~= "off" then print("Usage: ifconfig forward <on|off>") return end
    net.setConfig("forward", args[2] == "on")
    print("Forwarding " .. args[2])
elseif cmd == "up" then
    net.setConfig("up", true) net.up() print("Network up.")
elseif cmd == "down" then
    net.setConfig("up", false) net.down() print("Network down.")
else
    print("Unknown option. See: man ifconfig")
end
