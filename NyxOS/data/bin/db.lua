-- /bin/db.lua : inspect NyxOS mini-databases from the shell
-- Usage:
--   db list                        list databases
--   db tables <database>            list tables in a database
--   db dump <database> <table>       print every row (Lua-serialized)
--   db delete <database>             delete an entire database file

local db = dofile("/lib/db.lua")

local args = { ... }
local cmd = args[1]

local function usage()
    print("Usage:")
    print("  db list")
    print("  db tables <database>")
    print("  db dump <database> <table>")
    print("  db delete <database>")
end

if cmd == "list" then
    local names = db.list()
    if #names == 0 then
        print("No databases yet.")
        return
    end
    for _, name in ipairs(names) do
        print(name)
    end
    return
end

if cmd == "tables" and args[2] then
    local handle = db.open(args[2])
    local tables = handle:tables()
    if #tables == 0 then
        print("(no tables)")
        return
    end
    for _, t in ipairs(tables) do
        print(t .. " (" .. #handle:table(t) .. " row(s))")
    end
    return
end

if cmd == "dump" and args[2] and args[3] then
    local handle = db.open(args[2])
    local rows = handle:select(args[3])
    for _, row in ipairs(rows) do
        print(textutils.serialize(row))
    end
    return
end

if cmd == "delete" and args[2] then
    if db.delete(args[2]) then
        print("Database '" .. args[2] .. "' deleted.")
    else
        print("Unknown database: " .. args[2])
    end
    return
end

usage()
