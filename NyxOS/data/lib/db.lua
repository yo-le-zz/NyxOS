-- /lib/db.lua : small embedded database engine for NyxOS
--
-- Not a real relational DB -- a lightweight table-store in the spirit of
-- SQLite/Redis-for-CC: each "database" is a named collection of
-- "tables", each table a list of row-tables. Good enough for NyxApps
-- (chat logs, radio channel lists, turtle fleets...) that want
-- structured local storage without hand-rolling their own serialize/
-- deserialize logic.
--
-- On disk: /var/db/<database>.lua = { tableName = { row1, row2, ... }, ... }

local db = {}

local DB_DIR = "/var/db"

local function ensureDir()
    if not fs.exists(DB_DIR) then
        fs.makeDir(DB_DIR)
    end
end

local function path(name)
    return fs.combine(DB_DIR, name .. ".lua")
end

local Database = {}
Database.__index = Database

function db.open(name)
    ensureDir()
    local self = setmetatable({ name = name, path = path(name), data = {} }, Database)
    if fs.exists(self.path) then
        local f = fs.open(self.path, "r")
        local content = f.readAll()
        f.close()
        local ok, data = pcall(textutils.unserialize, content)
        if ok and type(data) == "table" then
            self.data = data
        end
    end
    return self
end

function Database:flush()
    local f = fs.open(self.path, "w")
    f.write(textutils.serialize(self.data))
    f.close()
end

function Database:table(tableName)
    if not self.data[tableName] then
        self.data[tableName] = {}
    end
    return self.data[tableName]
end

-- Appends a row (plain table) to `tableName`, auto-assigning a numeric
-- `id` field if the row doesn't already have one. Flushes to disk.
function Database:insert(tableName, row)
    local t = self:table(tableName)
    if row.id == nil then
        local maxId = 0
        for _, r in ipairs(t) do
            if type(r.id) == "number" and r.id > maxId then maxId = r.id end
        end
        row.id = maxId + 1
    end
    table.insert(t, row)
    self:flush()
    return row.id
end

-- Returns every row where `predicate(row)` is true (or all rows if
-- predicate is nil).
function Database:select(tableName, predicate)
    local t = self:table(tableName)
    if not predicate then
        return t
    end
    local out = {}
    for _, row in ipairs(t) do
        if predicate(row) then
            table.insert(out, row)
        end
    end
    return out
end

function Database:update(tableName, predicate, changes)
    local t = self:table(tableName)
    local count = 0
    for _, row in ipairs(t) do
        if predicate(row) then
            for k, v in pairs(changes) do
                row[k] = v
            end
            count = count + 1
        end
    end
    if count > 0 then self:flush() end
    return count
end

function Database:delete(tableName, predicate)
    local t = self:table(tableName)
    local kept = {}
    local removed = 0
    for _, row in ipairs(t) do
        if predicate(row) then
            removed = removed + 1
        else
            table.insert(kept, row)
        end
    end
    self.data[tableName] = kept
    if removed > 0 then self:flush() end
    return removed
end

function Database:tables()
    local names = {}
    for name in pairs(self.data) do table.insert(names, name) end
    table.sort(names)
    return names
end

function db.list()
    ensureDir()
    local names = {}
    for _, filename in ipairs(fs.list(DB_DIR)) do
        if filename:match("%.lua$") then
            table.insert(names, (filename:gsub("%.lua$", "")))
        end
    end
    table.sort(names)
    return names
end

function db.delete(name)
    local p = path(name)
    if fs.exists(p) then
        fs.delete(p)
        return true
    end
    return false
end

return db
