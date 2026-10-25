--[[
    Radio API module
    A small, stable scripting surface for controlling playback from any Lua
    script running on this client computer. Loaded as a global in client.lua:

        radio.play(id)
        radio.pause()
        radio.resume()
        radio.next()
        radio.queue(id)
        radio.getCurrent()
        radio.getPlaylist()

    `id` may be a bare song id (string) as returned by search results, or a
    full song_meta table {id=str, name=str, artist=str, duration=table}. When
    only an id is given, the client best-effort resolves it against locally
    known metadata (current search results, active song, queue); if nothing
    matches, a minimal meta stub is sent so the server can still queue it.
]]

local receiver = require("client_lib.receiver")

local M = {}

---@param id string|table
---@return table song_meta
local function resolve_meta(id)
    if type(id) == "table" then return id end

    if CSTATE.search_results then
        for _, meta in ipairs(CSTATE.search_results) do
            if meta.id == id then return meta end
        end
    end

    local active = CSTATE.server_state.active_song_meta
    if active and active.id == id then return active end

    for _, meta in ipairs(CSTATE.server_state.queue or {}) do
        if meta.id == id then return meta end
    end

    return { id = id, name = id, artist = "Unknown" } -- best-effort stub
end

---Play a song right now, interrupting whatever is currently playing.
---@param id string|table song id or song_meta
function M.play(id)
    receiver.send_server_queue(resolve_meta(id), "NOW")
end

---Pause playback (no-op if already paused).
function M.pause()
    if CSTATE.server_state.status == 1 then
        receiver.send_server_player("TOGGLE")
    end
end

---Resume playback (no-op if already playing).
function M.resume()
    if CSTATE.server_state.status ~= 1 then
        receiver.send_server_player("TOGGLE")
    end
end

---Skip to the next song in the queue.
function M.next()
    receiver.send_server_player("SKIP")
end

---Add a song to the end of the play queue.
---@param id string|table song id or song_meta
function M.queue(id)
    receiver.send_server_queue(resolve_meta(id), "ADD")
end

---@return table? song_meta the currently playing song, or nil if nothing is playing
function M.getCurrent()
    return CSTATE.server_state.active_song_meta
end

---@return table song_meta[] the current play queue (upcoming songs, not including the active one)
function M.getPlaylist()
    return CSTATE.server_state.queue
end

return M
