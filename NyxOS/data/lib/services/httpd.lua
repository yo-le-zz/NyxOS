-- Service httpd: a web server for the NyxOS network.
--   /srv/www/            the site (index.html is the default page)
--   /etc/httpd.lua       { root = "/srv/www", port = 80, host = "myserver",
--                          tls = true, lua = false, listing = false }
-- https: with tls = true (and a certificate made by `nyxcert create <host>`)
-- the server also answers on port 443, encrypted.
-- lua = true lets "*.lua" pages run (they receive `request` and return
-- status, body, headers): only enable it if nobody untrusted can write in the root.
return function()
    local web = dofile("/lib/nyxhttp.lua")
    local net = dofile("/lib/netstack.lua")
    local logger = dofile("/lib/logger.lua")

    local cfg = {}
    if fs.exists("/etc/httpd.lua") then
        local f = fs.open("/etc/httpd.lua", "r")
        local ok, t = pcall(textutils.unserialize, f.readAll())
        f.close()
        if ok and type(t) == "table" then cfg = t end
    end
    local root = "/" .. fs.combine("", cfg.root or "/srv/www")
    local host = cfg.host or (dofile("/lib/nyxlib.lua").getHostname())
    if not fs.exists(root) then
        fs.makeDir(root)
        local f = fs.open(root .. "/index.html", "w")
        f.write("<html><head><title>" .. host .. "</title></head><body><h1>It works!</h1>\n"
            .. "<p>This is the NyxOS web server of <b>" .. host .. "</b>.</p>\n"
            .. "<p>Put your pages in " .. root .. ".</p></body></html>\n")
        f.close()
    end

    local types = { html = "text/html", htm = "text/html", txt = "text/plain", lua = "text/plain",
        css = "text/css", json = "application/json", nfp = "image/nfp", md = "text/plain" }

    local function handler(req)
        if req.method ~= "GET" and req.method ~= "HEAD" and not cfg.lua then
            return 405, "Method not allowed", { ["content-type"] = "text/plain" }
        end
        local rel = req.path:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        local full = "/" .. fs.combine(root, rel)
        if full ~= root and full:sub(1, #root + 1) ~= root .. "/" then
            return 403, "Forbidden", { ["content-type"] = "text/plain" }
        end
        if fs.isDir(full) then
            if fs.exists(full .. "/index.html") then full = full .. "/index.html"
            elseif cfg.listing then
                local out = { "<html><body><h1>Index of " .. req.path .. "</h1>" }
                for _, n in ipairs(fs.list(full)) do
                    out[#out + 1] = '<li><a href="' .. fs.combine(req.path, n) .. '">' .. n .. "</a></li>"
                end
                return 200, table.concat(out, "\n") .. "</body></html>", { ["content-type"] = "text/html" }
            else
                return 403, "Directory listing is off", { ["content-type"] = "text/plain" }
            end
        end
        if not fs.exists(full) then
            logger.info("httpd", req.method .. " " .. req.path .. " -> 404")
            return 404, "<html><body><h1>404</h1><p>Not found: " .. req.path:gsub("[<>&]", "") .. "</p></body></html>",
                { ["content-type"] = "text/html" }
        end
        if cfg.lua and full:match("%.lua$") then
            local fn = loadfile(full, "t", setmetatable({ request = req }, { __index = _G }))
            if not fn then return 500, "Script error", { ["content-type"] = "text/plain" } end
            return fn()
        end
        local f = fs.open(full, "rb") or fs.open(full, "r")
        local data = f.readAll() or ""
        f.close()
        logger.info("httpd", req.method .. " " .. req.path .. " -> 200 (" .. #data .. " bytes) from " .. tostring(req.from))
        local ext = full:match("%.(%w+)$")
        return 200, data, { ["content-type"] = types[ext or ""] or "application/octet-stream" }
    end

    net.up()
    local ports = {}
    local function run(port, tls)
        web.serve(port, handler, { tls = tls, name = tls and "https" or "http" })
    end
    local fns = { function() run(cfg.port or 80, nil) end }
    if cfg.tls then
        local cert = web.loadCertificate(host)
        if cert then
            fns[#fns + 1] = function() run(443, cert) end
            logger.info("httpd", "https enabled for " .. host)
        else
            logger.warn("httpd", "tls = true but there is no certificate: run `nyxcert create " .. host .. "`")
        end
    end
    logger.info("httpd", "serving " .. root .. " on " .. net.myIp() .. ":" .. (cfg.port or 80))
    parallel.waitForAny((table.unpack or unpack)(fns))
end
