-- /bin/ps.lua : lists running processes
-- Usage: ps [-a]
--   ps      the shell, services and background jobs (things with a pid)
--   ps -a   also the parts of the system that are listed but have no
--           coroutine of their own (desktop, network, display...)
-- `jobs` shows only background jobs.

local services = dofile("/lib/services.lua")
local procui = dofile("/lib/procui.lua")

local args = { ... }
local all = args[1] == "-a"

if not services.scheduler() then
    print("ps: the scheduler is not running (boot NyxOS normally to use processes).")
    return
end

procui.print(procui.snapshot(all and "all" or "pid"))
