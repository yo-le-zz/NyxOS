-- CCTchat - Aides d'interface (couleurs / clear / saisie)

local M = {}

function M.clear()
    term.clear()
    term.setCursorPos(1, 1)
end

function M.print(text, color)
    term.setTextColor(color or colors.white)
    print(text)
    term.setTextColor(colors.white)
end

function M.header(title)
    M.clear()
    term.setTextColor(colors.lime)
    print("=========================================")
    print("   " .. title)
    print("=========================================")
    term.setTextColor(colors.white)
end

function M.ask(prompt)
    term.setTextColor(colors.yellow)
    write(prompt)
    term.setTextColor(colors.white)
    return read()
end

function M.askPassword(prompt)
    term.setTextColor(colors.yellow)
    write(prompt)
    term.setTextColor(colors.white)
    return read("*")
end

return M
