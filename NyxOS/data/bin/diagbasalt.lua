-- /bin/diagbasalt.lua : detailed Basalt diagnostic

print("=== BASALT DIAGNOSTIC ===")
print("")

-- Test 1: file check
print("1. Checking basalt.lua file:")
if fs.exists("/lib/basalt.lua") then
    local size = fs.getSize("/lib/basalt.lua")
    print("   File exists : YES")
    print("   Size : " .. size .. " bytes")
    if size > 300000 then
        print("   Size : OK")
    else
        print("   Size : ABNORMAL (should be > 300KB)")
    end
else
    print("   File exists : NO")
    print("   Checking data/lib :")
    if fs.exists("data/lib/basalt.lua") then
        print("   Found in data/lib/basalt.lua")
        local size = fs.getSize("data/lib/basalt.lua")
        print("   Size : " .. size .. " bytes")
    else
        print("   NOT FOUND in data/lib")
    end
end
print("")

-- Test 2: reading first/last lines
print("2. Reading lines:")
local testPath = "/lib/basalt.lua"
if not fs.exists(testPath) then
    testPath = "data/lib/basalt.lua"
end
if fs.exists(testPath) then
    local f = fs.open(testPath, "r")
    if f then
        local line1 = f.readLine()
        local line2 = f.readLine()
        f.close()
        print("   Line 1 : " .. (line1 or "NIL"))
        print("   Line 2 : " .. (line2 or "NIL"))

        -- Read the last line
        local f2 = fs.open(testPath, "r")
        local lastLine = ""
        for line in f2.readLine do
            lastLine = line
        end
        f2.close()
        print("   Last line : " .. (lastLine or "NIL"))
    else
        print("   ERROR: Could not open file")
    end
end
print("")

-- Test 3: attempt to load with debug info
print("3. Attempting to load:")
local function loadBasalt(path)
    print("   Trying: " .. path)
    local f = fs.open(path, "r")
    if not f then
        print("   ERROR: could not open")
        return false, "open failed"
    end

    local content = f.readAll()
    f.close()

    print("   Bytes read : " .. #content .. " bytes")

    local chunk, err = load(content, path)
    if not chunk then
        print("   Compile error: " .. tostring(err))
        return false, err
    end

    print("   Compilation OK")

    local success, result = pcall(chunk)
    if not success then
        print("   Runtime error: " .. tostring(result))
        return false, result
    end

    print("   Load OK")
    print("   Return type : " .. type(result))
    return true, result
end

local paths = {"/lib/basalt.lua", "data/lib/basalt.lua"}
local loaded = false
for _, path in ipairs(paths) do
    if fs.exists(path) then
        local ok, result = loadBasalt(path)
        if ok then
            print("   SUCCESS with: " .. path)
            loaded = true
            -- Check whether basalt exposes the expected methods
            if type(result) == "table" then
                print("   Available methods:")
                for k, v in pairs(result) do
                    print("     - " .. k)
                    if k == "getMainFrame" then
                        print("       -> getMainFrame found (OK)")
                    end
                end
            end
            break
        end
    end
end

if not loaded then
    print("   FAILED: could not load Basalt")
end
print("")

-- Test 4: environment check
print("4. Environment:")
print("   OS : " .. tostring(_OS))
print("   CC version : " .. tostring(_CC_VERSION or "unknown"))
print("   Computer ID : " .. os.getComputerID())
print("")

print("=== DIAGNOSTIC COMPLETE ===")
