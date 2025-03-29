local network = require("/lib/network")
local pings = {}
local pongs = {}
local limit
local terminated = false

local net, id

local function finish()
    print("--- " .. net .. "-" .. id .. " ping statistics ---")
    print(#pings .. " packets transmitted, " .. #pongs .. " received, " .. string.format("%.1f", (1.0 - (#pongs / #pings)) * 100) .. "% packet loss")

    if #pongs > 0 then
        local min, max
        local total = 0

        for k, duration in ipairs(pongs) do
            if min == nil or duration < min then
                min = duration
            end
            if max == nil or duration > min then
                max = duration
            end
            total = total + duration
        end

        local avg = total / #pongs
        print("rtt min/avg/max = " .. string.format("%.1f", min / 3600.0) .. "/" .. string.format("%.1f", avg / 3600.0) .. "/" .. string.format("%.1f", max / 3600.0) .. " ticks")
    end
end

local function safe_sleep(nTime)
    local timer = os.startTimer(nTime or 0)
    repeat
        local event, param = os.pullEventRaw("timer")
        if event == "terminate" then
            terminated = true
            return
        end
    until param == timer
end

local function send_pings()
    while not terminated and limit ~= 0 do
        limit = limit - 1
        local send_time = os.epoch("ingame")
        local result = network.send_packet(net, id, "ping", send_time)
        table.insert(pings, send_time)
        if result == false then
            print("No route found for target " .. net .. "-" .. id)
        end
        safe_sleep(1)
    end
    finish()
end

local function receive_pongs()
    while not terminated do
        local packet = network.receive_packet({ "pong", "route_expire", "route_notfound" })
        if packet.protocol == "route_expire" then
            print("Response from " .. packet.src_net .. "-" .. packet.src_id .. ": TTL expired")
        elseif packet.protocol == "route_notfound" then
            print("Response from " .. packet.src_net .. "-" .. packet.src_id .. ": Route not found")
        else
            for k, send_time in ipairs(pings) do
                if packet.payload == send_time then
                    table.insert(pongs, packet.timestamp - send_time)
                    print("Response #" .. k .. " from " .. packet.src_net .. "-" .. packet.src_id .. ": ttl=" .. packet.hop_count .. " time=" .. string.format("%.1f", (packet.timestamp - send_time) / 3600.0) .. " ticks")
                end
            end
        end
    end
end

local args = {...}

if not args[1] then
    print("Usage: ping [ip] <count>")
end

net, id = args[1]:match("([^-]+)-([^-]+)")

net = tonumber(net)
id = tonumber(id)

if type(args[2]) ~= "nil" then
    limit = tonumber(args[2])
else
    limit = -1
end

print("PING " .. net .. "-" .. id .. " with " .. (limit == -1 and "infinite" or limit) .. " packets")

parallel.waitForAny(send_pings, receive_pongs)