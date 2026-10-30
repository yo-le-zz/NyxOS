-- /lib/nyxhttp.lua : http and https for the NyxOS network (and the real internet)
--
--   local web = dofile("/lib/nyxhttp.lua")
--   local res, err = web.get("http://server1/index.html")       -- NyxOS network
--   local res, err = web.get("https://server1/")                 -- encrypted (needs the site certificate)
--   local res, err = web.get("https://example.com/")             -- real internet (CC http API)
--   res = { status = 200, headers = { ["content-type"] = "text/html" }, body = "...", via = "nyx"|"internet" }
--   web.post(url, body, headers)
--
--   web.serve(port, handler, { tls = secret, host = "name" })    -- run a server (blocks)
--     handler(request) -> status, body, headers      (request = { method, path, query, headers, body, from })
--
-- A name is looked up on the NyxOS network first (/etc/hosts, DNS, addresses);
-- if it is not known there and the CC http API is on, the real internet is used.
--
-- HTTPS here is "pre-shared key TLS": a site has a certificate file (a secret,
-- made by `nyxcert create <host>`); a client that holds the same certificate
-- (`nyxcert import`) can verify the site is really that site, and everything
-- after the handshake is encrypted (SHA-256 counter keystream) and
-- authenticated (SHA-256 MAC, replay-protected by sequence numbers). It does
-- not make strangers trust each other (no certificate authority): the
-- certificate must reach the client by a trusted road (disk, ssh).

local web = {}

local net = dofile("/lib/netstack.lua")
local crypto = dofile("/lib/crypto.lua")

web.HTTP_PORT = 80
web.HTTPS_PORT = 443
local CHUNK = 6000
local MAX_BODY = 512 * 1024

------------------------------------------------------------------
-- certificates
------------------------------------------------------------------

local SSL_DIR = "/etc/ssl"
local TRUST_DIR = "/etc/ssl/trusted"

local function readTable(path)
    if not fs.exists(path) or fs.isDir(path) then return nil end
    local f = fs.open(path, "r")
    local s = f.readAll()
    f.close()
    local ok, t = pcall(textutils.unserialize, s)
    return ok and type(t) == "table" and t or nil
end

local function writeTable(path, t)
    local dir = fs.getDir(path)
    if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
    local f = fs.open(path, "w")
    if not f then return false end
    f.write(textutils.serialize(t))
    f.close()
    return true
end

local function fingerprint(secret)
    return crypto.sha256("nyx-cert:" .. secret):sub(1, 32)
end

local function randomHex(n)
    local t = {}
    for i = 1, n do t[i] = string.format("%02x", math.random(0, 255)) end
    return table.concat(t)
end

