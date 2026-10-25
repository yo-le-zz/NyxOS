-- /bin/wget.lua : download a URL to a local file
-- Usage: wget <url> <file>

local network = dofile("/lib/network.lua")
local args = { ... }

local url, dest = args[1], args[2]
if not url or not dest then
    print("Usage: wget <url> <file>")
    return
end

print("Downloading " .. url .. " ...")
local ok, err = network.download(url, shell.resolve(dest))
if ok then
    print("Saved to " .. dest)
else
    print("wget: " .. tostring(err))
end
