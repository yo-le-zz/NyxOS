-- /bin/uname.lua : prints system information

local nyxlib = dofile("/lib/nyxlib.lua")

local release = "NyxOS 1.0"
if fs.exists("/etc/nyx-release") then
    local f = fs.open("/etc/nyx-release", "r")
    release = (f.readAll():match("^[^\n]+")) or release
    f.close()
end

local host = _HOST or "ComputerCraft (unknown version)"
print(release .. " " .. nyxlib.getHostname() .. " " .. host)
