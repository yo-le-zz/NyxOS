-- /lib/periph.lua : peripheral catalogue (CC:Tweaked, Advanced Peripherals, Classic Peripherals)
--
--   local periph = dofile("/lib/periph.lua")
--   for _, p in ipairs(periph.scan()) do print(p.name, p.label, p.pack) end
--   local box = periph.find("chatBox")     -- wrapped peripheral or nil
--
-- Unknown types are listed too (label = the raw type), so any addon works.
local periph = {}

-- type -> { label, pack, hint }
periph.catalog = {
    -- CC:Tweaked
    monitor = { "Monitor", "CC:Tweaked", "external screen (display command)" },
    speaker = { "Speaker", "CC:Tweaked", "sounds and music" },
    modem = { "Modem", "CC:Tweaked", "wired / wireless network" },
    drive = { "Disk drive", "CC:Tweaked", "floppy disks and music discs" },
    printer = { "Printer", "CC:Tweaked", "prints pages" },
    computer = { "Computer", "CC:Tweaked", "another computer" },
    command = { "Command block", "CC:Tweaked", "runs commands" },
    redstone_relay = { "Redstone relay", "CC:Tweaked", "redstone I/O" },
    -- Advanced Peripherals
    chatBox = { "Chat box", "Advanced Peripherals", "send/receive chat messages (say command)" },
    playerDetector = { "Player detector", "Advanced Peripherals", "who is online / nearby (players command)" },
    environmentDetector = { "Environment detector", "Advanced Peripherals", "biome, weather, light, radiation" },
    energyDetector = { "Energy detector", "Advanced Peripherals", "energy flow of a cable" },
    inventoryManager = { "Inventory manager", "Advanced Peripherals", "player inventory transfers" },
    redstoneIntegrator = { "Redstone integrator", "Advanced Peripherals", "redstone on every side" },
    blockReader = { "Block reader", "Advanced Peripherals", "reads the block in front" },
    geoScanner = { "Geo scanner", "Advanced Peripherals", "scans ores around" },
    meBridge = { "ME bridge", "Advanced Peripherals", "Applied Energistics network" },
    rsBridge = { "RS bridge", "Advanced Peripherals", "Refined Storage network" },
    colonyIntegrator = { "Colony integrator", "Advanced Peripherals", "MineColonies colony" },
    nbtStorage = { "NBT storage", "Advanced Peripherals", "stores NBT data" },
    arController = { "AR controller", "Advanced Peripherals", "AR goggles overlay" },
    -- Classic Peripherals
    cryptographic_accelerator = { "Cryptographic accelerator", "Classic Peripherals", "hashes (NyxLoader Secure Boot)" },
    tape_drive = { "Tape drive", "Classic Peripherals", "tapes: storage and audio" },
    nfc_reader = { "NFC reader", "Classic Peripherals", "reads and writes NFC cards" },
    radio_tower = { "Radio tower", "Classic Peripherals", "long-range wireless" },
}

local function describe(ptype)
    local c = periph.catalog[ptype]
    if c then return c[1], c[2], c[3] end
    return ptype, "unknown", "no description"
end

-- Every attached peripheral: { name, type, types, label, pack, hint, side }
function periph.scan()
    local list = {}
    if not peripheral then return list end
    for _, name in ipairs(peripheral.getNames()) do
        local ok, types = pcall(function() return { peripheral.getType(name) } end)
        types = ok and types or {}
        local main = types[1] or "?"
        -- a modem on a wired network can also be a monitor etc.: pick the first known type
        for _, ty in ipairs(types) do if periph.catalog[ty] then main = ty break end end
        local label, pack, hint = describe(main)
        list[#list + 1] = { name = name, type = main, types = types, label = label, pack = pack, hint = hint }
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- First peripheral of a type (wrapped), or nil.
function periph.find(ptype)
    if not peripheral then return nil end
    local ok, p = pcall(peripheral.find, ptype)
    if ok then return p end
end

-- Method names of a peripheral.
function periph.methods(name)
    local ok, m = pcall(peripheral.getMethods, name)
    if ok and m then table.sort(m) return m end
    return {}
end

-- Convenience wrappers for common addon peripherals ---------------------

-- Names of the players currently online (Advanced Peripherals player detector).
function periph.players()
    local pd = periph.find("playerDetector")
    if not pd then return nil, "no player detector attached" end
    local ok, list = pcall(pd.getOnlinePlayers)
    if not ok then return nil, tostring(list) end
    return list or {}
end

-- Sends a chat message (Advanced Peripherals chat box).
function periph.say(message, label)
    local box = periph.find("chatBox")
    if not box then return false, "no chat box attached" end
    local ok, res, err = pcall(box.sendMessage, message, label or "NyxOS")
    if not ok then return false, tostring(res) end
    if res == false or res == nil then return false, tostring(err or "refused (cooldown?)") end
    return true
end

-- Short summary lines for the specs screen.
function periph.summary()
    local counts, order = {}, {}
    for _, p in ipairs(periph.scan()) do
        if not counts[p.label] then counts[p.label] = 0 order[#order + 1] = p.label end
        counts[p.label] = counts[p.label] + 1
    end
    local out = {}
    for _, l in ipairs(order) do out[#out + 1] = l .. (counts[l] > 1 and (" x" .. counts[l]) or "") end
    return out
end

return periph
