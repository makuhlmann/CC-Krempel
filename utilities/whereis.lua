local arg = ...

if arg == nil then
  print("Missing parameter")
  return
end

local path = shell.resolveProgram(arg)
if path == nil then
  return
end

print(path)
