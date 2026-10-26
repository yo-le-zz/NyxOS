-- /bin/specs.lua : prints the machine specifications
-- Usage: specs

local specs = dofile("/lib/specs.lua")
for _, row in ipairs(specs.collect()) do
    print(string.format("%-14s %s", row[1] .. ":", row[2]))
end
