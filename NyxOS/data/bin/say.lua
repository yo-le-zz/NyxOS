-- /bin/say.lua : sends a chat message (needs an Advanced Peripherals chat box)
-- Usage: say <message...>
local msg = table.concat({ ... }, " ")
if msg == "" then print("Usage: say <message>") return end
local ok, err = dofile("/lib/periph.lua").say(msg)
print(ok and "Sent." or ("say: " .. tostring(err)))
