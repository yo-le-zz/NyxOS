-- /bin/jobs.lua : background jobs started with `command &` or `bg`
-- Usage: jobs            list them
--        jobs <pid>      show what job <pid> printed so far

local services = dofile("/lib/services.lua")
local procui = dofile("/lib/procui.lua")
local args = { ... }

if not services.scheduler() then
    print("jobs: the scheduler is not running.")
    return
end

if args[1] then
    local out = services.jobOutput(args[1])
    if out == nil then
        print("jobs: no running job with pid " .. tostring(args[1]))
    elseif out == "" then
        print("(no output yet)")
    else
        print(out)
    end
    return
end

local list = procui.snapshot("job")
if #list == 0 then
    print("No background jobs.")
else
    procui.print(list)
end
