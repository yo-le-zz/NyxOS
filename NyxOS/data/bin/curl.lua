-- /bin/curl.lua : fetch a URL and print its body (or save it to a file)
-- Usage:
--   curl <url>              print the response body
--   curl <url> -o <file>     save the response body to <file>

local network = dofile("/lib/network.lua")
local args = { ... }

local url = args[1]
if not url then
    print("Usage: curl <url> [-o <file>]")
    return
end

if args[2] == "-o" and args[3] then
    local ok, err = network.download(url, shell.resolve(args[3]))
    if ok then
        print("Saved to " .. args[3])
    else
        print("curl: " .. tostring(err))
    end
    return
end

local body, err = network.fetch(url)
if not body then
    print("curl: " .. tostring(err))
    return
end
print(body)
