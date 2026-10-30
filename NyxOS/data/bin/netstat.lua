-- /bin/netstat.lua : listening ports, connections, counters
local net = dofile("/lib/netstack.lua")
local cfg = net.config()
print("Address " .. cfg.ip .. "  " .. (cfg.up and "up" or "DOWN"))
print("Listening:")
local l = net.listeners()
if #l == 0 then print("  (none)") end
for _, e in ipairs(l) do print(string.format("  %-6s %s", tostring(e.port), e.name)) end
print("Connections:")
local c = net.connections()
if #c == 0 then print("  (none)") end
for _, e in ipairs(c) do
    print(string.format("  %s:%s <-> %s:%s  %s  %ds", cfg.ip, tostring(e.port), e.peer, tostring(e.peerPort), e.role, math.floor((os.epoch("utc") - e.since) / 1000)))
end
local s = net.stats()
print("Packets: rx " .. s.rx .. "  tx " .. s.tx)
