-- /bin/dd.lua : low-level file copy, dd-style
-- Usage: dd if=<source> of=<dest> [bs=<bytes>] [count=<n>]
--
-- Copies data from `if` (input file, or /dev/zero) to `of` (output
-- file, or /dev/null) in chunks of `bs` bytes (default 512), for
-- `count` chunks (default: until the input is exhausted). Works with
-- the /dev/null and /dev/zero special files (see /lib/nyxlib.lua).
--
-- Example: create a 10KB zero-filled file:
--   dd if=/dev/zero of=blank.bin bs=1024 count=10

local args = { ... }

local params = {}
for _, a in ipairs(args) do
    local key, value = a:match("^(%a+)=(.*)$")
    if key then
        params[key] = value
    end
end

local inputPath = params["if"]
local outputPath = params["of"]
local blockSize = tonumber(params.bs) or 512
local count = tonumber(params.count)

if not inputPath or not outputPath then
    print("Usage: dd if=<source> of=<dest> [bs=<bytes>] [count=<n>]")
    return
end

local inPath = shell.resolve(inputPath)
local outPath = shell.resolve(outputPath)
-- Keep /dev/null and /dev/zero literal -- they're not real filesystem
-- paths that shell.resolve should rewrite relative to the current dir.
if inputPath == "/dev/null" or inputPath == "/dev/zero" then inPath = inputPath end
if outputPath == "/dev/null" or outputPath == "/dev/zero" then outPath = outputPath end

local inFile = fs.open(inPath, "rb")
if not inFile then
    -- /dev/zero and text-mode fallback
    inFile = fs.open(inPath, "r")
end
if not inFile then
    print("dd: cannot open input: " .. inputPath)
    return
end

local outFile = fs.open(outPath, "wb")
if not outFile then
    outFile = fs.open(outPath, "w")
end
if not outFile then
    print("dd: cannot open output: " .. outputPath)
    inFile.close()
    return
end

local blocksCopied = 0
local bytesCopied = 0

while (not count) or blocksCopied < count do
    local chunk
    if inputPath == "/dev/zero" then
        chunk = string.rep("\0", blockSize)
    else
        chunk = inFile.read(blockSize)
    end

    if not chunk or chunk == "" then
        break
    end

    outFile.write(chunk)
    bytesCopied = bytesCopied + #chunk
    blocksCopied = blocksCopied + 1

    if #chunk < blockSize and inputPath ~= "/dev/zero" then
        break
    end
end

inFile.close()
outFile.close()

print(blocksCopied .. " block(s) copied (" .. bytesCopied .. " bytes).")
