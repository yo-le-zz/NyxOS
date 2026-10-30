-- Service netd: brings the network up and answers ping, refuses closed
-- ports, forwards packets when /etc/network.lua says forward = true, asks
-- a DHCP server for an address in "dhcp" mode and starts the services a
-- /etc/servers/*.lua definition lists.
return function()
    local net = dofile("/lib/netstack.lua")
    local logger = dofile("/lib/logger.lua")
    local cfg = net.config()
    local lastIp
    local started = {}

    local function announce()
        cfg = net.config()
        local n = net.up()
        if cfg.ip ~= lastIp then
            logger.info("netd", string.format("%d modem(s), address %s (%s)", n, cfg.ip, cfg.mode))
            lastIp = cfg.ip
        end
    end

    local function dhcpLease()
        if cfg.mode ~= "dhcp" then return end
        if net.up() == 0 then return end
        -- broadcast a discover, the server answers directly
        rednet.broadcast({ v = 1, proto = "udp", dport = 67, src = "0.0.0.0", dst = "255.255.255.255", t = "discover", mac = os.getComputerID() }, net.PROTO)
        local deadline = os.epoch("utc") + 3000
        while os.epoch("utc") < deadline do
            local sender, msg = rednet.receive(net.PROTO, 1)
            if type(msg) == "table" and msg.proto == "udp" and msg.t == "offer" and msg.mac == os.getComputerID() then
                local f = fs.open("/var/run/net.lease", "w")
                if f then
                    f.write(textutils.serialize({ ip = msg.ip, mask = msg.mask, gateway = msg.gateway, dns = msg.dns, server = sender }))
                    f.close()
                end
                logger.info("netd", "DHCP lease " .. tostring(msg.ip) .. " from computer " .. tostring(sender))
                return
            end
        end
        logger.warn("netd", "no DHCP server answered (keeping the previous lease / default address)")
    end

    local function startListedServices()
        local ok, services = pcall(dofile, "/lib/services.lua")
        if not ok then return end
        for _, name in ipairs(cfg.services) do
            if not started[name] then
                local pid, err = services.start(name)
                if pid then
                    logger.info("netd", "started service " .. name)
                    started[name] = true
                elseif err and not tostring(err):find("already running") then
                    logger.warn("netd", "cannot start " .. name .. ": " .. tostring(err))
                else
                    started[name] = true
                end
            end
        end
    end

    dhcpLease()
    announce()
    startListedServices()

    local refresh = os.startTimer(30)
    while true do
        local ev, a, b, c = os.pullEvent()
        if ev == "rednet_message" and c == net.PROTO then
            local okH, errH = pcall(net.handleIncoming, a, b)
            if not okH then logger.warn("netd", "packet: " .. tostring(errH)) end
        elseif ev == "timer" and a == refresh then
            announce()
            refresh = os.startTimer(30)
        elseif ev == "peripheral" or ev == "peripheral_detach" then
            announce()
        end
    end
end
