-- /bin/tsort.lua : merges stacks and packs the turtle inventory
if not turtle then print("Not a turtle.") return end
dofile("/lib/turtlekit.lua").sort()
print("Inventory sorted.")
