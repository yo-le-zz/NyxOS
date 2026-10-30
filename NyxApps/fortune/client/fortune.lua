local quotes = {
    "A computer is a bicycle for the mind.",
    "Turtles are just robots with better manners.",
    "It works on my computer. (id " .. os.getComputerID() .. ")",
    "There is no place like 127.0.0.1.",
    "Have you tried turning it off and on? (reboot)",
    "Tip: `man` lists every NyxOS command.",
    "Tip: right-click a desktop icon for its menu.",
    "Tip: the Paint app can set your wallpaper.",
    "Tip: `ping` works between NyxOS machines.",
    "Real programmers use rednet.",
    "Redstone: because wires are boring.",
    "The cake is a lie, the disk quota is not.",
}
math.randomseed(os.epoch("utc"))
print(quotes[math.random(#quotes)])
