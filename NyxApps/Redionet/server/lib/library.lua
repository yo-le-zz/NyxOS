--[[
    Library module
    Manages playlists, favorites and play history.
    All state is persisted to disk (.redionet/*.json) so it survives
    server reboots/reloads.
]]

local M = {}

local DATA_DIR    = ".redionet"
local PLAYLISTS_FILE = DATA_DIR .. "/playlists.json"
local FAVORITES_FILE = DATA_DIR .. "/favorites.json"
local HISTORY_FILE   = DATA_DIR .. "/history.json"
local EXPORT_DIR     = DATA_DIR .. "/exports"

M.config = {
    max_history = 200,
}

M.playlists = {} -- { [name] = { items = {song_meta, ...}, created = epoch_ms } }
M.favorites = {} -- list of song_meta
M.history   = {} -- list of {id, name, artist, played_at}, most recent first


local function read_json(path, default)
    if not fs.exists(path) then return default end
    local handle = fs.open(path, "r")
    if not handle then return default end
    local raw = handle.readAll()
    handle.close()

    local ok, data = pcall(textutils.unserializeJSON, raw)
    if ok and data then return data end
    return default
end

local function write_json(path, data)
    if not fs.exists(DATA_DIR) then fs.makeDir(DATA_DIR) end
    local handle, err = fs.open(path, "w")
    if not handle then return false, err end
    handle.write(textutils.serializeJSON(data, { allow_repetitions = true }))
    handle.close()
    return true
end

---Load all persisted library data from disk. Call once on server startup.
function M.load()
    M.playlists = read_json(PLAYLISTS_FILE, {})
    M.favorites = read_json(FAVORITES_FILE, {})
    M.history   = read_json(HISTORY_FILE, {})
end

function M.save_playlists() write_json(PLAYLISTS_FILE, M.playlists) end
function M.save_favorites() write_json(FAVORITES_FILE, M.favorites) end
function M.save_history()   write_json(HISTORY_FILE, M.history) end


--[[ Playlists ]]

---@param name string
---@return boolean ok
---@return string? err one of: empty_name, already_exists
function M.playlist_create(name)
    if not name or name == "" then return false, "empty_name" end
    if M.playlists[name] then return false, "already_exists" end
    M.playlists[name] = { items = {}, created = os.epoch("utc") }
    M.save_playlists()
    return true
end

---@return boolean ok
---@return string? err one of: not_found, already_exists
function M.playlist_rename(old_name, new_name)
    if not (old_name and new_name) or new_name == "" then return false, "invalid_name" end
    if not M.playlists[old_name] then return false, "not_found" end
    if M.playlists[new_name] then return false, "already_exists" end
    M.playlists[new_name] = M.playlists[old_name]
    M.playlists[old_name] = nil
    M.save_playlists()
    return true
end

---@return boolean ok
---@return string? err one of: not_found
function M.playlist_delete(name)
    if not M.playlists[name] then return false, "not_found" end
    M.playlists[name] = nil
    M.save_playlists()
    return true
end

---@return boolean ok
---@return string? err one of: not_found, invalid_song
function M.playlist_add_song(name, song_meta)
    local pl = M.playlists[name]
    if not pl then return false, "not_found" end
    if not (song_meta and song_meta.id) then return false, "invalid_song" end
    table.insert(pl.items, song_meta)
    M.save_playlists()
    return true
end

---@return boolean ok
---@return string? err one of: not_found, song_not_found
function M.playlist_remove_song(name, song_id)
    local pl = M.playlists[name]
    if not pl then return false, "not_found" end
    for i, item in ipairs(pl.items) do
        if item.id == song_id then
            table.remove(pl.items, i)
            M.save_playlists()
            return true
        end
    end
    return false, "song_not_found"
end

---@return table[] list of {name, count, created}
function M.playlist_list()
    local out = {}
    for name, pl in pairs(M.playlists) do
        table.insert(out, { name = name, count = #pl.items, created = pl.created })
    end
    return out
end

---@return table? items list of song_meta, or nil if playlist doesn't exist
function M.playlist_get(name)
    local pl = M.playlists[name]
    return pl and pl.items or nil
end

---Serialize a playlist to a JSON string and write a copy to .redionet/exports/<name>.json
---@return string? json
---@return string? err one of: not_found
function M.playlist_export(name)
    local pl = M.playlists[name]
    if not pl then return nil, "not_found" end

    local json = textutils.serializeJSON({ name = name, items = pl.items }, { allow_repetitions = true })

    if not fs.exists(EXPORT_DIR) then fs.makeDir(EXPORT_DIR) end
    local handle = fs.open(EXPORT_DIR .. "/" .. name .. ".json", "w")
    if handle then
        handle.write(json)
        handle.close()
    end

    return json
end

---Import a playlist from a JSON string (as produced by playlist_export).
---@param name? string name to import as. Falls back to the name embedded in the JSON.
---@param json_str string
---@return boolean ok
---@return string? err one of: invalid_json, empty_name, already_exists
function M.playlist_import(name, json_str)
    local ok, data = pcall(textutils.unserializeJSON, json_str)
    if not ok or not data or not data.items then return false, "invalid_json" end

    name = (name and name ~= "" and name) or data.name
    if not name or name == "" then return false, "empty_name" end
    if M.playlists[name] then return false, "already_exists" end

    M.playlists[name] = { items = data.items, created = os.epoch("utc") }
    M.save_playlists()
    return true
end


--[[ Favorites ]]

local function favorite_index(song_id)
    for i, item in ipairs(M.favorites) do
        if item.id == song_id then return i end
    end
    return nil
end

---Add song_meta to favorites if absent, remove it if present.
---@return boolean ok
---@return boolean|string is_favorite true/false after toggling, or an err string if invalid_song
function M.favorite_toggle(song_meta)
    if not (song_meta and song_meta.id) then return false, "invalid_song" end

    local idx = favorite_index(song_meta.id)
    if idx then
        table.remove(M.favorites, idx)
        M.save_favorites()
        return true, false
    else
        table.insert(M.favorites, song_meta)
        M.save_favorites()
        return true, true
    end
end

function M.is_favorite(song_id)
    return favorite_index(song_id) ~= nil
end

function M.favorite_list()
    return M.favorites
end


--[[ History ]]

---Record a song as having started playing. Most recent first, capped at config.max_history.
function M.history_add(song_meta)
    if not (song_meta and song_meta.id) then return end

    table.insert(M.history, 1, {
        id = song_meta.id,
        name = song_meta.name,
        artist = song_meta.artist,
        played_at = os.epoch("utc"),
    })

    while #M.history > M.config.max_history do
        table.remove(M.history)
    end

    M.save_history()
end

function M.history_list()
    return M.history
end

function M.history_clear()
    M.history = {}
    M.save_history()
end

return M
