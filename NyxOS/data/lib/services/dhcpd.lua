-- Service dhcpd: leases addresses to computers in "dhcp" mode.
-- Pool in /etc/dhcpd.lua:  { subnet = "10.0.1", first = 100, last = 199,
--   mask = "255.255.255.0", gateway = "10.0.1.1", dns = "10.0.1.2" }
-- Leases are remembered per computer id in /var/run/dhcp-leases.lua.
return function()
    local net = dofile("/lib/netstack.lua")
    local logger = dofile("/lib/logger.lua")
    local function load(path)
        if not fs.exists(path) then return nil end
        local f = fs.open(path, "r") local s = f.readAll() f.close()
        local ok, t = pcall(textutils.unserialize, s)
        return ok and type(t) == "table" and t or nil
    end
    local pool = load("/etc/dhcpd.lua") or { subnet = "10.0.1", first = 100, last = 199 }
    local leases = load("/var/run/dhcp-leases.lua") or {}
    net.up()
    logger.info("dhcpd", string.format("pool %s.%d-%d", pool.subnet, pool.first, pool.last))
    while true do
        local sender, msg = rednet.receive(net.PROTO)
        if type(msg) == "table" and msg.proto == "udp" and msg.dport == 67 and msg.t == "discover" and msg.mac then
            local key = tostring(msg.mac)
            if not leases[key] then
                local used = {}
                for _, ip in pairs(leases) do used[ip] = true end
                for n = pool.first, pool.last do
                    local ip = pool.subnet .. "." .. n
                    if not used[ip] then leases[key] = ip break end
                end
                local f = fs.open("/var/run/dhcp-leases.lua", "w")
                if f then f.write(textutils.serialize(leases)) f.close() end
            end
            if leases[key] then
                rednet.send(sender, { v = 1, proto = "udp", dport = 68, src = net.myIp(), dst = "0.0.0.0", t = "offer", mac = msg.mac,
                    ip = leases[key], mask = pool.mask or net.DEFAULT_MASK, gateway = pool.gateway or net.myIp(), dns = pool.dns }, net.PROTO)
                logger.info("dhcpd", "lease " .. leases[key] .. " -> computer " .. key)
            else
                logger.warn("dhcpd", "pool exhausted for computer " .. key)
            end
        end
    end
end
