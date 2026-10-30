if not fs.exists("/var") then fs.makeDir("/var") end
local path = "/var/todo.lua"
local function load()
    if not fs.exists(path) then return {} end
    local f = fs.open(path, "r")
    local data = textutils.unserialize(f.readAll()) or {}
    f.close()
    return data
end
local function save(list)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(list))
    f.close()
end
local args = { ... }
local cmd = args[1] or "list"
local list = load()
if cmd == "add" and args[2] then
    list[#list + 1] = { text = table.concat(args, " ", 2), done = false }
    save(list)
    print("Added #" .. #list)
elseif cmd == "done" and tonumber(args[2]) and list[tonumber(args[2])] then
    list[tonumber(args[2])].done = true
    save(list)
    print("Done.")
elseif cmd == "clear" then
    local keep = {}
    for _, item in ipairs(list) do if not item.done then keep[#keep + 1] = item end end
    save(keep)
    print("Removed finished items.")
elseif cmd == "list" then
    if #list == 0 then print("Nothing to do.") end
    for i, item in ipairs(list) do
        term.setTextColor(item.done and colors.gray or colors.white)
        print(string.format("%2d [%s] %s", i, item.done and "x" or " ", item.text))
    end
    term.setTextColor(colors.white)
else
    print("Usage: todo add <text> | list | done <n> | clear")
end
