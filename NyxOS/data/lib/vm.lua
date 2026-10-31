-- /lib/vm.lua : virtual memory (swap)
--
-- CC:Tweaked computers have little RAM; programs that handle big data sets
-- can keep them on disk and only hold a few pages in memory:
--
--   local vm = dofile("/lib/vm.lua")
--   local h = vm.alloc(200000)              -- 200 000 bytes, zero filled, on disk
--   vm.write(h, 1, "hello")                 -- offsets are 1-based
--   print(vm.read(h, 1, 5))                 -- "hello"
--   vm.free(h)
--
--   vm.stats()  -> { blocks, bytes, limit, cached, cacheMax, hits, misses, pageSize, free }
--   vm.limit()  -> max swap bytes (a share of the free storage, see /lib/resources.lua)
--   vm.clean()  -> deletes every block (administrator)
--
-- Blocks live in /var/swap/<id>/<page>; a small LRU cache keeps recently
-- used pages in memory. Used by `free`, shown in Specs.

local vm = {}

local DIR = "/var/swap"
local PAGE = 2048

local state = _G.NYX_VM
if type(state) ~= "table" then
    state = { blocks = {}, cache = {}, order = {}, hits = 0, misses = 0, nextId = 1 }
    _G.NYX_VM = state
end

local function safeFree()
    local ok, v = pcall(fs.getFreeSpace, "/")
    return ok and tonumber(v) or 0
end

local function cacheMax()
    local ok, res = pcall(dofile, "/lib/resources.lua")
    if ok and type(res) == "table" then
        local okB, b = pcall(res.budget)
        if okB and type(b) == "table" and b.vmPages then return b.vmPages end
    end
    return 16
end

function vm.pageSize() return PAGE end

local function usedBytes()
    local n = 0
    for _, b in pairs(state.blocks) do n = n + b.size end
    return n
end

-- at most 40% of the storage that is free right now (and of what swap already uses)
function vm.limit()
    return math.floor((safeFree() + usedBytes()) * 0.4)
end

local function pagePath(id, page) return DIR .. "/" .. id .. "/" .. page end

local function touch(key)
    local order = state.order
    for i = #order, 1, -1 do
        if order[i] == key then table.remove(order, i) break end
    end
    order[#order + 1] = key
end

local function flush(key)
    local entry = state.cache[key]
    if not entry or not entry.dirty then return true end
    local id, page = key:match("^(%d+):(%d+)$")
    local f = fs.open(pagePath(id, page), "wb") or fs.open(pagePath(id, page), "w")
    if not f then return false end
    f.write(entry.data)
    f.close()
    entry.dirty = false
    return true
end

local function evict()
    local max = cacheMax()
    while #state.order > max do
        local key = table.remove(state.order, 1)
        flush(key)
        state.cache[key] = nil
    end
end

local function loadPage(id, page)
    local key = id .. ":" .. page
    local entry = state.cache[key]
    if entry then
        state.hits = state.hits + 1
        touch(key)
        return entry
    end
    state.misses = state.misses + 1
    local data
    local path = pagePath(id, page)
    if fs.exists(path) then
        local f = fs.open(path, "rb") or fs.open(path, "r")
        if f then data = f.readAll() f.close() end
    end
    data = data or string.rep("\0", PAGE)
    if #data < PAGE then data = data .. string.rep("\0", PAGE - #data) end
    entry = { data = data, dirty = false }
    state.cache[key] = entry
    touch(key)
    evict()
    return entry
end

-- Allocates a zero-filled block. Returns its handle, or nil + reason.
function vm.alloc(size)
    size = math.floor(tonumber(size) or 0)
    if size <= 0 then return nil, "size must be positive" end
    if usedBytes() + size > vm.limit() then return nil, "not enough storage for swap" end
    local id = state.nextId
    while fs.exists(DIR .. "/" .. id) do id = id + 1 end
    state.nextId = id + 1
    local ok, err = pcall(fs.makeDir, DIR .. "/" .. id)
    if not ok then return nil, tostring(err) end
    state.blocks[id] = { size = size }
    return id
end

function vm.size(h)
    local b = state.blocks[h]
    return b and b.size or nil
end

function vm.write(h, offset, data)
    local b = state.blocks[h]
    if not b then return false, "invalid handle" end
    data = tostring(data)
    offset = math.floor(tonumber(offset) or 1)
    if offset < 1 or offset + #data - 1 > b.size then return false, "out of range" end
    local pos = 1
    while pos <= #data do
        local abs = offset + pos - 2            -- 0-based position in the block
        local page = math.floor(abs / PAGE)
        local inPage = abs % PAGE
        local n = math.min(PAGE - inPage, #data - pos + 1)
        local entry = loadPage(h, page)
        entry.data = entry.data:sub(1, inPage) .. data:sub(pos, pos + n - 1) .. entry.data:sub(inPage + n + 1)
        entry.dirty = true
        pos = pos + n
    end
    return true
end

function vm.read(h, offset, len)
    local b = state.blocks[h]
    if not b then return nil, "invalid handle" end
    offset = math.floor(tonumber(offset) or 1)
    len = math.floor(tonumber(len) or 0)
    if offset < 1 or len < 0 or offset + len - 1 > b.size then return nil, "out of range" end
    local out, pos = {}, 0
    while pos < len do
        local abs = offset + pos - 1
        local page = math.floor(abs / PAGE)
        local inPage = abs % PAGE
        local n = math.min(PAGE - inPage, len - pos)
        out[#out + 1] = loadPage(h, page).data:sub(inPage + 1, inPage + n)
        pos = pos + n
    end
    return table.concat(out)
end

function vm.free(h)
    local b = state.blocks[h]
    if not b then return false end
    for key in pairs(state.cache) do
        if key:match("^" .. h .. ":") then
            state.cache[key] = nil
            for i = #state.order, 1, -1 do if state.order[i] == key then table.remove(state.order, i) end end
        end
    end
    pcall(fs.delete, DIR .. "/" .. h)
    state.blocks[h] = nil
    return true
end

-- Writes every modified page to the disk
function vm.sync()
    for key in pairs(state.cache) do flush(key) end
end

function vm.stats()
    local pages = 0
    for _ in pairs(state.cache) do pages = pages + 1 end
    local blocks = 0
    for _ in pairs(state.blocks) do blocks = blocks + 1 end
    return {
        blocks = blocks, bytes = usedBytes(), limit = vm.limit(), cached = pages,
        cacheMax = cacheMax(), hits = state.hits, misses = state.misses, pageSize = PAGE, free = safeFree(),
    }
end

function vm.clean()
    for h in pairs(state.blocks) do vm.free(h) end
    if fs.exists(DIR) then
        for _, name in ipairs(fs.list(DIR)) do pcall(fs.delete, DIR .. "/" .. name) end
    end
    state.cache, state.order = {}, {}
end

-- Leftover blocks of a previous boot are useless (handles are gone)
if not state.cleaned then
    state.cleaned = true
    if fs.exists(DIR) then
        for _, name in ipairs(fs.list(DIR)) do pcall(fs.delete, DIR .. "/" .. name) end
    end
end

return vm
