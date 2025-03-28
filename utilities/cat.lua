local arg = ...

if arg == nil then
  print("Missing file name argument")
  return
end

if not fs.exists(shell.resolve(arg)) then
  print("File not found")
  return
end

local file = fs.open(shell.resolve(arg), "r")
print(file.readAll())
file.close()

