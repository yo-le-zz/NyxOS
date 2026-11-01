-- /bin/run.lua : runs a script with the interpreter registered for its extension
-- Usage: run <file.py|file.c|...> [args...]
local args = { ... }
if not args[1] then print("Usage: run <file> [args...]") return end
local interp = dofile("/lib/interpreters.lua")
interp.shell = shell
local file = table.remove(args, 1)
local ok, err = interp.run(shell.resolve(file), table.unpack(args))
if not ok and err then printError("run: " .. err) end
