-- /bin/ping.lua : ping <host|address> [count]
local net = dofile("/lib/netstack.lua")
local host, count = ...
count = tonumber(count) or 4
if not host then print("Usage: ping <host|address> [count]") return end
local ip, via = net.resolveName(host)
if not ip then print("ping: " .. tostring(via)) return end
print("PING " .. host .. (ip ~= host and (" (" .. ip .. ")") or ""))
local ok, lost, total = 0, 0, 0
for i = 1, count do
    local ms, from = net.ping(ip, 2)
    if ms then
        ok = ok + 1 total = total + ms
        print(string.format("reply from %s: seq=%d time=%d ms", tostring(from), i, ms))
    else
        lost = lost + 1
        print("seq=" .. i .. ": " .. tostring(from))
    end
    if i < count then sleep(1) end
end
print(string.format("%d sent, %d received, %d lost%s", count, ok, lost, ok > 0 and string.format(", avg %d ms", total / ok) or ""))
