-- /bin/players.lua : online players (needs an Advanced Peripherals player detector)
local list, err = dofile("/lib/periph.lua").players()
if not list then print("players: " .. tostring(err)) return end
if #list == 0 then print("Nobody online.") return end
print(#list .. " online: " .. table.concat(list, ", "))
