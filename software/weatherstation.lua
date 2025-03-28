-- Define light level tables
local lightLevels = {
    Clear = {
        {1, 4.331}, {2, 4.782}, {3, 5.07}, {4, 5.297}, {5, 5.53}, 
        {6, 5.768}, {7, 5.961}, {8, 6.167}, {9, 6.536}, {10, 6.934}, 
        {11, 7.372}, {12, 7.866}, {13, 8.445}, {14, 9.176}, {15, 10.295}, 
        {14, 13.706}, {13, 14.826}, {12, 15.557}, {11, 16.136}, {10, 16.629}, 
        {9, 17.067}, {8, 17.465}, {7, 17.835}, {6, 18.041}, {5, 18.233}, 
        {4, 18.471}, {3, 18.705}, {2, 18.931}, {1, 19.219}, {0, 19.67}
    },
    Rain = {
        {1, 4.331}, {2, 4.799}, {3, 5.232}, {4, 5.505}, {5, 5.746}, 
        {6, 5.992}, {7, 6.395}, {8, 6.883}, {9, 7.430}, {10, 8.07}, 
        {11, 8.876}, {12, 10.109}, {11, 13.892}, {10, 15.125}, {9, 15.931}, 
        {8, 16.571}, {7, 17.119}, {6, 17.607}, {5, 18.01}, {4, 18.256}, 
        {3, 18.497}, {2, 18.769}, {1, 19.203}, {0, 19.67}
    },
    Thunder = {
        {1, 4.331}, {2, 4.944}, {3, 5.353}, {4, 5.701}, {5, 6.06}, 
        {6, 6.442}, {7, 7.04}, {8, 7.736}, {9, 8.609}, {10, 9.943}, 
        {9, 14.059}, {8, 15.392}, {7, 16.266}, {6, 16.962}, {5, 17.560}, 
        {4, 17.941}, {3, 18.3}, {2, 18.648}, {1, 19.058}, {0, 19.67}
    }
}

-- Function to get the expected light level at a given timestamp
local function getLightLevel(weatherType, timestamp)
    local data = lightLevels[weatherType]
    local lastLevel = nil

    for i = 1, #data do
        local level, time = data[i][1], data[i][2]
        if timestamp < time then
            break
        end
        lastLevel = level
    end

    return lastLevel
end

-- Function to determine which weather condition matches the current light level best
local function determineWeather(timestamp, currentLightLevel)
    local bestWeather = nil
    local smallestDifference = math.huge
    
    local clear_level = getLightLevel("Clear", timestamp)
    local rain_level = getLightLevel("Rain", timestamp)
    local thunder_level = getLightLevel("Thunder", timestamp)
    
    if os.time() < 12.0 then
        if currentLightLevel == thunder_level then
            return "Thunder"
        elseif currentLightLevel == rain_level then
            return "Rain"
        elseif currentLightLevel == clear_level then
            return "Clear"
        end
    else
        if currentLightLevel == clear_level then
            return "Clear"
        elseif currentLightLevel == rain_level then
            return "Rain"
        elseif currentLightLevel == thunder_level then
            return "Thunder"
        end
    end
    return "Unknown"
end

local sensor_reading = 0
local weather = "Clear"

local modem = peripheral.wrap("back")
local send_ticks = 200

while true do
  if redstone.getAnalogInput("top") ~= sensor_reading then
    sensor_reading = redstone.getAnalogInput("top")
    if sensor_reading > 1 or (sensor_reading > 0 and os.time() > 12) then
        local new_weather = determineWeather(os.time(), sensor_reading)
        if new_weather ~= "Unknown" then
            weather = new_weather
        end
    end
    print(os.time() .. " - " .. sensor_reading .. " - " .. weather)
    modem.transmit(24, 0, weather)
  end
  if weather ~= "Thunder" and redstone.getAnalogInput("left") > 1 then
    weather = "Thunder"
    print(os.time() .. " - " .. sensor_reading .. " - " .. weather)
    modem.transmit(24, 0, weather)
  end
  os.sleep(0.05)
  send_ticks = send_ticks - 1
  if send_ticks <= 0 then
    modem.transmit(24, 0, weather)
    send_ticks = 200
  end
end