-- /lib/network.lua : NyxOS network helpers (HTTP + rednet)

local network = {}

-- ---------------------------------------------------------------
-- HTTP
-- ---------------------------------------------------------------

-- Fetches a URL and returns body, nil on success or nil, error on
-- failure. Requires the `http` API to be enabled on this computer.
function network.fetch(url, headers)
    if not http then
        return nil, "The http API is not enabled on this computer."
    end
    local response, err = http.get(url, headers)
    if not response then
        return nil, tostring(err)
    end
    local body = response.readAll()
    response.close()
    return body
end

-- Downloads a URL straight to a local file.
function network.download(url, destPath, headers)
    local body, err = network.fetch(url, headers)
    if not body then
        return false, err
    end
    local dir = fs.getDir(destPath)
    if dir ~= "" and not fs.exists(dir) then
        fs.makeDir(dir)
    end
    local f = fs.open(destPath, "w")
    if not f then
        return false, "Could not open " .. destPath .. " for writing."
    end
    f.write(body)
    f.close()
    return true
end

-- ---------------------------------------------------------------
-- rednet
-- ---------------------------------------------------------------

-- Opens every wireless/wired modem attached to the computer for rednet.
function network.openAllModems()
    local opened = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "modem" then
            rednet.open(name)
            table.insert(opened, name)
        end
    end
    return opened
end

-- Very small DHCP-like discovery protocol: a "server" hosts a protocol
-- name; clients broadcast a lookup and collect replies for `timeout`
-- seconds. Not real DHCP (rednet has no concept of IP addresses) -- this
-- just assigns each replying computer a short-lived "lease id" the
-- caller can use as a friendly network id.
network.DHCP_PROTOCOL = "nyxnet.dhcp"

function network.dhcpServe(serviceName)
    network.openAllModems()
    rednet.host(network.DHCP_PROTOCOL, serviceName)
end

function network.dhcpDiscover(timeout)
    network.openAllModems()
    local found = {}
    local ids = { rednet.lookup(network.DHCP_PROTOCOL) }
    for _, id in ipairs(ids) do
        table.insert(found, id)
    end
    return found
end

return network
