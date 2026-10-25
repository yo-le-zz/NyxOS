-- CCTchat - Base de donnees des utilisateurs (fichier serialise)

local M = {}
local DB_PATH = nil

function M.init(path)
    DB_PATH = path
    if not fs.exists(DB_PATH) then
        local f = fs.open(DB_PATH, "w")
        f.write(textutils.serialize({}))
        f.close()
    end
end

local function load()
    local f = fs.open(DB_PATH, "r")
    local data = f.readAll()
    f.close()
    return textutils.unserialize(data) or {}
end

local function save(t)
    local f = fs.open(DB_PATH, "w")
    f.write(textutils.serialize(t))
    f.close()
end

function M.userExists(user)
    local users = load()
    return users[user] ~= nil
end

function M.addUser(user, hash, salt)
    local users = load()
    users[user] = { hash = hash, salt = salt }
    save(users)
end

function M.getUser(user)
    local users = load()
    return users[user]
end

function M.getAllUsers()
    return load()
end

return M
