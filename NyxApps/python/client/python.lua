-- Python interpreter SKELETON for NyxOS: supports print("literal") only.
-- Contract: see docs/INTERPRETERS.md. Called as: python.lua <script.py> [args]
local args = { ... }
local f = fs.open(args[1], "r")
if not f then error("cannot open " .. tostring(args[1]), 0) end
local n = 0
for line in f.readAll():gmatch("[^\n]*") do
    n = n + 1
    local s = line:match("^%s*print%s*%(%s*[\"'](.-)[\"']%s*%)%s*$")
    if s then print(s)
    elseif line:match("%S") and not line:match("^%s*#") then
        error(args[1] .. ":" .. n .. ": unsupported statement (skeleton interpreter)", 0)
    end
end
f.close()