-- Creates /etc/ssl/<host>.key (the site's certificate + secret)
function web.createCertificate(host)
    host = tostring(host):lower()
    if not host:match("^[%w%-%._]+$") then return nil, "invalid host name" end
    local secret = crypto.sha256(randomHex(32) .. os.epoch("utc") .. os.getComputerID() .. tostring({})):sub(1, 48)
    local cert = { host = host, secret = secret, fp = fingerprint(secret), created = os.epoch("utc") }
    if not writeTable(SSL_DIR .. "/" .. host .. ".key", cert) then return nil, "cannot write the certificate" end
    return cert
end

function web.loadCertificate(host)
    return readTable(SSL_DIR .. "/" .. tostring(host):lower() .. ".key")
end

function web.importCertificate(path)
    local cert = readTable(path)
    if not cert or not cert.host or not cert.secret then return nil, "not a NyxOS certificate" end
    cert.fp = fingerprint(cert.secret)
    cert.imported = true
    if not writeTable(TRUST_DIR .. "/" .. cert.host .. ".lua", cert) then return nil, "cannot write the trust store" end
    return cert
end

function web.trusted()
    local out = {}
    if fs.exists(TRUST_DIR) then
        for _, name in ipairs(fs.list(TRUST_DIR)) do
            local c = readTable(TRUST_DIR .. "/" .. name)
            if c and c.host and c.secret then out[#out + 1] = c end
        end
    end
    return out
end

------------------------------------------------------------------
-- secure channel (used for https)
------------------------------------------------------------------

local function xorBytes(data, key, dir, seq)
    local out, n = {}, #data
    local block, pos = 0, 1
    while pos <= n do
        local ks = crypto.sha256(key .. dir .. seq .. ":" .. block)
        for i = 1, 32, 2 do
            if pos > n then break end
            local kb = tonumber(ks:sub(i, i + 1), 16)
            local d = data:byte(pos)
            -- xor without bit ops
            local r, bit = 0, 1
            local a, b = d, kb
            for _ = 1, 8 do
                if (a % 2) ~= (b % 2) then r = r + bit end
                a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
            end
            out[pos] = string.char(r)
            pos = pos + 1
        end
        block = block + 1
    end
    return table.concat(out)
end

local function toHex(s)
    return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end
local function fromHex(h)
    return (h:gsub("%x%x", function(x) return string.char(tonumber(x, 16)) end))
end

local Secure = {}
Secure.__index = Secure

local function newSecure(conn, key, role)
    return setmetatable({ conn = conn, key = key, sendDir = role == "client" and "c" or "s",
        recvDir = role == "client" and "s" or "c", sendSeq = 0, recvSeq = 0, peer = conn.peer }, Secure)
end

function Secure:send(value)
    local plain = textutils.serialize(value)
    self.sendSeq = self.sendSeq + 1
    local enc = toHex(xorBytes(plain, self.key, self.sendDir, self.sendSeq))
    local mac = crypto.sha256(self.key .. self.sendDir .. self.sendSeq .. enc):sub(1, 32)
    return self.conn:send({ t = "rec", seq = self.sendSeq, data = enc, mac = mac })
end

function Secure:receive(timeout)
    local m, why = self.conn:receive(timeout)
    if not m then return nil, why end
    if type(m) ~= "table" or m.t ~= "rec" or type(m.data) ~= "string" then return nil, "protocol error" end
    if m.seq ~= self.recvSeq + 1 then return nil, "replayed or out-of-order record" end
    local mac = crypto.sha256(self.key .. self.recvDir .. m.seq .. m.data):sub(1, 32)
    if mac ~= m.mac then return nil, "bad record signature" end
    self.recvSeq = m.seq
    local plain = xorBytes(fromHex(m.data), self.key, self.recvDir, m.seq)
    local ok, value = pcall(textutils.unserialize, plain)
    if not ok then return nil, "unreadable record" end
    return value
end

function Secure:close() return self.conn:close() end

-- Client side handshake. certs = list of acceptable certificates.
local function clientHandshake(conn, certs)
    local cn = randomHex(12)
    conn:send({ t = "hello", cn = cn })
    local s = conn:receive(5)
    if type(s) ~= "table" or s.t ~= "shello" then return nil, "no TLS answer (is this an https port?)" end
    local chosen
    for _, c in ipairs(certs) do
        if c.fp == s.fp and crypto.sha256(c.secret .. ":srv:" .. cn .. s.sn) == s.proof then chosen = c break end
    end
    if not chosen then return nil, "certificate not trusted (nyxcert import the site's certificate)" end
    conn:send({ t = "finished", proof = crypto.sha256(chosen.secret .. ":cli:" .. s.sn .. cn) })
    local ok = conn:receive(5)
    if type(ok) ~= "table" or ok.t ~= "ready" then return nil, "handshake refused" end
    return newSecure(conn, crypto.sha256(chosen.secret .. ":key:" .. cn .. s.sn), "client"), chosen
end

-- Server side handshake with the site certificate.
local function serverHandshake(conn, cert)
    local h = conn:receive(5)
    if type(h) ~= "table" or h.t ~= "hello" or type(h.cn) ~= "string" then return nil, "no hello" end
    local sn = randomHex(12)
    conn:send({ t = "shello", sn = sn, fp = cert.fp, proof = crypto.sha256(cert.secret .. ":srv:" .. h.cn .. sn) })
    local f = conn:receive(5)
    if type(f) ~= "table" or f.t ~= "finished" or f.proof ~= crypto.sha256(cert.secret .. ":cli:" .. sn .. h.cn) then
        conn:send({ t = "refused" })
        return nil, "client could not prove the certificate"
    end
    conn:send({ t = "ready" })
    return newSecure(conn, crypto.sha256(cert.secret .. ":key:" .. h.cn .. sn), "server")
end

------------------------------------------------------------------
-- http over a connection (plain or secure: same send/receive API)
------------------------------------------------------------------

local function sendBody(c, body)
    for pos = 1, #body, CHUNK do
        local ok, err = c:send({ t = "part", data = body:sub(pos, pos + CHUNK - 1) })
        if not ok then return nil, err end
    end
    return true
end

local function recvBody(c, len, timeout)
    if len > MAX_BODY then return nil, "body too large" end
    local parts, got = {}, 0
    while got < len do
        local m = c:receive(timeout or 10)
        if type(m) ~= "table" or m.t ~= "part" then return nil, "connection lost while reading the body" end
        parts[#parts + 1] = m.data
        got = got + #m.data
    end
    return table.concat(parts)
end

function web.parseUrl(url)
    local scheme, rest = tostring(url):match("^(%a+)://(.+)$")
    if not scheme then scheme, rest = "http", tostring(url) end
    scheme = scheme:lower()
    local hostport, path = rest:match("^([^/]+)(/.*)$")
    if not hostport then hostport, path = rest, "/" end
    local host, port = hostport:match("^(.-):(%d+)$")
    if not host then host = hostport end
    return { scheme = scheme, host = host:lower(), port = tonumber(port), path = path, url = url }
end

local function viaNyx(u, method, body, headers, timeout)
    local ip = net.resolveName(u.host)
    if not ip then return nil, "unknown host " .. u.host, true end
    local secure = u.scheme == "https"
    local port = u.port or (secure and web.HTTPS_PORT or web.HTTP_PORT)
    local conn, err = net.connect(ip, port, timeout or 4)
    if not conn then return nil, err end
    local c = conn
    if secure then
        local certs = {}
        for _, t in ipairs(web.trusted()) do
            if t.host == u.host or net.resolveName(t.host) == ip then certs[#certs + 1] = t end
        end
        local sec, why = clientHandshake(conn, certs)
        if not sec then conn:close() return nil, "https: " .. tostring(why) end
        c = sec
    end
    headers = headers or {}
    headers["host"] = u.host
    body = body or ""
    c:send({ t = "req", method = method, path = u.path, headers = headers, len = #body })
    if #body > 0 then sendBody(c, body) end
    local r = c:receive(timeout or 10)
    if type(r) ~= "table" or r.t ~= "res" then c:close() return nil, "no answer from " .. u.host end
    local data, e2 = recvBody(c, r.len or 0, timeout)
    c:close()
    if not data then return nil, e2 end
    return { status = r.status, headers = r.headers or {}, body = data, via = "nyx", secure = secure, ip = ip }
end

local function viaInternet(u, method, body, headers)
    if not http then return nil, "the http API is disabled (and the host is not on the NyxOS network)" end
    local url = u.scheme .. "://" .. u.host .. (u.port and (":" .. u.port) or "") .. u.path
    local res, reason, failed
    if method == "POST" then
        res, reason, failed = http.post(url, body or "", headers)
    elseif method == "GET" then
        res, reason, failed = http.get(url, headers)
    else
        res, reason, failed = http.get({ url = url, method = method, headers = headers, body = body })
    end
    res = res or failed
    if not res then return nil, tostring(reason or "request failed") end
    local out = {
        status = res.getResponseCode and res.getResponseCode() or 200,
        headers = res.getResponseHeaders and res.getResponseHeaders() or {},
        body = res.readAll() or "", via = "internet", secure = u.scheme == "https",
    }
    res.close()
    return out
end

function web.request(method, url, body, headers, timeout)
    local u = web.parseUrl(url)
    if u.scheme ~= "http" and u.scheme ~= "https" then return nil, "unsupported scheme " .. u.scheme end
    local res, err, unknown = viaNyx(u, method, body, headers, timeout)
    if res then return res end
    if unknown then return viaInternet(u, method, body, headers) end
    return nil, err
end

function web.get(url, headers, timeout) return web.request("GET", url, nil, headers, timeout) end
function web.post(url, body, headers, timeout) return web.request("POST", url, body, headers, timeout) end
function web.head(url, headers, timeout) return web.request("HEAD", url, nil, headers, timeout) end

------------------------------------------------------------------
-- server
------------------------------------------------------------------

local STATUS = { [200] = "OK", [201] = "Created", [204] = "No Content", [301] = "Moved", [302] = "Found",
    [400] = "Bad Request", [403] = "Forbidden", [404] = "Not Found", [405] = "Method Not Allowed",
    [413] = "Too Large", [500] = "Server Error" }
web.STATUS = STATUS

local function serveOne(c, handler, from)
    local r = c:receive(10)
    if type(r) ~= "table" or r.t ~= "req" then return end
    local body = ""
    if (r.len or 0) > 0 then
        local data, err = recvBody(c, r.len, 10)
        if not data then return end
        body = data
    end
    local path, query = tostring(r.path or "/"):match("^([^?]*)%??(.*)$")
    local req = { method = tostring(r.method or "GET"):upper(), path = path, query = query, headers = r.headers or {}, body = body, from = from }
    local ok, status, out, headers = pcall(handler, req)
    if not ok then
        local why = status
        status, out, headers = 500, "Server error", { ["content-type"] = "text/plain" }
        pcall(function() dofile("/lib/logger.lua").error("httpd", "handler: " .. tostring(why)) end)
    end
    out = tostring(out or "")
    headers = headers or {}
    if req.method == "HEAD" then headers["content-length"] = tostring(#out) out = "" end
    c:send({ t = "res", status = status or 200, headers = headers, len = #out })
    if #out > 0 then sendBody(c, out) end
end

-- Runs a server on `port`; blocks. opts: { tls = certificate table, name = "..." }
-- Each connection is handled in its own coroutine.
function web.serve(port, handler, opts)
    opts = opts or {}
    net.up()
    local listener = net.listen(port, opts.name or (opts.tls and "https" or "http"))
    local threads = {}
    local function spawn(fn)
        table.insert(threads, { co = coroutine.create(fn) })
    end
    spawn(function()
        while true do
            local conn = listener:accept()
            if conn then
                spawn(function()
                    local ok, err = pcall(function()
                        local c = conn
                        if opts.tls then
                            local sec, why = serverHandshake(conn, opts.tls)
                            if not sec then conn:close() return end
                            c = sec
                        end
                        serveOne(c, handler, conn.peer)
                        c:close()
                    end)
                    if not ok then
                        pcall(function() dofile("/lib/logger.lua").warn("httpd", "connection: " .. tostring(err)) end)
                        pcall(conn.close, conn)
                    end
                end)
            end
        end
    end)
    local event = {}
    while true do
        for i = #threads, 1, -1 do
            local th = threads[i]
            if th.filter == nil or th.filter == event[1] or event[1] == "terminate" then
                local ok, filter = coroutine.resume(th.co, (table.unpack or unpack)(event))
                if not ok or coroutine.status(th.co) == "dead" then
                    if not ok then pcall(function() dofile("/lib/logger.lua").warn("httpd", tostring(filter)) end) end
                    table.remove(threads, i)
                else
                    th.filter = filter
                end
            end
        end
        event = { os.pullEventRaw() }
        if event[1] == "terminate" then break end
    end
    listener:close()
end

------------------------------------------------------------------
-- tiny html -> text (used by the browser and `web`)
------------------------------------------------------------------

local ENT = { amp = "&", lt = "<", gt = ">", quot = '"', nbsp = " ", apos = "'" }

-- Returns text, links  (links = { { text=, href= } ... }, numbered [n] in the text)
function web.htmlToText(html)
    local links = {}
    html = tostring(html):gsub("<!%-%-.-%-%->", ""):gsub("<script.-</script>", ""):gsub("<style.-</style>", "")
    local title = html:match("<[Tt][Ii][Tt][Ll][Ee]>(.-)</[Tt][Ii][Tt][Ll][Ee]>")
    html = html:gsub("<[Tt][Ii][Tt][Ll][Ee]>.-</[Tt][Ii][Tt][Ll][Ee]>", "")
    html = html:gsub("<[Aa]%s[^>]-[Hh][Rr][Ee][Ff]%s*=%s*[\"']([^\"']*)[\"'][^>]*>(.-)</[Aa]>", function(href, text)
        text = text:gsub("<[^>]*>", "")
        links[#links + 1] = { href = href, text = text }
        return string.format("%s[%d]", text, #links)
    end)
    html = html:gsub("<[Bb][Rr]%s*/?>", "\n"):gsub("</[Pp]>", "\n\n"):gsub("</[Dd][Ii][Vv]>", "\n")
        :gsub("<[Ll][Ii][^>]*>", "\n * "):gsub("</[Hh]%d>", "\n\n"):gsub("<[Hh]%d[^>]*>", "\n# ")
        :gsub("<[Tt][Rr][^>]*>", "\n"):gsub("</[Tt][Dd]>", "  ")
    html = html:gsub("<[^>]*>", "")
    html = html:gsub("&(%a+);", function(n) return ENT[n:lower()] or ("&" .. n .. ";") end)
    html = html:gsub("[ \t]+", " "):gsub(" ?\n ?", "\n"):gsub("\n\n\n+", "\n\n")
    html = html:gsub("^%s+", "")
    return html, links, title and title:gsub("%s+", " ") or nil
end

-- Resolves a link found in a page relative to the page url
function web.resolveLink(base, href)
    if href:match("^%a+://") then return href end
    local u = web.parseUrl(base)
    local origin = u.scheme .. "://" .. u.host .. (u.port and (":" .. u.port) or "")
    if href:sub(1, 1) == "/" then return origin .. href end
    local dir = u.path:match("^(.*/)") or "/"
    return origin .. dir .. href
end

return web
