-- /lib/users.lua : gestion multi-utilisateurs de NyxOS
--
-- /etc/passwd contient desormais une LISTE d'utilisateurs :
--   { { username="alice", password="...", home="/home/alice", admin=true },
--     { username="bob",   password="",    home="/home/bob",   admin=false }, ... }
--
-- L'ancien format mono-utilisateur (une seule table avec .username /
-- .password / .home directement) est migre automatiquement vers ce
-- nouveau format des la premiere lecture, pour rester compatible avec
-- les installations existantes.
--
-- Les mots de passe sont maintenant hachés avec SHA-256 via le module crypto

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
        -- Ancien format mono-utilisateur -> migration vers une liste.
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
    -- Verification par hash (SHA-256 materiel ou fallback logiciel, 32 ou 64 hex)
    if crypto.verifyPassword(password, u.password) then
        return true
    end
    -- Migration automatique : mot de passe en clair -> hachage
    if u.password == password then
        -- Hache et met à jour le mot de passe
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

-- Cree un nouvel utilisateur. admin=true en fait un administrateur
-- (seuls les administrateurs peuvent creer/supprimer des utilisateurs).
function users.add(name, password, admin)
    if not name or name == "" then
        return false, "Le nom d'utilisateur ne peut pas etre vide."
    end
    local list = users.load()
    for _, u in ipairs(list) do
        if u.username == name then
            return false, "Cet utilisateur existe deja."
        end
    end
    local home = "/home/" .. name
    if not fs.exists(home) then
        fs.makeDir(home)
    end
    -- Hache le mot de passe avant de le stocker
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
            -- Hache le mot de passe avant de le stocker
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

-- Y a-t-il au moins un autre administrateur que `name` ? (utilise pour
-- empecher de se retrouver sans aucun admin apres une suppression)
function users.hasOtherAdmin(name)
    for _, u in ipairs(users.load()) do
        if u.admin and u.username ~= name then
            return true
        end
    end
    return false
end

return users
