-- /bin/web.lua : text web client
--   web get <url> [file]        prints the page as text (or saves the raw body to file)
--   web raw <url>               prints the raw body
--   web head <url>              status and headers
--   web post <url> <data>       POST
-- URLs: http://host/path, https://host/path (NyxOS network first, then the real internet).
local web = dofile("/lib/nyxhttp.lua")
local args = { ... }
local cmd, url = args[1], args[2]
if not cmd or not url then
    print("Usage: web get|raw|head|post <url> [file|data]")
    return
end
local res, err
if cmd == "get" or cmd == "raw" then res, err = web.get(url)
elseif cmd == "head" then res, err = web.head(url)
elseif cmd == "post" then res, err = web.post(url, args[3] or "")
else print("Unknown command: " .. cmd) return end
if not res then print("web: " .. tostring(err)) return end
if cmd == "head" then
    print(res.status .. " (" .. res.via .. (res.secure and ", encrypted" or "") .. ")")
    for k, v in pairs(res.headers) do print(k .. ": " .. tostring(v)) end
    return
end
if cmd == "get" and args[3] then
    local f = fs.open(shell.resolve(args[3]), "wb") or fs.open(shell.resolve(args[3]), "w")
    f.write(res.body) f.close()
    print(res.status .. " saved " .. #res.body .. " bytes to " .. args[3])
    return
end
print(res.status .. " (" .. res.via .. (res.secure and ", encrypted" or ", clear") .. ")")
local ct = tostring(res.headers["content-type"] or res.headers["Content-Type"] or "")
if cmd == "get" and (ct:find("html") or res.body:find("<html") or res.body:find("<HTML")) then
    local text, links = web.htmlToText(res.body)
    print(text)
    for i, l in ipairs(links) do print(string.format("[%d] %s", i, web.resolveLink(url, l.href))) end
else
    print(res.body)
end
