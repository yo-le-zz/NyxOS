local args = { ... }
local text = table.concat(args, " ")
if text == "" then text = "Moo! Give me something to say." end
local w = math.min(36, term.getSize() - 6)
local lines, line = {}, ""
for word in text:gmatch("%S+") do
    if #line + #word + 1 > w and line ~= "" then lines[#lines + 1] = line line = word
    else line = (line == "" and word or line .. " " .. word) end
end
lines[#lines + 1] = line
local width = 0
for _, l in ipairs(lines) do width = math.max(width, #l) end
print(" " .. string.rep("_", width + 2))
for i, l in ipairs(lines) do
    local a, b = "|", "|"
    if #lines == 1 then a, b = "<", ">" elseif i == 1 then a, b = "/", "\\" elseif i == #lines then a, b = "\\", "/" end
    print(a .. " " .. l .. string.rep(" ", width - #l) .. " " .. b)
end
print(" " .. string.rep("-", width + 2))
print("        \\   ^__^")
print("         \\  (oo)\\_______")
print("            (__)\\       )\\/\\")
print("                ||----w |")
print("                ||     ||")
