-- Example NyxOS package: "hello"
-- Can be installed with:
--   apt install https://.../paquet_hello/install.lua
--   apt install ./disk        (if this file sits at the disk's root)
--
-- Rule: every file written here IS automatically tracked by apt.
-- If written at the root ("hello.lua"), apt moves it into /bin.
-- If written to an absolute path (e.g. "/etc/hello.conf"), apt leaves
-- it where it is but still tracks it in the manifest (useful for
-- config, which is kept by "apt remove" and wiped by "apt purge").

local bin = fs.open("hello.lua", "w")
bin.write([[
print("Hello from the 'hello' package!")
]])
bin.close()

local conf = fs.open("/etc/hello.conf", "w")
conf.write("message=Hello\n")
conf.close()

print("Package 'hello' ready to be registered by apt.")
