local expect = require "cc.expect".expect
local network = { terminated = false }
local default_conf = { modem = nil, network = 0, static = false, driver = { name = nil, instance = nil, data = nil }, routes = {}, max_hops = 20 }
local debug = false

function network.sleep(nTime)
    expect(1, nTime, "number", "nil")
    local timer = os.startTimer(nTime or 0)
    repeat
        local _, param = os.pullEventRaw("timer")
    until param == timer
end

-- Finds the best route for a packet, first direct routes, then default routes, else nil
function network.find_best_side(dest_net)
    expect(1, dest_net, "number")

    if debug then print("[find_best_side] start") end
    local first_default_device = nil
    for side, device in pairs(_G.network_devices.device) do
        for _, route in ipairs(device.routes) do
            if route == dest_net then
                if debug then print("[find_best_side] found direct side" .. side) end
                return side
            end
            if route == 0 and first_default_device == nil then
                if debug then print("[find_best_side] found default side" .. side) end
                first_default_device = side
            end
        end
    end
    if debug then print("[find_best_side] done") end
    return first_default_device
end

function network.send_packet(dest_net, dest_id, protocol, payload, side)
    expect(1, dest_net, "number")
    expect(2, dest_id, "number")
    expect(3, protocol, "string")
    expect(4, payload, "boolean", "number", "string", "table", "nil")
    expect(5, side, "string", "nil")

    if _G.network_devices == nil then
        error("Network service not initialized!")
    end

    if debug then print("[send_packet] start") end

    if side == nil then
        side = network.find_best_side(dest_net)
        if side == nil then
            if debug then print("[send_packet] no route found") end
            return false
        end
        if debug then print("[send_packet] found best side " .. side) end
    end

    if _G.network_devices.device[side].driver["instance"] ~= nil then
        -- Let the driver handle the sending and return the result
        if debug then print("[send_packet] passing to driver") end
        return _G.network_devices.device[side].driver["instance"].send_packet(dest_net, dest_id, protocol, payload, side)
    end
    _G.network_devices.device[side].modem.transmit(0, 0, { 
        _G.network_devices.device[side].network,   -- Source Network
        os.getComputerID(),                 -- Source ID
        dest_net,                           -- Destination Network
        dest_id,                            -- Destination ID
        20,                                 -- Hop counter
        0,                                  -- Distance counter
        protocol,                           -- Protocol string
        payload })                          -- Payload
    if debug then print("[send_packet] done") end
end

function network.receive_packet(protocol)
    expect(1, protocol, "string", "table")

    if _G.network_devices == nil then
        error("Network service not initialized!")
    end

    if debug then print("[receive_packet] start") end
    while true do
        for i, packet in ipairs(_G.network_devices.queue) do
            if type(protocol) == "string" then
                if packet.protocol == protocol then
                    if debug then print("[receive_packet] packet for " .. protocol .. " found and returned") end
                    table.remove(_G.network_devices.queue, i)
                    return packet
                end
            else
                for _, single_protocol in ipairs(protocol) do
                    if packet.protocol == single_protocol then
                        if debug then print("[receive_packet] packet for " .. protocol .. " found and returned") end
                        table.remove(_G.network_devices.queue, i)
                        return packet
                    end
                end
            end
        end
        sleep()
    end
end

-- Initializes modems and saves them in the global environment
function network.init_modem(name, wrapped)
    expect(1, name, "string")
    expect(2, wrapped, "table")

    if debug then print("[parse_modem_message] start " .. name) end
    if _G.network_devices.device[name] == nil then
        _G.network_devices.device[name] = default_conf
    end
    if _G.network_devices.device[name].driver["name"] ~= nil then
        if debug then print("[parse_modem_message] loading driver " .. name) end
        _G.network_devices.device[name].driver["instance"] = require(_G.network_devices.device[name].driver["name"])
        _G.network_devices.device[name].modem = wrapped
        _G.network_devices.device[name].driver["instance"].init_modem(debug)
    else
        if not wrapped.isWireless() then
            if debug then print("[parse_modem_message] load cable modem w/o driver " .. name) end
            _G.network_devices.device[name].modem = wrapped
            _G.network_devices.device[name].modem.open(0)
        end
    end
    if debug then print("[parse_modem_message] done") end
end

