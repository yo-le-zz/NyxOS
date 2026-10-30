-- Service dns: answers name queries (UDP port 53) from /etc/hosts.
-- Other computers use it by setting `dns` to this computer's address
-- (ifconfig dns <ip>) or find it automatically (it announces itself).
return function()
    local net = dofile("/lib/netstack.lua")
    local logger = dofile("/lib/logger.lua")
    net.up()
    pcall(rednet.host, net.DNS_PROTO, "dns")
    logger.info("dns", "name server ready on " .. net.myIp() .. ":53")
    while true do
        local p = net.receive(function(pkt) return pkt.proto == "udp" and pkt.dport == 53 and pkt.t == "query" end)
        if p then
            local name = tostring(p.name or ""):lower()
            local hosts = net.readHosts()
            local ip = hosts[name]
            if not ip and name == "localhost" then ip = net.myIp() end
            net.sendPacket(p.src, { proto = "udp", dport = p.sport, sport = 53, t = "answer", name = name, ip = ip })
        end
    end
end
