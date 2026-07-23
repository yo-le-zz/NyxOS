local source = fs.getDir(shell.getRunningProgram())

local function copyRecursive(from, to)
    if fs.isDir(from) then
        fs.makeDir(to)

        for _, file in ipairs(fs.list(from)) do
            copyRecursive(
                fs.combine(from, file),
                fs.combine(to, file)
            )
        end
    else
        fs.copy(from, to)
    end
end


for _, file in ipairs(fs.list(source)) do
    if file ~= "install.lua" then
        copyRecursive(
            fs.combine(source, file),
            fs.combine("/", file)
        )
    end
end

print("RedioNet Server installé.")