function network.parse_modem_message(event)
    expect(1, event, "table")

    if debug then print("[parse_modem_message] start") end
    local side = event[2]
    local message = event[5]
    local distance = event[6]
    local signal_strength = event[7]

    if type(message) == "table" then
        if debug then print("[parse_modem_message] validation 1 pass") end
        local src_net = message[1]
        local src_id = message[2]
        local dest_net = message[3]
        local dest_id = message[4]
        local hop_count = message[5]
        local distance_count = message[6]
        local protocol = message[7]
        local payload = message[8]

        if (dest_net ~= _G.network_devices.device[side].network or dest_id ~= os.getComputerID()) and _G.network_devices.settings.router then
            if debug then print("[parse_modem_message/routing] start") end

            if protocol == "discovery_req" then
                for _, route in ipairs(_G.network_devices.device[side].routes) do
                    if debug then print("[parse_modem_message/routing] discovery_req answered") end
                    network.send_packet(src_net, src_id, "discovery_ack", { ["network"] = route, ["routes"] = { 0 } }, side)
                end
                return
            end

            -- Modify hop count and add distance traversed
            message[5] = hop_count - 1
            message[6] = distance_count + distance

            if message[5] == 0 then
                if debug then print("[parse_modem_message/routing] hop count exceeded") end
                network.send_packet(src_net, src_id, "route_expire", nil)
                return
            end

            local route_side = network.find_best_side(dest_net)
            if route_side == nil then
                if debug then print("[parse_modem_message/routing] route not found") end
                network.send_packet(src_net, src_id, "route_notfound", nil)
                return
            end

            if debug then print("[parse_modem_message/routing] found best side " .. route_side) end

            if _G.network_devices.device[route_side].driver["instance"] ~= nil then
                -- Let the driver handle the sending and return the result
                if debug then print("[parse_modem_message/routing] passing to driver") end
                return _G.network_devices.device[route_side].driver["instance"].send_packet_raw(message, route_side)
            end

            _G.network_devices.device[route_side].modem.transmit(0, 0, message)

            if debug then print("[parse_modem_message/routing] done") end
            return
        end

        if protocol == "ping" then
            if debug then print("[parse_modem_message] parse ping + respond") end
                network.send_packet(src_net, src_id, "pong", payload, side)
            return
        end
        
        if protocol == "discovery_ack" then
            if debug then print("[parse_modem_message] parse discovery_ack + save") end
                _G.network_devices.device[side].network = payload.network
                _G.network_devices.device[side].routes = payload.routes
            return
        end

        local packet = {
            src_net = src_net,
            src_id = src_id,
            dest_net = dest_net,
            dest_id = dest_id,
            protocol = protocol,
            payload = payload,
            hop_count = hop_count,
            packet_distance = distance_count + distance,
            receive_distance = distance,
            signal_strength = signal_strength,
            timestamp = os.epoch("ingame")
        }

        if debug then print("[parse_modem_message] queue packet " .. textutils.serialise(packet, { allow_repetitions = true })) end

        table.insert(_G.network_devices.queue, packet)
        if debug then print("[parse_modem_message] queue size " .. #_G.network_devices.queue) end
        if #_G.network_devices.queue > 16 then
            table.remove(_G.network_devices.queue, 1)
            if debug then print("[parse_modem_message] discarded oldest packet") end
        end
        if debug then print("[parse_modem_message] end") end
    end
end

function network.save_config()
    if debug then print("[save_config] start") end
    local copy = _G.network_devices
    copy.queue = nil
    for side, _ in pairs(copy.device) do
        copy.device[side].driver["instance"] = nil
        copy.device[side].modem = nil
    end

    local config_file = fs.open("/.network", "w")
    config_file.write(textutils.serialise(copy, { allow_repetitions = true }))
    config_file.close()
    if debug then print("[save_config] end") end
end

function network.driver_routine_task()
    if debug then print("[driver_routine_task] start") end
    while not network.terminated do
        for side, device in pairs(_G.network_devices.device) do
            if device.modem ~= nil and device.driver["instance"] ~= nil then
                _G.network_devices.device[side].driver["instance"].routine()
            end
        end
        network.sleep(2)
    end
    if debug then print("[driver_routine_task] done") end
end

function network.discovery_task()
    if debug then print("[discovery_task] start") end
    local cooldown = 1
    while not network.terminated do
        cooldown = cooldown - 1
        if cooldown <= 0 then
            for side, device in pairs(_G.network_devices.device) do
                if device.modem ~= nil and device.network == 0 and device.static == false then
                    network.send_packet(0, 0, "discovery_req", nil, side)
                    if debug then print("[discovery_task] sent discovery_req on " .. side) end
                end
            end
            cooldown = 30
        end
        network.sleep(1)
    end
    if debug then print("[discovery_task] done") end
end

function network.event_listener_task()
    if debug then print("[event_listener_task] start") end
    local num = parallel.waitForAny(
        function()
            while not network.terminated do
                local event = { os.pullEventRaw("redrun_pause") }
                if debug then print("[event_listener_task/redrun_pause] " .. event[1]) end
                if event[1] ~= "terminate" or debug then
                    network.terminated = true
                    for side, _ in pairs(_G.network_devices.device) do
                        if _G.network_devices.device[side].driver["instance"] ~= nil then
                            _G.network_devices.device[side].driver["instance"].terminate()
                            _G.network_devices.device[side].driver["instance"] = nil
                        end
                        _G.network_devices.device[side].modem = nil
                    end
                    network.save_config()
                end
            end
        end,
        function()
            while not network.terminated do
                local event = { os.pullEventRaw("modem_message") }
                if debug then print("[event_listener_task/modem_message] " .. event[1]) end
                if event[1] ~= "terminate" then
                    local side = event[2]
                    if _G.network_devices.device[side].driver["instance"] ~= nil then
                        _G.network_devices.device[side].driver["instance"].parse_modem_message(event, network.parse_modem_message)
                    else
                        network.parse_modem_message(event)
                    end
                end
            end
        end,
        function ()
            while not network.terminated do
                local event = { os.pullEventRaw("peripheral_detach") }
                if debug then print("[event_listener_task/peripheral_detach] " .. event[1]) end
                if event[1] ~= "terminate" then
                    local side = event[2]
                    if peripheral.getType(side) == "modem" then
                        if _G.network_devices.device[side].driver["instance"] ~= nil then
                            _G.network_devices.device[side].driver["instance"].terminate()
                            _G.network_devices.device[side].driver["instance"] = nil
                        end
                        _G.network_devices.device[side].modem = nil
                    end
                end
            end
        end,
        function()
            while not network.terminated do
                local event = { os.pullEventRaw("peripheral") }
                if debug then print("[event_listener_task/peripheral] " .. event[1]) end
                if event[1] ~= "terminate" then
                    local side = event[2]
                    if peripheral.getType(side) == "modem" then
                        network.init_modem(side, peripheral.wrap(side))
                    end
                end
            end
        end
    )
    if num and debug then print("[event_listener_task] waitForAny ended " .. num) end
    if debug then print("[event_listener_task] done") end
end

-- == Service functions == --

-- Service Init
function network.init()
    if debug then print("[init] start") end
    if _G.network_devices == nil then
        _G.network_devices = { device = {
            ["bottom"] = default_conf,
            ["top"] = default_conf,
            ["left"] = default_conf,
            ["right"] = default_conf,
            ["front"] = default_conf,
            ["back"] = default_conf
        }, settings = {router = false} }
    end
    if fs.exists("/.network") then
        local file = fs.open("/.network", "r")
        _G.network_devices = textutils.unserialise(file.readAll())
        file.close()
        if debug then print("[init] loaded config") end
    end
    -- Non-static -> reset IP for autodiscover
    for side, device in pairs(_G.network_devices.device) do
        if not device.static then
            _G.network_devices.device[side].network = 0
            if debug then print("[init] reset ip on " .. side) end
        end
    end

    -- Initialize queue
    _G.network_devices["queue"] = {}

    -- Sends all modem interface to the init function
    peripheral.find("modem", network.init_modem)

    if debug then print("[init] done") end
    return true
end

-- Service Start
function network.run()
    parallel.waitForAll(network.event_listener_task,
                        network.discovery_task,
                        network.driver_routine_task)
end

-- Command line stuff

local arg_command = ...

if arg_command ~= nil and arg_command == "saveconf" then
    network.init()
    network.save_config()
    print("Configuration saved")
end

if arg_command ~= nil and arg_command == "debug" then
    debug = true
    network.init()
    network.run()
end

return network