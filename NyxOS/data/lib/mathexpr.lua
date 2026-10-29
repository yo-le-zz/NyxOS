-- /lib/mathexpr.lua : safe math expression evaluator (no load()).
--
--   local m = dofile("/lib/mathexpr.lua")
--   local value, err = m.eval("2*(3+4)^2 - sqrt(16)", { degrees = false, ans = 0, vars = { x = 3 } })
--
-- Numbers: 12, 3.5, .5, 1e-3, 0xFF, 0b101.  Operators: + - * / % ^ ! (factorial),
-- unary - and +, implicit multiplication (2pi, 3(4+1)), `mod`.
-- Constants: pi, e, tau, phi, ans.  Functions: sin cos tan asin acos atan
-- sinh cosh tanh sqrt cbrt abs floor ceil round trunc sign exp ln log (base 10)
-- log2 logb(x,b) pow(x,y) min max hypot atan2 rad deg fact gcd lcm rand(n).

local M = {}

local pi = math.pi
local function fact(n)
    if n < 0 or n ~= math.floor(n) then error("factorial needs a whole number >= 0", 0) end
    if n > 170 then return math.huge end
    local r = 1
    for i = 2, n do r = r * i end
    return r
end
local function gcd(a, b)
    a, b = math.abs(a), math.abs(b)
    while b ~= 0 do a, b = b, a % b end
    return a
end
local function round(x, n)
    n = n or 0
    local m = 10 ^ n
    return math.floor(x * m + 0.5) / m
end

local function funcs(opts)
    local deg = opts.degrees
    local function toRad(x) return deg and x * pi / 180 or x end
    local function fromRad(x) return deg and x * 180 / pi or x end
    local function sinh(x) return (math.exp(x) - math.exp(-x)) / 2 end
    local function cosh(x) return (math.exp(x) + math.exp(-x)) / 2 end
    return {
        sin = function(x) return math.sin(toRad(x)) end,
        cos = function(x) return math.cos(toRad(x)) end,
        tan = function(x) return math.tan(toRad(x)) end,
        asin = function(x) return fromRad(math.asin(x)) end,
        acos = function(x) return fromRad(math.acos(x)) end,
        atan = function(x) return fromRad(math.atan(x)) end,
        atan2 = function(y, x) return fromRad(math.atan2 and math.atan2(y, x) or math.atan(y, x)) end,
        sinh = sinh, cosh = cosh, tanh = function(x) return sinh(x) / cosh(x) end,
        sqrt = function(x) if x < 0 then error("sqrt of a negative number", 0) end return math.sqrt(x) end,
        cbrt = function(x) return x < 0 and -((-x) ^ (1 / 3)) or x ^ (1 / 3) end,
        abs = math.abs, floor = math.floor, ceil = math.ceil,
        round = round,
        trunc = function(x) return x < 0 and math.ceil(x) or math.floor(x) end,
        sign = function(x) return x > 0 and 1 or (x < 0 and -1 or 0) end,
        exp = math.exp,
        ln = function(x) if x <= 0 then error("ln needs a positive number", 0) end return math.log(x) end,
        log = function(x) if x <= 0 then error("log needs a positive number", 0) end return math.log(x) / math.log(10) end,
        log2 = function(x) if x <= 0 then error("log2 needs a positive number", 0) end return math.log(x) / math.log(2) end,
        logb = function(x, b) return math.log(x) / math.log(b) end,
        pow = function(x, y) return x ^ y end,
        min = math.min, max = math.max,
        hypot = function(x, y) return math.sqrt(x * x + y * y) end,
        rad = function(x) return x * pi / 180 end,
        deg = function(x) return x * 180 / pi end,
        fact = fact,
        gcd = gcd,
        lcm = function(a, b) if a == 0 or b == 0 then return 0 end return math.abs(a * b) / gcd(a, b) end,
        rand = function(n) if n then return math.random(math.floor(n)) end return math.random() end,
    }
end

local CONST = { pi = pi, e = math.exp(1), tau = 2 * pi, phi = (1 + math.sqrt(5)) / 2 }

