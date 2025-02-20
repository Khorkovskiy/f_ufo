----------------------------
-- GLOBAL VARIABLES       --
----------------------------
local is_soundset_playing = false
local soundset_ref = "Ufos_Sounds"
local soundset_name = "Loop_A"
local UfoSpawned = false
local UfoEntity = 0
local playCount = 0
local hasUfoSpawnedOnce = Config.hasUfoSpawnedOnce   

----------------------------
-- HELPER FUNCTIONS       --
----------------------------
function GetNearbyPlayers(playerId, radius)
  local players = GetActivePlayers()
  local nearbyPlayers = {}
  local shooterCoords = GetEntityCoords(GetPlayerPed(playerId))
  for _, id in ipairs(players) do
    if id ~= playerId then
      local playerCoords = GetEntityCoords(GetPlayerPed(id))
      local distance = #(shooterCoords - playerCoords)
      if distance <= radius then
        table.insert(nearbyPlayers, GetPlayerServerId(id))
      end
    end
  end
  return nearbyPlayers
end

----------------------------
-- SOUND FUNCTIONS        --
----------------------------
function loadSoundSet(soundset)
  local counter = 1
  while not Citizen.InvokeNative(0xD9130842D7226045, soundset, 0) and counter <= 300 do
    counter = counter + 1
    Citizen.Wait(0)
  end
end

function playSound(soundName, x, y, z, soundset)
  Citizen.InvokeNative(0xCCE219C922737BFA, soundName, x, y, z, soundset, true, 0, true, 0)
end

function stopSound(soundset)
  Citizen.InvokeNative(0x531A78D6BF27014B, soundset)
end

----------------------------
-- MAIN THREAD            --
----------------------------
Citizen.CreateThread(function()
  while true do
    Citizen.Wait(500)
    local ped = PlayerPedId()
    local ped_coords = GetEntityCoords(ped)
    local distance = GetDistanceBetweenCoords(ped_coords, Config.ChurchCoords, false)
    local currentHour = GetClockHours() -- текущее игровое время (0-23)

    -- Проверяем, что текущее время в разрешённом интервале
    if currentHour >= Config.SpawnTime.start and currentHour < Config.SpawnTime.finish then
      if distance < 5.0 then
        -- Добавляем условие: UFO еще не заспавнился ранее
        if not is_soundset_playing and not UfoSpawned and not hasUfoSpawnedOnce then
          if math.random(100) <= (Config.SpawnChance * 100) then
            local playerId = PlayerId()
            local nearbyPlayers = GetNearbyPlayers(playerId, 250.0)
            if #nearbyPlayers == 0 then
              local counter_i = 1
              while soundset_ref ~= 0 and not Citizen.InvokeNative(0xD9130842D7226045, soundset_ref, 0) and counter_i <= 300 do
                counter_i = counter_i + 1
                Citizen.Wait(0)
              end

              if soundset_ref == 0 or Citizen.InvokeNative(0xD9130842D7226045, soundset_ref, 0) then
                local ped = PlayerPedId()
                local ped_coords = GetEntityCoords(ped)
                local x, y, z = table.unpack(ped_coords + GetEntityForwardVector(ped) * 15.0)
                playSound(soundset_name, 1459.53076171875, 813.67529296875, 118.3720703125, soundset_ref)
                is_soundset_playing = true
                playCount = playCount + 1
                StarUfo()
                hasUfoSpawnedOnce = true  -- UFO заспавнился, дальнейшие спавны запрещены
              end
            end
          end
        end
      else
        if is_soundset_playing then
          is_soundset_playing = false
          stopSound(soundset_ref)
          playCount = 0
          Citizen.Wait(200)
          if UfoSpawned then
            UFO_Exit()
          end
        end
      end
    else
      -- Если не в разрешенном временном интервале
      if is_soundset_playing then
        is_soundset_playing = false
        stopSound(soundset_ref)
        playCount = 0
        Citizen.Wait(200)
        if UfoSpawned then
          UFO_Exit()
        end
      end
    end
  end
end)

----------------------------
-- UFO SPAWN FUNCTION     --
----------------------------
function StarUfo()
  local endcoords = vector3(1459.53076171875, 813.67529296875, 118.3720703125)
  local startcoords = vector3(1459.53076171875, 813.67529296875, 200.3720703125)
  local modelHash = GetHashKey('s_ufo02x')

  RequestModel(modelHash)
  while not HasModelLoaded(modelHash) do
    Wait(0)
  end

  local obj = CreateObject(modelHash, startcoords.x, startcoords.y, startcoords.z, false, false, false)

  -- Плавное перемещение UFO к конечной точке
  local duration = 1500 -- длительность перемещения (мс)
  local startTime = GetGameTimer()
  UfoEntity = obj
  while true do
    local now = GetGameTimer()
    local progress = math.min((now - startTime) / duration, 1.0)

    local newX = startcoords.x + (endcoords.x - startcoords.x) * progress
    local newY = startcoords.y + (endcoords.y - startcoords.y) * progress
    local newZ = startcoords.z + (endcoords.z - startcoords.z) * progress

    SetEntityCoords(obj, newX, newY, newZ, false, false, false, true)

    if progress >= 1.0 then
      break
    end

    Citizen.Wait(0)
  end

  -- Поток для покачивания и вращения UFO (имитация движения летающей тарелки)
  Citizen.CreateThread(function()
    local swayAmplitude = 0.5   -- амплитуда колебаний по оси Z
    local swayFrequency = 1.0   -- частота осцилляций (Гц)
    local rotationSpeed = 35.0  -- скорость вращения (градусов в секунду)
    local finalCoords = endcoords -- базовая конечная позиция
    local baseHeading = GetEntityHeading(obj)

    while UfoEntity and DoesEntityExist(obj) do
      local timeSec = GetGameTimer() / 1000.0 -- время в секундах
      local swayOffset = math.sin(timeSec * swayFrequency * 2 * math.pi) * swayAmplitude
      SetEntityCoords(obj, finalCoords.x, finalCoords.y, finalCoords.z + swayOffset, false, false, false, true)
      local newHeading = (baseHeading + timeSec * rotationSpeed) % 360
      SetEntityHeading(obj, newHeading)
      Citizen.Wait(0)
    end
  end)

  UfoSpawned = true
end

----------------------------
-- UFO EXIT FUNCTION      --
----------------------------
function UFO_Exit()
  local startcoords = vector3(1459.53076171875, 813.67529296875, 118.3720703125) -- текущее положение UFO
  local endcoords = vector3(1459.53076171875, 813.67529296875, 200.3720703125)   -- конечная позиция (уход вверх)
  local obj = UfoEntity

  if not obj or not DoesEntityExist(obj) then
    return
  end

  local duration = 1500 -- длительность анимации ухода (мс)
  local startTime = GetGameTimer()
  UfoEntity = nil

  while true do
    local now = GetGameTimer()
    local progress = math.min((now - startTime) / duration, 1.0)

    local newX = startcoords.x + (endcoords.x - startcoords.x) * progress
    local newY = startcoords.y + (endcoords.y - startcoords.y) * progress
    local newZ = startcoords.z + (endcoords.z - startcoords.z) * progress

    SetEntityCoords(obj, newX, newY, newZ, false, false, false, true)

    if progress >= 1.0 then
      DeleteEntity(obj)
      UfoSpawned = false
      break
    end

    Citizen.Wait(0)
  end
end
