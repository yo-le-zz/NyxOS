-- /bin/free.lua : memory, virtual memory (swap) and storage
--   free        summary      free -c   clean the swap (administrator)
local vm = dofile("/lib/vm.lua")
local args = { ... }
local function kb(n) return string.format("%d KB", math.floor((n or 0) / 1024 + 0.5)) end
if args[1] == "-c" then
    local good, why = dofile("/lib/permissions.lua").requirePrivileged("cleaning the swap")
    if not good then print(why) return end
    vm.clean()
    print("Swap cleaned.")
    return
end
local lua = collectgarbage and collectgarbage("count")
print(string.format("%-10s %s", "Lua heap:", lua and kb(lua * 1024) or "n/a"))
local s = vm.stats()
print(string.format("%-10s %s used / %s max   (%d block(s), %d B pages)", "Swap:", kb(s.bytes), kb(s.limit), s.blocks, s.pageSize))
print(string.format("%-10s %d/%d pages cached, %d hit(s), %d miss(es)", "Cache:", s.cached, s.cacheMax, s.hits, s.misses))
local cap = 0
pcall(function() cap = fs.getCapacity("/") or 0 end)
print(string.format("%-10s %s free%s", "Storage:", kb(s.free), cap > 0 and (" of " .. kb(cap)) or ""))
