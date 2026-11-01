# Interpreter interface (NyxOS 1.8.0)

An interpreter is an `apt` package that adds a language (`.py`, `.c`, ...).

## Contract
1. The package installs a Lua program, e.g. `/lib/interp/python.lua`.
2. It registers itself: `dofile("/lib/nyxapi.lua").registerInterpreter("python", "py", "/lib/interp/python.lua")`
   (stored in `/etc/interpreters.lua`). The uninstaller calls `nyxapi.interpreters.unregister("python")`.
3. NyxOS runs `run script.py a b` as `shell.run("/lib/interp/python.lua", "/abs/script.py", "a", "b")`.
4. The interpreter pipeline: **parse** (source -> AST) -> **execute** (walk the AST) -> **system calls**
   translated to the NyxOS API (`print` -> `write`/`print`, file access -> `fs`, `input` -> `read`,
   network -> `nyxapi.network`/`http`). It must stay cooperative (yield through `os.pullEvent`) and
   return a normal Lua error (not terminate) on failure.
5. Commands: `run <file>`, `interpreters`, `interpreters add|remove`.

## Status
`python` and `c` packages (NyxApps/python, NyxApps/c) are **skeletons**: they implement only
`print(...)` / `printf(...)` of string literals to prove the pipeline. A real interpreter replaces
`/lib/interp/<name>.lua` without touching the rest.
