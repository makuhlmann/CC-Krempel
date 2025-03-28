local dfpwm = require("cc.audio.dfpwm")
local speakers = { peripheral.find("speaker") }

local decoder = dfpwm.make_decoder()

local file = io.open("/var/servernoise.dfpwm", "r")
local data = file:read("*all")
file:close()

local buffer = decoder(data)

local function playChunk(chunk)
  local callbacks = {}
  
  for i, speaker in pairs(speakers) do
    table.insert(callbacks, function()
      speaker.playAudio(chunk, 2.0)
    end)
  end
  
  parallel.waitForAll(table.unpack(callbacks))
end

local function start()
  write("Servers go b")

  while true do
    write("r")
    while not playChunk(buffer) do
      os.pullEvent("speaker_audio_empty")
    end
  end
end

start()
