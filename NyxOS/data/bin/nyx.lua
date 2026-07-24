-- /bin/nyx.lua : runs a .nyx automation script
-- Usage: nyx <script.nyx> [args...]
-- See docs/NYX_SCRIPTING.md for the language reference.

local nyxscript = dofile("/lib/nyxscript.lua")
local args = { ... }

local path = args[1]
if not path then
    print("Usage: nyx <script.nyx> [args...]")
    return
end

local scriptArgs = {}
for i = 2, #args do
    table.insert(scriptArgs, args[i])
end

local ok, result = nyxscript.runFile(path, scriptArgs)
if not ok then
    print("nyx: " .. tostring(result))
end
