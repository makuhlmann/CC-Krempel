local arg = ...

if not fs.exists(arg) then
  local file = fs.open(arg, "w")
  file.close()
end
