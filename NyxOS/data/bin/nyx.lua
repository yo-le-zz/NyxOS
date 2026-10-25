-- /bin/nyx.lua : runs a .nyx automation script
-- Usage: nyx <script.nyx> [args...]
-- See docs/NYX_SCRIPTING.md for the language reference.

-- /lib/nyxscript.lua is loaded with dofile() (global environment, where
-- `shell` is undefined): publish it so `shell` lines in scripts work.
if shell and not _G.shell then _G.shell = shell end

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
