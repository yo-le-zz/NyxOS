-- /bin/machineid.lua : shows this computer's NyxOS machine identity
local machineid = dofile("/lib/machineid.lua")
local info = machineid.info()

print("Machine ID     : " .. info.machineId)
print("Hostname       : " .. info.hostname)
print("Computer ID    : " .. tostring(info.computerId))
if info.computerLabel then
    print("Computer label : " .. info.computerLabel)
end
print("Release        : " .. info.release)
print("Host           : " .. info.host)
