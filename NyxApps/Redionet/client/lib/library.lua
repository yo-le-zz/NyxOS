--[[
    Client library module
    Thin request/reply wrapper around PROTO_SERVER_LIBRARY, for managing
    playlists, favorites and history from any script running on this client
    (shell, custom programs, or the UI itself).

    Usage example, from a `lua` shell on the client computer:
        local library = require("lib.library")
        library.playlist_create("chill")
        library.playlist_add("chill", radio.getCurrent())
        library.playlist_play("chill")
]]

local M = {}

local REPLY_TIMEOUT = 3 -- seconds

---Send a library request and block waiting for its reply.
---@return table? reply nil on timeout
local function request(code, payload)
    rednet.send(SERVER_ID, { code, payload }, "PROTO_SERVER_LIBRARY")
    local _, reply = rednet.receive("PROTO_SERVER_LIBRARY:REPLY", REPLY_TIMEOUT)
    return reply
end


--[[ Playlists ]]

function M.playlist_create(name)         return request("PLAYLIST_CREATE", name) end
function M.playlist_rename(old, new)     return request("PLAYLIST_RENAME", { old, new }) end
function M.playlist_delete(name)         return request("PLAYLIST_DELETE", name) end
function M.playlist_add(name, song_meta) return request("PLAYLIST_ADD", { name, song_meta }) end
function M.playlist_remove(name, id)     return request("PLAYLIST_REMOVE", { name, id }) end
function M.playlist_list()               return request("PLAYLIST_LIST") end
function M.playlist_get(name)            return request("PLAYLIST_GET", name) end
function M.playlist_export(name)         return request("PLAYLIST_EXPORT", name) end
function M.playlist_import(name, json)   return request("PLAYLIST_IMPORT", { name, json }) end

---Load a playlist into the server queue and start playing it immediately.
function M.playlist_play(name)
    rednet.send(SERVER_ID, { "PLAYLIST_PLAY", name }, "PROTO_SERVER_LIBRARY")
    os.queueEvent('redionet:sync_state')
end


--[[ Favorites ]]

function M.favorite_toggle(song_meta) return request("FAVORITE_TOGGLE", song_meta) end
function M.favorite_list()            return request("FAVORITE_LIST") end


--[[ History ]]

function M.history_list()  return request("HISTORY_LIST") end
function M.history_clear() return request("HISTORY_CLEAR") end


--[[ Shuffle ]]

---@param enabled boolean
function M.shuffle_set(enabled)
    rednet.send(SERVER_ID, { "SHUFFLE", enabled }, "PROTO_SERVER_PLAYER")
    os.queueEvent('redionet:sync_state')
end

return M
