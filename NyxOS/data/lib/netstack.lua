-- /lib/netstack.lua : NyxOS virtual network on top of rednet
--
-- rednet only knows computer ids. NyxOS adds a small IP-like layer:
--
--   * every computer has an address ("10.0.0.5"): static (default derived
--     from the computer id, or set in /etc/network.lua) or leased by a
--     `dhcpd` service;
--   * names: /etc/hosts, then a `dns` service (see /lib/services/dns.lua);
--   * datagrams (udp), echo (icmp: ping) and simple connections (tcp-like
--     sockets with ports), all carried by rednet messages;
--   * a computer with `forward = true` and a gateway role forwards packets
--     for other subnets.
--
-- The `netd` service (autostart) answers ping and forwards packets.
--
--   local net = dofile("/lib/netstack.lua")
--   net.up()                               -- open modems, announce our address
--   local conn = net.connect("server1", 22)  -- name or address
--   conn:send({ hello = "world" })
--   local data = conn:receive(5)
--   conn:close()
--
--   local l = net.listen(22)
--   local c = l:accept(10)                 -- a connection, or nil on timeout
--
-- Messages are Lua values (tables included). Nothing is encrypted: do not
-- send secrets in clear (the ssh package authenticates with a challenge).

local net = {}

net.PROTO = "nyxnet.ip"
net.DNS_PROTO = "nyxnet.dns"
net.CONFIG = "/etc/network.lua"
net.HOSTS = "/etc/hosts"
net.SERVERS_DIR = "/etc/servers"
net.DEFAULT_MASK = "255.255.255.0"

-- state shared by every program of this computer (they all inherit _G)
_G.__nyxnet = _G.__nyxnet or { rx = 0, tx = 0, listeners = {}, conns = {}, cache = {}, hosted = nil }
local state = _G.__nyxnet

------------------------------------------------------------------
-- small helpers
------------------------------------------------------------------