local function tokenize(src)
    local tokens, i, n = {}, 1, #src
    while i <= n do
        local c = src:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c:match("%d") or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
            local hex = src:match("^0[xX]%x+", i)
            local bin = src:match("^0[bB][01]+", i)
            if hex then
                tokens[#tokens + 1] = { t = "num", v = tonumber(hex:sub(3), 16) }
                i = i + #hex
            elseif bin then
                tokens[#tokens + 1] = { t = "num", v = tonumber(bin:sub(3), 2) }
                i = i + #bin
            else
                local num = src:match("^%d*%.?%d*[eE][%+%-]?%d+", i) or src:match("^%d*%.?%d*", i)
                tokens[#tokens + 1] = { t = "num", v = tonumber(num) }
                if not tokens[#tokens].v then error("bad number '" .. num .. "'", 0) end
                i = i + #num
            end
        elseif c:match("[%a_]") then
            local id = src:match("^[%a_][%w_]*", i)
            tokens[#tokens + 1] = { t = "id", v = id }
            i = i + #id
        elseif c == "\207" and src:sub(i, i + 1) == "\207\128" then
            tokens[#tokens + 1] = { t = "id", v = "pi" }
            i = i + 2
        elseif c:match("[%+%-%*/%%%^!%(%),]") then
            tokens[#tokens + 1] = { t = c }
            i = i + 1
        elseif c == "x" or c == "X" then
            tokens[#tokens + 1] = { t = "*" }
            i = i + 1
        else
            error("unexpected '" .. c .. "'", 0)
        end
    end
    return tokens
end

function M.eval(src, opts)
    opts = opts or {}
    src = tostring(src or "")
    src = src:gsub("\195\151", "*"):gsub("\195\183", "/"):gsub("\226\136\146", "-")
    local ok, result = pcall(function()
        local tokens = tokenize(src)
        if #tokens == 0 then error("empty expression", 0) end
        local pos = 1
        local F = funcs(opts)
        local depth = 0

        local function peek() return tokens[pos] end
        local function take(t)
            local tok = tokens[pos]
            if tok and (not t or tok.t == t) then pos = pos + 1 return tok end
        end

        local expr

        local function startsValue()
            local tok = peek()
            return tok and (tok.t == "num" or tok.t == "id" or tok.t == "(")
        end

        local function primary()
            local tok = take()
            if not tok then error("unexpected end", 0) end
            if tok.t == "num" then return tok.v end
            if tok.t == "(" then
                depth = depth + 1
                if depth > 50 then error("too many nested parentheses", 0) end
                local v = expr()
                if not take(")") then error("missing ')'", 0) end
                depth = depth - 1
                return v
            end
            if tok.t == "id" then
                local name = tok.v:lower()
                if peek() and peek().t == "(" and F[name] then
                    take("(")
                    local args = {}
                    if not take(")") then
                        repeat args[#args + 1] = expr() until not take(",")
                        if not take(")") then error("missing ')'", 0) end
                    end
                    return F[name](unpack(args))
                end
                if name == "ans" then return opts.ans or 0 end
                if CONST[name] then return CONST[name] end
                if opts.vars and opts.vars[tok.v] ~= nil then return opts.vars[tok.v] end
                if F[name] then error("function '" .. name .. "' needs (...)", 0) end
                error("unknown name '" .. tok.v .. "'", 0)
            end
            error("unexpected '" .. tok.t .. "'", 0)
        end

        local function postfix()
            local v = primary()
            while peek() and peek().t == "!" do take() v = fact(v) end
            return v
        end

        local unary
        local function power()
            local base = postfix()
            if take("^") then
                return base ^ unary() -- right associative, binds tighter than unary minus on the left
            end
            return base
        end
        function unary()
            if take("-") then return -unary() end
            if take("+") then return unary() end
            return power()
        end

        local function term()
            local v = unary()
            while true do
                local tok = peek()
                if tok and tok.t == "*" then take() v = v * unary()
                elseif tok and tok.t == "/" then
                    take()
                    local d = unary()
                    if d == 0 then error("division by zero", 0) end
                    v = v / d
                elseif tok and tok.t == "%" then
                    take()
                    local d = unary()
                    if d == 0 then error("division by zero", 0) end
                    v = v % d
                elseif tok and tok.t == "id" and tok.v:lower() == "mod" then
                    take()
                    local d = unary()
                    if d == 0 then error("division by zero", 0) end
                    v = v % d
                elseif startsValue() then
                    v = v * unary() -- implicit multiplication: 2pi, 3(4+1)
                else
                    return v
                end
            end
        end

        function expr()
            local v = term()
            while true do
                if take("+") then v = v + term()
                elseif take("-") then v = v - term()
                else return v end
            end
        end

        local v = expr()
        if pos <= #tokens then error("unexpected '" .. tostring(tokens[pos].v or tokens[pos].t) .. "'", 0) end
        return v
    end)
    if not ok then return nil, tostring(result) end
    if result ~= result then return nil, "undefined result" end
    return result
end

-- Display: integers without ".0", at most 12 significant digits
function M.format(v)
    if v == math.huge then return "inf" end
    if v == -math.huge then return "-inf" end
    if v == math.floor(v) and math.abs(v) < 1e15 then
        return string.format("%d", v)
    end
    local s = string.format("%.12g", v)
    return s
end

return M
