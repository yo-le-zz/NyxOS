-- /bin/nyxcert.lua : certificates for https on the NyxOS network
--   nyxcert create <host>          makes /etc/ssl/<host>.key for a site you host (administrator)
--   nyxcert export <host> <file>   copies the certificate so it can reach clients (by disk / ssh)
--   nyxcert import <file>          trusts a site's certificate on this computer
--   nyxcert list                   certificates you host and certificates you trust
--   nyxcert remove <host>          stops trusting <host> (and deletes a hosted certificate)
-- The certificate holds a secret: only give it to computers you trust.
local web = dofile("/lib/nyxhttp.lua")
local args = { ... }
local cmd = args[1]

local function admin()
    local good, why = dofile("/lib/permissions.lua").requirePrivileged("managing certificates")
    if not good then print(why) end
    return good
end

if cmd == "create" and args[2] then
    if not admin() then return end
    local cert, err = web.createCertificate(args[2])
    if not cert then print("nyxcert: " .. tostring(err)) return end
    print("Certificate for " .. cert.host .. " created. Fingerprint " .. cert.fp)
    print("Enable https: set tls = true in /etc/httpd.lua, then: service restart httpd")
    print("Give it to clients: nyxcert export " .. cert.host .. " <file>")
elseif cmd == "export" and args[2] and args[3] then
    if not admin() then return end
    local cert = web.loadCertificate(args[2])
    if not cert then print("No certificate for " .. args[2]) return end
    fs.copy("/etc/ssl/" .. cert.host .. ".key", shell.resolve(args[3]))
    print("Exported to " .. args[3] .. " (it contains the secret: move it by disk or ssh).")
elseif cmd == "import" and args[2] then
    if not admin() then return end
    local cert, err = web.importCertificate(shell.resolve(args[2]))
    if not cert then print("nyxcert: " .. tostring(err)) return end
    print("Trusting " .. cert.host .. " (fingerprint " .. cert.fp .. ")")
elseif cmd == "list" then
    print("Hosted:")
    if fs.exists("/etc/ssl") then
        for _, n in ipairs(fs.list("/etc/ssl")) do
            if n:match("%.key$") then print("  " .. n:gsub("%.key$", "")) end
        end
    end
    print("Trusted:")
    for _, c in ipairs(web.trusted()) do print("  " .. c.host .. "  " .. c.fp) end
elseif cmd == "remove" and args[2] then
    if not admin() then return end
    local host = args[2]:lower()
    for _, p in ipairs({ "/etc/ssl/trusted/" .. host .. ".lua", "/etc/ssl/" .. host .. ".key" }) do
        if fs.exists(p) then fs.delete(p) print("Removed " .. p) end
    end
else
    print("Usage: nyxcert create|export|import|list|remove (see: man nyxcert)")
end
