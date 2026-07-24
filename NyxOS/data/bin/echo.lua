-- /bin/echo.lua : prints the given text

local args = {...}
print(table.concat(args, " "))
