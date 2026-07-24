# The `.nyx` scripting language

`.nyx` is NyxOS's own automation scripting language: a small mix of
shell scripting (running commands, variables) and old-style batch
scripting (labels + `goto` for control flow). It's meant to be readable
and writable by hand without learning Lua, for simple boot tasks,
install helpers, or personal automation.

This is **not** the same thing as the `nyxapi`/`toolkit` system: those
are Lua libraries your `.lua` *programs* call into (`dofile("/lib/nyxapi.lua")`);
`.nyx` is a standalone script file you run with `nyx myscript.nyx`, the
same way you'd run a `.sh` or `.bat` file.

## Running a script

```
nyx myscript.nyx [args...]
```

Arguments are available inside the script as `$1`, `$2`, ...

## Syntax reference

| Line                              | Meaning |
|------------------------------------|---------|
| `# comment` or `:: comment`        | Comment, ignored |
| `set NAME value`                   | Sets a variable |
| `$NAME` or `%NAME%`                | Expands to the variable's value, anywhere in a line |
| `echo text`                        | Prints text (with variables expanded) |
| `wait N`                           | Sleeps N seconds |
| `label NAME` or `NAME:`            | Declares a jump target |
| `goto NAME`                        | Jumps to a label |
| `if A op B goto NAME`              | Jumps to NAME if the comparison is true. `op` is one of `== != > < >= <=` |
| `call other.nyx`                   | Runs another .nyx script, then continues after it returns |
| `exit [code]`                      | Stops the script |
| anything else                      | Run as a NyxOS/CraftOS shell command line |

Any line that isn't one of the keywords above is executed exactly like
you typed it at the shell -- so ordinary commands (`apt`, `echo`,
`neofetch`, your own programs...) work as-is.

## Example: greeting with a variable

```
# greet.nyx
set NAME World
echo Hello, $NAME!
neofetch
```

## Example: a simple retry loop with goto

```
# retry.nyx
set ATTEMPTS 0

label try
set ATTEMPTS $ATTEMPTS
echo Attempt number $ATTEMPTS...
wait 1

if $ATTEMPTS == 3 goto done
set ATTEMPTS 1
goto try

label done
echo Done after 3 attempts.
```

*(Since `.nyx` has no arithmetic, count-based loops are usually driven
by comparing against a value you `set` at each step -- keep loops
simple, or drive them from a wrapping `.lua` script via `nyxscript.run`
if you need real math.)*

## Example: a small install helper

```
# setup.nyx
echo Setting up my tools...
apt tool install basalt
apt install cctchat client
echo All done!
```

See `exemples/nyx-scripts/` for these examples, ready to run with
`nyx exemples/nyx-scripts/greet.nyx`.
