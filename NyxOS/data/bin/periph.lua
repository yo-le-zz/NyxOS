-- /bin/periph.lua : lists attached peripherals (CC:Tweaked, Advanced and Classic Peripherals)
-- Usage: periph | periph info <name>
local periph = dofile("/lib/periph.lua")
local a = { ... }
if a[1] == "info" and a[2] then
    if not peripheral.isPresent(a[2]) then print("No peripheral named " .. a[2]) return end
    for _, p in ipairs(periph.scan()) do
        if p.name == a[2] then
            print(p.label .. " (" .. p.type .. ") - " .. p.pack)
            print(p.hint)
        end
    end
    local m = periph.methods(a[2])
    print(#m .. " method(s):")
    print(table.concat(m, ", "))
    return
end
local list = periph.scan()
if #list == 0 then print("No peripheral attached.") return end
for _, p in ipairs(list) do
    print(string.format("%-18s %-26s %s", p.name, p.label, p.pack))
end
