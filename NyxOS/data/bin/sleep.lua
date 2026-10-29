-- /bin/sleep.lua : wait N seconds (useful with background jobs: `sleep 60 &`)
--   sleep <seconds>      0 < seconds <= 86400, decimals allowed
local args = { ... }
local n = tonumber(args[1])
if not n or n < 0 or n ~= n or n == math.huge then
    print("Usage: sleep <seconds>")
    return
end
if n > 86400 then
    printError("sleep: maximum is 86400 seconds (24 h)")
    return
end
sleep(n)
