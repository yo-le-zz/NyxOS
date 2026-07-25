-- /bin/rm.lua : deletes files/folders
-- Usage: rm [-r|-R] [-f] [-i] <path...>
--   -r, -R   recursive (required to delete a folder)
--   -f       force: no confirmation, ignore missing files/missing -r
--   -i       interactive: ask before every single deletion
--
-- Safety: deleting a wildcard ("*") or several items at once always
-- asks for an explicit typed confirmation first, the same way `sudo`
-- asks for your password before anything destructive happens -- unless
-- -f was given.

local permissions = dofile("/lib/permissions.lua")
local nyxlib = dofile("/lib/nyxlib.lua")

local args = { ... }

local recursive, force, interactive = false, false, false
local targets = {}

for _, a in ipairs(args) do
    if a == "-r" or a == "-R" or a == "--recursive" then
        recursive = true
    elseif a == "-f" or a == "--force" then
        force = true
    elseif a == "-i" or a == "--interactive" then
        interactive = true
    elseif a == "-rf" or a == "-fr" then
        recursive = true
        force = true
    else
        table.insert(targets, a)
    end
end

if #targets == 0 then
    print("Usage: rm [-r] [-f] [-i] <path...>")
    return
end

-- Expands a single '*' wildcard within its own folder (same simple
-- matching as /bin/find.lua -- no full glob engine).
local function expand(pattern)
    if not pattern:find("*", 1, true) then
        return { pattern }
    end
    local dir = fs.getDir(shell.resolve(pattern))
    local namePattern = fs.getName(pattern)
    local escaped = namePattern:gsub("[%(%)%.%%%+%-%[%]%^%$%?]", "%%%1")
    local luaPattern = "^" .. escaped:gsub("%*", ".*") .. "$"
    local matches = {}
    if fs.exists(dir) and fs.isDir(dir) then
        for _, name in ipairs(fs.list(dir)) do
            if name:match(luaPattern) then
                table.insert(matches, fs.combine(dir, name))
            end
        end
    end
    return matches
end

local resolved = {}
local sawWildcard = false
for _, t in ipairs(targets) do
    if t:find("*", 1, true) then
        sawWildcard = true
    end
    for _, m in ipairs(expand(t)) do
        table.insert(resolved, shell.resolve(m))
    end
end

if #resolved == 0 then
    print("rm: no matching file.")
    return
end

-- Anything protected (root system folders) needs elevated privileges,
-- mirroring how a real system guards against wiping itself out.
local PROTECTED = { "/", "/bin", "/lib", "/etc", "/rom" }
local touchesProtected = false
for _, p in ipairs(resolved) do
    for _, prot in ipairs(PROTECTED) do
        if p == prot then touchesProtected = true end
    end
end
if touchesProtected then
    local ok, err = permissions.requirePrivileged("deleting a core system folder")
    if not ok then
        print(err)
        return
    end
end

-- Wildcards or multi-target deletes always ask for an explicit typed
-- confirmation, like sudo re-checking your password before anything
-- destructive -- skippable only with -f.
if not force and (sawWildcard or #resolved > 1) then
    print("This will delete " .. #resolved .. " item(s):")
    for _, p in ipairs(resolved) do
        print("  " .. p)
    end
    write("Type 'yes' to confirm: ")
    if read() ~= "yes" then
        print("Cancelled.")
        return
    end
end

local function removeOne(path)
    if not fs.exists(path) then
        if not force then
            print("rm: no such file: " .. path)
        end
        return
    end

    if fs.isDir(path) and not recursive then
        print("rm: '" .. path .. "' is a folder (use -r).")
        return
    end

    if interactive and not force then
        write("Delete " .. path .. "? (y/n) ")
        if read() ~= "y" then
            return
        end
    end

    fs.delete(path)
end

for _, path in ipairs(resolved) do
    removeOne(path)
end
