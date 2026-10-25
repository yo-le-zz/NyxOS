-- /bin/neofetch.lua : system summary with the NyxOS logo

local nyxlib = dofile("/lib/nyxlib.lua")
local nyxdisplay = dofile("/lib/display.lua")
local themeOk, theme = pcall(dofile, "/lib/theme.lua")
local palette = colors or colours

local logo = {
    "   _   _            ___  ____",
    "  | \\ | |_   ___  __/ _ \\/ ___|",
    "  |  \\| | | | \\ \\/ / | | \\___ \\",
    "  | |\\  | |_| |>  <| |_| |___) |",
    "  |_| \\_|\\__, /_/\\_\\\\___/|____/",
    "         |__/",
}

local passwd = nyxlib.loadPasswd()
local manifest = nyxlib.loadManifest()

local pkgCount = 0
for _ in pairs(manifest) do pkgCount = pkgCount + 1 end

local cfg = nyxdisplay.loadConfig()
local screenInfo = "none"
if cfg.side then
    screenInfo = cfg.side .. (cfg.advanced and " (Advanced)" or " (standard)")
end

local info = {
    (passwd.username or "?") .. "@" .. nyxlib.getHostname(),
    "----------------",
    "OS      : NyxOS 1.0",
    "System  : " .. (_HOST or "ComputerCraft"),
    "ID      : " .. tostring(os.getComputerID()),
    "Packages: " .. pkgCount,
    "Screen  : " .. screenInfo,
}

local accent = nil
if themeOk and theme then
    local ok, a = pcall(theme.accent)
    if ok then accent = a end
end

for i = 1, math.max(#logo, #info) do
    if accent and logo[i] then
        pcall(term.setTextColor, accent)
        write(logo[i])
        pcall(term.setTextColor, palette.white)
        print("   " .. (info[i] or ""))
    else
        print((logo[i] or "") .. "   " .. (info[i] or ""))
    end
end
pcall(term.setTextColor, palette.white)
