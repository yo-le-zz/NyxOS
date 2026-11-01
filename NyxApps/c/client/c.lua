-- C interpreter SKELETON for NyxOS: supports printf("literal\n") inside main only.
-- Contract: see docs/INTERPRETERS.md. Called as: c.lua <script.c> [args]
local args = { ... }
local f = fs.open(args[1], "r")
if not f then error("cannot open " .. tostring(args[1]), 0) end
local src = f.readAll() f.close()
if not src:find("main%s*%(") then error(args[1] .. ": no main()", 0) end
for lit in src:gmatch('printf%s*%(%s*"(.-)"%s*%)%s*;') do
    lit = lit:gsub("\\n", "\n"):gsub("\\t", "\t")
    write(lit)
end
