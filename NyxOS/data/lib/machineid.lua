-- /lib/machineid.lua : persistent machine identity, like /etc/machine-id
-- on real Linux systems.

local machineid = {}

local ID_PATH = "/etc/machine-id"

local function randomHex(bytes)
    local ok, crypto = pcall(dofile, "/lib/crypto.lua")
    local seed = tostring(os.epoch("utc")) .. tostring(math.random(0, 1e9)) .. tostring(os.getComputerID())
    if ok and crypto then
        local h = crypto.hash(seed)
        if h and #h >= bytes * 2 then
            return h:sub(1, bytes * 2)
        end
    end
    -- Fallback: pseudo-random hex
    local out = {}
    for i = 1, bytes do
        out[i] = string.format("%02x", math.random(0, 255))
    end
    return table.concat(out)
end

-- Returns the persistent machine id, generating one on first call.
function machineid.get()
    if fs.exists(ID_PATH) then
        local f = fs.open(ID_PATH, "r")
        local id = f.readAll():gsub("%s+$", "")
        f.close()
        if id ~= "" then
            return id
        end
    end
    local id = randomHex(16) -- 32 hex chars, like a Linux machine-id
    local f = fs.open(ID_PATH, "w")
    f.write(id)
    f.close()
    return id
end

-- Full identity summary, similar to `hostnamectl status`.
function machineid.info()
    local nyxlib = dofile("/lib/nyxlib.lua")
    local release = "NyxOS 1.0.1"
    if fs.exists("/etc/nyx-release") then
        local f = fs.open("/etc/nyx-release", "r")
        release = (f.readAll():match("^[^\n]+")) or release
        f.close()
    end
    return {
        machineId = machineid.get(),
        hostname = nyxlib.getHostname(),
        computerId = os.getComputerID(),
        computerLabel = os.getComputerLabel and os.getComputerLabel() or nil,
        release = release,
        host = _HOST or "ComputerCraft",
    }
end

return machineid