local function loadTable(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local content = f.readAll()
    f.close()
    -- data files are written with textutils.serialize ({...}); packs are
    -- Lua chunks ("return {...}"): accept both
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then return data end
    local fn = load(content, path, "t", {})
    if fn then
        local ok2, res = pcall(fn)
        if ok2 and type(res) == "table" then return res end
    end
    return nil
end

local function saveTable(path, data)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = fs.open(path, "w")
    if not f then return false end
    f.write(textutils.serialize(data))
    f.close()
    return true
end

function net.isIp(text)
    if type(text) ~= "string" then return false end
    local a, b, c, d = text:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    if not a then return false end
    for _, n in ipairs({ a, b, c, d }) do
        if tonumber(n) > 255 then return false end
    end
    return true
end

local function ipToNumber(ip)
    local a, b, c, d = ip:match("^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
    return ((tonumber(a) * 256 + tonumber(b)) * 256 + tonumber(c)) * 256 + tonumber(d)
end

function net.sameSubnet(a, b, mask)
    if not (net.isIp(a) and net.isIp(b) and net.isIp(mask or net.DEFAULT_MASK)) then return false end
    local m = ipToNumber(mask or net.DEFAULT_MASK)
    -- (a & m) == (b & m), without bit operators (Lua 5.1)
    local x, y = ipToNumber(a), ipToNumber(b)
    local function band(p, q)
        local r, bit = 0, 1
        while p > 0 and q > 0 do
            if p % 2 == 1 and q % 2 == 1 then r = r + bit end
            p, q, bit = math.floor(p / 2), math.floor(q / 2), bit * 2
        end
        return r
    end
    return band(x, m) == band(y, m)
end

-- Default address derived from a computer id: 10.0.<id div 254>.<id mod 254 + 1>
function net.defaultIp(id)
    id = id or os.getComputerID()
    return string.format("10.0.%d.%d", math.floor(id / 254) % 256, id % 254 + 1)
end

------------------------------------------------------------------
-- configuration
------------------------------------------------------------------

-- Merged configuration: /etc/network.lua, then the first /etc/servers/*.lua
-- (server definition: ip, mask, gateway, dns, ports, services), then a
-- DHCP lease if the mode is "dhcp".
function net.config()
    local cfg = loadTable(net.CONFIG) or {}
    local out = {
        mode = cfg.mode == "dhcp" and "dhcp" or "static",
        ip = cfg.ip, mask = cfg.mask or net.DEFAULT_MASK,
        gateway = cfg.gateway, dns = cfg.dns,
        up = cfg.up ~= false, forward = cfg.forward == true,
        ports = {}, services = {},
    }
    if fs.exists(net.SERVERS_DIR) and fs.isDir(net.SERVERS_DIR) then
        local names = fs.list(net.SERVERS_DIR)
        table.sort(names)
        for _, file in ipairs(names) do
            if file:match("%.lua$") then
                local def = loadTable(fs.combine(net.SERVERS_DIR, file))
                if def then
                    out.server = def.name or file:gsub("%.lua$", "")
                    out.ip = def.ip or out.ip
                    out.mask = def.mask or out.mask
                    out.gateway = def.gateway or out.gateway
                    out.dns = def.dns or out.dns
                    if def.forward ~= nil then out.forward = def.forward and true or false end
                    for port, name in pairs(def.ports or {}) do out.ports[tonumber(port) or port] = name end
                    for _, svc in ipairs(def.services or {}) do table.insert(out.services, svc) end
                    break
                end
            end
        end
    end
    if out.mode == "dhcp" then
        local lease = loadTable("/var/run/net.lease")
        if lease and lease.ip then
            out.ip = lease.ip
            out.mask = lease.mask or out.mask
            out.gateway = lease.gateway or out.gateway
            out.dns = lease.dns or out.dns
            out.leased = true
        end
    end
    out.ip = out.ip or net.defaultIp()
    return out
end

-- Changes /etc/network.lua (key = value, nil removes the key)
function net.setConfig(key, value)
    local cfg = loadTable(net.CONFIG) or {}
    cfg[key] = value
    return saveTable(net.CONFIG, cfg)
end

function net.myIp() return net.config().ip end

------------------------------------------------------------------
-- interfaces
------------------------------------------------------------------

function net.interfaces()
    local list = {}
    if peripheral and peripheral.getNames then
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.getType(name) == "modem" then
                local wireless = false
                pcall(function() wireless = peripheral.call(name, "isWireless") and true or false end)
                local open = false
                pcall(function() open = rednet.isOpen(name) end)
                table.insert(list, { name = name, wireless = wireless, open = open })
            end
        end
    end
    return list
end

-- Opens every modem and announces our address. Returns number of modems.
function net.up()
    local n = 0
    for _, iface in ipairs(net.interfaces()) do
        if not iface.open then pcall(rednet.open, iface.name) end
        n = n + 1
    end
    local cfg = net.config()
    if n > 0 and cfg.up then
        if state.hosted ~= cfg.ip then
            if state.hosted then pcall(rednet.unhost, net.PROTO) end
            local ok = pcall(rednet.host, net.PROTO, cfg.ip)
            if ok then state.hosted = cfg.ip end
        end
    end
    return n
end

function net.down()
    if state.hosted then pcall(rednet.unhost, net.PROTO) state.hosted = nil end
    for _, iface in ipairs(net.interfaces()) do
        if iface.open then pcall(rednet.close, iface.name) end
    end
end

------------------------------------------------------------------
-- names and addresses
------------------------------------------------------------------

function net.readHosts()
    local out = {}
    if fs.exists(net.HOSTS) and not fs.isDir(net.HOSTS) then
        local f = fs.open(net.HOSTS, "r")
        while true do
            local line = f.readLine()
            if not line then break end
            line = line:gsub("#.*$", "")
            local ip, names = line:match("^%s*(%d+%.%d+%.%d+%.%d+)%s+(.-)%s*$")
            if ip and names ~= "" then
                for name in names:gmatch("%S+") do out[name:lower()] = ip end
            end
        end
        f.close()
    end
    return out
end

function net.writeHosts(map)
    local names = {}
    for name in pairs(map) do names[#names + 1] = name end
    table.sort(names)
    local f = fs.open(net.HOSTS, "w")
    if not f then return false end
    f.write("# NyxOS hosts: <address> <name>\n127.0.0.1 localhost\n")
    for _, name in ipairs(names) do
        if name ~= "localhost" then f.write(map[name] .. " " .. name .. "\n") end
    end
    f.close()
    return true
end

-- Resolves a name (or returns the address if it already is one).
function net.resolveName(name, timeout)
    if net.isIp(name) then return name end
    name = tostring(name):lower()
    if name == "localhost" then return net.myIp() end
    local ok, nyxlib = pcall(dofile, "/lib/nyxlib.lua")
    if ok and nyxlib.getHostname and name == tostring(nyxlib.getHostname()):lower() then return net.myIp() end
    local hosts = net.readHosts()
    if hosts[name] then return hosts[name], "hosts" end

    local cfg = net.config()
    local dnsIp = cfg.dns
    if not dnsIp then
        -- discover a DNS server on the network
        local id = rednet.lookup and rednet.lookup(net.DNS_PROTO) or nil
        if id then dnsIp = net.defaultIp(id) end
    end
    if dnsIp then
        local reply = net.request(dnsIp, 53, { t = "query", name = name }, timeout or 2)
        if reply and reply.t == "answer" and reply.ip then return reply.ip, "dns " .. dnsIp end
    end
    return nil, "unknown host " .. name
end

-- Computer id of an address (looked up on the network, cached 60 s)
function net.resolveId(ip, timeout)
    if ip == net.myIp() or ip == "127.0.0.1" then return os.getComputerID() end
    local c = state.cache[ip]
    local now = os.epoch("utc")
    if c and now - c.at < 60000 then return c.id end
    net.up()
    local id = rednet.lookup(net.PROTO, ip)
    if id then state.cache[ip] = { id = id, at = now } end
    return id
end

------------------------------------------------------------------
-- packets
------------------------------------------------------------------

-- Which computer do we hand the packet to? Same subnet: the destination
-- itself; otherwise the gateway.
local function nextHop(dst, cfg)
    if net.sameSubnet(cfg.ip, dst, cfg.mask) or not cfg.gateway then return dst end
    return cfg.gateway
end

-- Sends one packet. `pkt` fields: proto ("udp"|"tcp"|"icmp"), dport, sport,
-- anything else is payload. Returns true, or nil + error.
function net.sendPacket(dst, pkt)
    local cfg = net.config()
    if not cfg.up then return nil, "network is down" end
    if net.up() == 0 then return nil, "no modem" end
    pkt.v = 1
    pkt.src = cfg.ip
    pkt.dst = dst
    pkt.ttl = pkt.ttl or 8
    local hop = nextHop(dst, cfg)
    local id = net.resolveId(hop)
    if not id then return nil, "host unreachable (" .. tostring(hop) .. ")" end
    state.tx = state.tx + 1
    rednet.send(id, pkt, net.PROTO)
    return true
end

-- Waits for a packet accepted by `filter(pkt, senderId)`; nil on timeout.
-- Packets for another address are ignored here (netd forwards them).
function net.receive(filter, timeout)
    local deadline = timeout and (os.epoch("utc") + timeout * 1000) or nil
    while true do
        local remaining
        if deadline then
            remaining = (deadline - os.epoch("utc")) / 1000
            if remaining <= 0 then return nil end
        end
        local sender, msg = rednet.receive(net.PROTO, remaining)
        if not sender then return nil end
        if type(msg) == "table" and msg.v == 1 and msg.dst == net.myIp() then
            state.rx = state.rx + 1
            if not filter or filter(msg, sender) then return msg, sender end
        end
    end
end

-- One datagram out, one reply back (used by dns, ping...). Returns reply.
function net.request(dst, port, payload, timeout)
    local sport = 49152 + math.random(0, 16000)
    payload.proto = "udp"
    payload.dport = port
    payload.sport = sport
    local ok = net.sendPacket(dst, payload)
    if not ok then return nil end
    return net.receive(function(p) return p.proto == "udp" and p.dport == sport and p.src == dst end, timeout or 2)
end

-- Echo request. Returns round-trip time in ms, or nil + error.
function net.ping(host, timeout)
    local ip, why = net.resolveName(host)
    if not ip then return nil, why end
    local seq = math.random(1, 65535)
    local started = os.epoch("utc")
    local ok, err = net.sendPacket(ip, { proto = "icmp", t = "echo", seq = seq })
    if not ok then return nil, err end
    local reply = net.receive(function(p) return p.proto == "icmp" and p.t == "reply" and p.seq == seq end, timeout or 2)
    if not reply then return nil, "timeout" end
    return os.epoch("utc") - started, reply.src, ip
end

------------------------------------------------------------------
-- sockets
------------------------------------------------------------------

local Conn = {}
Conn.__index = Conn

local function newCid() return os.getComputerID() * 100000 + math.random(1, 99999) end

function Conn:send(data)
    if self.closed then return nil, "closed" end
    return net.sendPacket(self.peer, { proto = "tcp", t = "data", cid = self.cid, dport = self.peerPort, sport = self.port, data = data })
end

function Conn:receive(timeout)
    if self.closed then return nil, "closed" end
    local p = net.receive(function(pkt)
        return pkt.proto == "tcp" and pkt.cid == self.cid and pkt.src == self.peer and pkt.dport == self.port
    end, timeout)
    if not p then return nil, "timeout" end
    if p.t == "fin" then
        self.closed = true
        state.conns[self.cid] = nil
        return nil, "closed"
    end
    return p.data
end

function Conn:close()
    if self.closed then return end
    self.closed = true
    state.conns[self.cid] = nil
    net.sendPacket(self.peer, { proto = "tcp", t = "fin", cid = self.cid, dport = self.peerPort, sport = self.port })
end

-- Opens a connection to name/address:port. Returns conn, or nil + error.
function net.connect(host, port, timeout)
    local ip, why = net.resolveName(host)
    if not ip then return nil, why end
    local cid = newCid()
    local sport = 49152 + math.random(0, 16000)
    local ok, err = net.sendPacket(ip, { proto = "tcp", t = "syn", cid = cid, dport = port, sport = sport })
    if not ok then return nil, err end
    local p = net.receive(function(pkt)
        return pkt.proto == "tcp" and pkt.cid == cid and pkt.src == ip and (pkt.t == "synack" or pkt.t == "rst")
    end, timeout or 3)
    if not p then return nil, "connection timed out" end
    if p.t == "rst" then return nil, "connection refused" end
    local conn = setmetatable({ peer = ip, peerPort = port, port = sport, cid = cid }, Conn)
    state.conns[cid] = { peer = ip, peerPort = port, port = sport, since = os.epoch("utc"), role = "client" }
    return conn
end

local Listener = {}
Listener.__index = Listener

-- Waits for a client. Returns conn (with .peer = client address), or nil.
function Listener:accept(timeout)
    local p = net.receive(function(pkt) return pkt.proto == "tcp" and pkt.t == "syn" and pkt.dport == self.port end, timeout)
    if not p then return nil end
    net.sendPacket(p.src, { proto = "tcp", t = "synack", cid = p.cid, dport = p.sport, sport = self.port })
    local conn = setmetatable({ peer = p.src, peerPort = p.sport, port = self.port, cid = p.cid }, Conn)
    state.conns[p.cid] = { peer = p.src, peerPort = p.sport, port = self.port, since = os.epoch("utc"), role = "server" }
    return conn
end

function Listener:close() state.listeners[self.port] = nil end

function net.listen(port, name)
    state.listeners[port] = name or "?"
    return setmetatable({ port = port }, Listener)
end

-- For netstat
function net.listeners()
    local out = {}
    for port, name in pairs(state.listeners) do out[#out + 1] = { port = port, name = name } end
    for port, name in pairs(net.config().ports) do
        local dup = false
        for _, l in ipairs(out) do if l.port == port then dup = true end end
        if not dup then out[#out + 1] = { port = port, name = tostring(name) .. " (declared)" } end
    end
    table.sort(out, function(a, b) return tostring(a.port) < tostring(b.port) end)
    return out
end

function net.connections()
    local out = {}
    for cid, c in pairs(state.conns) do out[#out + 1] = c end
    return out
end

function net.stats() return { rx = state.rx, tx = state.tx } end

------------------------------------------------------------------
-- daemon work (called by the netd service)
------------------------------------------------------------------

-- Handles one rednet packet received by netd: answers echo, forwards.
function net.handleIncoming(sender, msg)
    if type(msg) ~= "table" or msg.v ~= 1 then return end
    local cfg = net.config()
    if msg.dst == cfg.ip then
        if msg.proto == "icmp" and msg.t == "echo" then
            net.sendPacket(msg.src, { proto = "icmp", t = "reply", seq = msg.seq })
        elseif msg.proto == "tcp" and msg.t == "syn" and not state.listeners[msg.dport] and not cfg.ports[msg.dport] then
            net.sendPacket(msg.src, { proto = "tcp", t = "rst", cid = msg.cid, dport = msg.sport, sport = msg.dport })
        end
        return
    end
    if cfg.forward and (msg.ttl or 0) > 1 then
        msg.ttl = msg.ttl - 1
        local id = net.resolveId(msg.dst)
        if id then rednet.send(id, msg, net.PROTO) end
    end
end

return net
