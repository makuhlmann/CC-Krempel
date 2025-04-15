local expect = require "cc.expect".expect
local wireless = {}

local debug = false
local side = ""

function wireless.init_modem(modem_side, debug_opt)
    expect(1, modem_side, "string")
    expect(2, debug_opt, "boolean")

    side = modem_side

    _G.network_devices.device[side].modem.open(0)
    debug = debug_opt
    if debug then print("[wireless_dummy/init_modem] loaded modem with dummy driver " .. side) end
end

function wireless.send_packet_raw(message)
    expect(1, message, "table")

    if debug then print("[wireless_dummy/send_packet_raw] start") end
    _G.network_devices.device[side].modem.transmit(0, 0, message)
    if debug then print("[wireless_dummy/send_packet_raw] done") end
end

function wireless.send_packet(dest_net, dest_id, protocol, payload)
    expect(1, dest_net, "number")
    expect(2, dest_id, "number")
    expect(3, protocol, "string")
    expect(4, payload, "boolean", "number", "string", "table", "nil")

    if debug then print("[wireless_dummy/send_packet] start") end

    _G.network_devices.device[side].modem.transmit(0, 0, { 
        _G.network_devices.device[side].network,   -- Source Network
        os.getComputerID(),                 -- Source ID
        dest_net,                           -- Destination Network
        dest_id,                            -- Destination ID
        20,                                 -- Hop counter
        0,                                  -- Distance counter
        protocol,                           -- Protocol string
        payload })                          -- Payload
    if debug then print("[wireless_dummy/send_packet] done") end
end

function wireless.parse_modem_message(event, network_parse_modem_message)
    expect(1, event, "table")
    expect(2, network_parse_modem_message, "function")
    
    _G.network_devices.device[side].driver.data["signal"] = event[7]

    if debug then print("[wireless_dummy/parse_modem_message] returning back to network function") end
    network_parse_modem_message(event)
end

function wireless.routine()
    return
end

function wireless.terminate()
    if debug then print("[wireless_dummy/terminate] bye") end
end

return wireless