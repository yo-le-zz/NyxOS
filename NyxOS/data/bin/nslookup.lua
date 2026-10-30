-- /bin/nslookup.lua : nslookup <name>
local net = dofile("/lib/netstack.lua")
local name = ...
if not name then print("Usage: nslookup <name>") return end
local cfg = net.config()
print("DNS server: " .. (cfg.dns or "(none: /etc/hosts and discovery)"))
local ip, how = net.resolveName(name)
if ip then print(name .. " -> " .. ip .. "   [" .. tostring(how or "address") .. "]")
else print("nslookup: " .. tostring(how)) end
