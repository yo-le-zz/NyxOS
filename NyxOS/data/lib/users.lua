-- /lib/users.lua : NyxOS multi-user management
--
-- /etc/passwd now contains a LIST of users:
--   { { username="alice", password="...", home="/home/alice", admin=true },
--     { username="bob",   password="",    home="/home/bob",   admin=false }, ... }
--
-- The old single-user format (one table with .username / .password /
-- .home directly) is automatically migrated to this new format on the
-- first read, to stay compatible with existing installs.
--
-- Passwords are now hashed with SHA-256 via the crypto module

local PASSWD_PATH = "/etc/passwd"
local crypto = dofile("/lib/crypto.lua")

local function loadTable(path)
    if not fs.exists(path) then
        return {}
    end
    local f = fs.open(path, "r")
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserialize, content)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

local function saveTable(path, data)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(data))
    f.close()
end

local users = {}

function users.load()
    local data = loadTable(PASSWD_PATH)
    if data.username then
        -- Old single-user format -> migrate to a list.
        data = { {
            username = data.username,
            password = data.password,
            home = data.home,
            admin = true,
        } }
        saveTable(PASSWD_PATH, data)
    end
    return data
end

function users.save(list)
    saveTable(PASSWD_PATH, list)
end

function users.find(name)
    for _, u in ipairs(users.load()) do
        if u.username == name then
            return u
        end
    end
    return nil
end

function users.checkPassword(name, password)
    local u = users.find(name)
    if not u then
        return false
    end
    if u.password == nil or u.password == "" then
        return true
    end
    -- Verify against hash (hardware or software-fallback SHA-256, 32 or 64 hex chars)
    if crypto.verifyPassword(password, u.password) then
        return true
    end
    -- Automatic migration: plaintext password -> hash
    if u.password == password then
        -- Hash and update the password
        local list = users.load()
        for _, user in ipairs(list) do
            if user.username == name then
                user.password = crypto.hash(password)
                users.save(list)
                break
            end
        end
        return true
    end
    return false
end

-- Creates a new user. admin=true makes them an administrator
-- (only administrators can create/delete users).
function users.add(name, password, admin)
    if not name or name == "" then
        return false, "Username cannot be empty."
    end
    local list = users.load()
    for _, u in ipairs(list) do
        if u.username == name then
            return false, "This user already exists."
        end
    end
    local home = "/home/" .. name
    if not fs.exists(home) then
        fs.makeDir(home)
    end
    -- Hash the password before storing it
    local hashedPassword = ""
    if password and password ~= "" then
        hashedPassword = crypto.hash(password)
    end
    table.insert(list, {
        username = name,
        password = hashedPassword,
        home = home,
        admin = admin and true or false,
    })
    users.save(list)
    return true
end

function users.remove(name)
    local list = users.load()
    local out, removed = {}, false
    for _, u in ipairs(list) do
        if u.username == name then
            removed = true
        else
            table.insert(out, u)
        end
    end
    if removed then
        users.save(out)
    end
    return removed
end

function users.setPassword(name, password)
    local list = users.load()
    for _, u in ipairs(list) do
        if u.username == name then
            -- Hash the password before storing it
            local hashedPassword = ""
            if password and password ~= "" then
                hashedPassword = crypto.hash(password)
            end
            u.password = hashedPassword
            users.save(list)
            return true
        end
    end
    return false
end

function users.setAdmin(name, admin)
    local list = users.load()
    for _, u in ipairs(list) do
        if u.username == name then
            u.admin = admin and true or false
            users.save(list)
            return true
        end
    end
    return false
end

function users.count()
    return #users.load()
end

-- Is there at least one other administrator besides `name`? (used to
-- avoid ending up with no admin at all after a deletion)
function users.hasOtherAdmin(name)
    for _, u in ipairs(users.load()) do
        if u.admin and u.username ~= name then
            return true
        end
    end
    return false
end

return users
