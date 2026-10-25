-- /bin/testbasalt.lua : test script to verify Basalt loading

print("Testing Basalt load...")
print("")

-- Test from data/lib (during install)
print("1. Test from data/lib/basalt.lua :")
local ok1, basalt1 = pcall(dofile, "data/lib/basalt.lua")
if ok1 and basalt1 then
    print("   SUCCESS: Basalt loaded from data/lib")
else
    print("   FAILED: " .. tostring(basalt1))
end
print("")

-- Test from /lib (after install)
print("2. Test from /lib/basalt.lua :")
if fs.exists("/lib/basalt.lua") then
    local ok2, basalt2 = pcall(dofile, "/lib/basalt.lua")
    if ok2 and basalt2 then
        print("   SUCCESS: Basalt loaded from /lib")
    else
        print("   FAILED: " .. tostring(basalt2))
    end
else
    print("   File not found: /lib/basalt.lua")
end
print("")

-- Test with pcall and direct dofile
print("3. Test with pcall(dofile, '/lib/basalt.lua') :")
local ok3, basalt3 = pcall(dofile, "/lib/basalt.lua")
if ok3 then
    print("   pcall OK")
    if basalt3 then
        print("   Basalt is not nil")
        if type(basalt3) == "table" then
            print("   Basalt is a table")
        else
            print("   Basalt is of type: " .. type(basalt3))
        end
    else
        print("   Basalt is nil")
    end
else
    print("   pcall FAILED: " .. tostring(basalt3))
end
print("")

-- File size check
print("4. File check:")
if fs.exists("/lib/basalt.lua") then
    local size = fs.getSize("/lib/basalt.lua")
    print("   Size : " .. size .. " bytes")
    if size > 300000 then
        print("   Size OK (> 300KB)")
    else
        print("   Size abnormal (should be > 300KB)")
    end
else
    print("   File not found")
end
print("")

print("Test complete.")
