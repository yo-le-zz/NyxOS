-- /bin/reset.lua : removes every package installed on top of the base
-- NyxOS system (everything tracked by apt), restoring a clean base
-- install without wiping users/config/screen setup.
-- Usage: reset [--yes]

local nyxlib = dofile("/lib/nyxlib.lua")
local permissions = dofile("/lib/permissions.lua")
local logger = dofile("/lib/logger.lua")

local args = { ... }

local ok, err = permissions.requirePrivileged("resetting installed packages")
if not ok then
    print(err)
    return
end

local manifest = nyxlib.loadManifest()
local names = {}
for name in pairs(manifest) do
    table.insert(names, name)
end
table.sort(names)

if #names == 0 then
    print("Nothing to reset: no extra packages are installed.")
    return
end

print("The following packages will be completely removed:")
for _, name in ipairs(names) do
    print("  - " .. name)
end

if args[1] ~= "--yes" then
    write("Continue? (type 'yes' to confirm): ")
    local answer = read()
    if answer ~= "yes" then
        print("Reset cancelled.")
        return
    end
end

local removed = 0
for _, name in ipairs(names) do
    print("Purging " .. name .. " ...")
    if shell.run("apt", "purge", name, "--yes") then
        removed = removed + 1
    end
end

logger.info("apt", "reset: purged " .. removed .. "/" .. #names .. " package(s)")
print("Reset complete: " .. removed .. "/" .. #names .. " package(s) removed.")
