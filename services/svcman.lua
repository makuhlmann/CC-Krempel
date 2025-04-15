local redrun = require("/lib/redrun")

redrun.init()
local svcman = {}
local arg_command, arg_service = ...
local svcsettings = settings.get("svcman.settings")

if svcsettings == nil then
  svcsettings = { autorun = {} }
end

function svcman.validate_path(name)
  local path = ""
  if fs.exists(name) then
    path = name
  elseif fs.exists(shell.resolveProgram(name)) then
    path = shell.resolveProgram(name)
  elseif fs.exists(shell.resolve(name)) then
    path = shell.resolve(name)
  end

  if path == "" then
    print("Could not find path of service " .. name)
    return nil
  end

  if path:sub(1, 1) ~= "/" then
    path = "/" .. path
  end

  if path:sub(-4, -1) == ".lua" then
    path = path:gsub(".lua", "")
  end
  
  return path
end

function svcman.start_service(name, silent)
  local path = nil
  for aname, apath in pairs(svcsettings.autorun) do
    if aname == name then
      path = apath
    end
  end
  
  if path == nil then
    path = svcman.validate_path(name)
    if path == nil then
      return nil
    end
  end

  local service = require(path)
  local init_response = service.init()
  if not init_response == true then
    if type(init_response) == "nil" then
      print("Service " .. name .. " failed to initialise with no error code")
      return
    end
    print("Service " .. name .. " failed to initialise with error code " .. init_response)
    return init_response
  end
  local id = redrun.start(service.run, name)
  if not silent then
    print("Service started with id " .. id)
  end
  return id
end

function svcman.stop_service(name, silent)
  local id = redrun.getid(name)
  if id == nil then
    if not silent then
      print("The service " .. name .. " is not running")
    end
    return 1
  end
  redrun.terminate(id)
  if not silent then
    print("Service stopped")
  end
  return 0
end

function svcman.kill_service(name)
  local id = redrun.getid(name)
  if id == nil then
    print("The service is not running")
    return 1
  end
  redrun.kill(id)
  print("Service stopped")
  return 0
end

function svcman.restart_service(name)
  svcman.stop_service(name)
  svcman.start_service(name)
end

function svcman.list_services()
  local env = getfenv(rednet.run)
  local output = ""
  for k, _ in pairs(svcsettings.autorun) do
    local id = redrun.getid(k)
    if id == nil then
      output = output .. k .. "\t\t\t" .. "stopped\n\r"
    else
      output = output .. k .. "\t\t\t" .. "running\n\r"
    end
  end
  if env.__redrun_coroutines then
    for k,v in pairs(env.__redrun_coroutines) do
      if not svcsettings.autorun[v.name] then
        output = output .. v.name .. "\t\t\t" .. "running\n\r"
      end
    end
  end
  if output == "" then
    print("No services running")
    return
  end
  write(" Service\t\t\tStatus\n\r-------------------------\n\r" .. output)
  print("")
end


function svcman.disable_service(name)
  for aname, _ in pairs(svcsettings.autorun) do
    if aname == name then
      svcsettings.autorun[k] = nil
      print("Service has been disabled")
      settings.set("svcman.settings", svcsettings)
      settings.save()
      return 0
    end
  end
  print("Service is not enabled")
  return 1
end

function svcman.enable_service(name)
  for aname, _ in pairs(svcsettings.autorun) do
    if aname == name then
      print("Service is already enabled")
      return 1
    end
  end
  
  local path = nil

  path = svcman.validate_path(name)

  if path == nil then
    return nil
  else
    svcsettings.autorun[name] = path
    print("Service has been enabled")
    settings.set("svcman.settings", svcsettings)
    settings.save()
    return 0
  end
  return 1
end

function svcman.autorun(silent)
  if silent == nil then
    silent = true
  end
  for aname, apath in pairs(svcsettings.autorun) do
    svcman.start_service(aname, silent)
  end
end

local commands = {
  ["start"] = svcman.start_service,
  ["stop"] = svcman.stop_service,
  ["restart"] = svcman.restart_service,
  ["kill"] = svcman.kill_service,
  ["list"] = svcman.list_services,
  ["disable"] = svcman.disable_service,
  ["enable"] = svcman.enable_service
}

if arg_command == nil then
  print("Usage: service [start|stop|restart|kill|list|enable|disable] <service name>")
  return
end

if commands[arg_command] then
  return commands[arg_command](arg_service)
end

if string.sub(arg_command, -6, -1) == "svcman" then
  return svcman
end

print("Unknown command \"" .. arg_command .. "\"")

