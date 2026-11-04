-- Job 3: the timer starts when the player takes the reins; the server stays the referee.
local Cfg = Config.Wagon
local Texts = Cfg.Texts

local DRIVER_SEAT = -1
local LEAVE_TIMEOUT_MS = 4000
local GROUND_PROBE_HEIGHT = 2.0
local GROUND_ATTEMPTS = 20
local DEBUG_INTERVAL_MS = 2000

local state = nil
local DeliverPrompt = nil

local function ensurePrompt()
    if DeliverPrompt then return end
    DeliverPrompt = Delivery.NewPrompt(Config.Keys.Action, Texts.Prompt, Texts.PromptGroup)
end

-- SpawnOffset is relative to the spawn point: rotate it by its heading.
local function spawnCoords(entry, point)
    local offset = entry.SpawnOffset or vector3(0.0, 0.0, 0.0)
    local radians = math.rad(point.w)
    local cosine, sine = math.cos(radians), math.sin(radians)

    return vector4(
        point.x + offset.x * cosine - offset.y * sine,
        point.y + offset.x * sine + offset.y * cosine,
        point.z + offset.z,
        point.w
    )
end

local function loadCargo(wagon, entry)
    if entry.Propset and entry.Propset ~= '' then
        Citizen.InvokeNative(0x75F90E4051CC084C, wagon, joaat(entry.Propset))
    end

    for _, prop in ipairs(entry.Props or {}) do
        local hash = Delivery.LoadModel(prop.Model)
        if hash then
            local object = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
            SetModelAsNoLongerNeeded(hash)
            local offset, rotation = prop.Offset, prop.Rotation or vector3(0.0, 0.0, 0.0)
            AttachEntityToEntity(
                object, wagon, 0,
                offset.x, offset.y, offset.z,
                rotation.x, rotation.y, rotation.z,
                false, false, false, false, 1, true, false, false
            )
            Delivery.TrackEntity(object)
        end
    end
end

-- Coordinates taken from the player are about one meter above the ground.
local function groundZ(coords)
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + GROUND_PROBE_HEIGHT, false)
    return found and z or coords.z
end

-- Right after creation the collision may not be ready: retry until it works.
local function placeOnGround(wagon)
    for _ = 1, GROUND_ATTEMPTS do
        if SetVehicleOnGroundProperly(wagon) then
            return
        end
        Wait(100)
    end
    Delivery.Warn('wagon not placed on the ground: check SpawnPoint.')
end

local function spawnWagon(entry, spawnPoint)
    local hash = Delivery.LoadModel(entry.Model)
    if not hash then return nil end

    local coords = spawnCoords(entry, spawnPoint)
    local wagon = CreateVehicle(hash, coords.x, coords.y, groundZ(coords), coords.w, true, false, entry.Horses == false, false)
    SetModelAsNoLongerNeeded(hash)

    if not wagon or wagon == 0 then
        return nil
    end

    placeOnGround(wagon)
    SetEntityAsMissionEntity(wagon, true, true)
    loadCargo(wagon, entry)
    Delivery.Log('wagon %s, horse in harness: %s', entry.Model, tostring(Citizen.InvokeNative(0xA8BA0BAE0173457B, wagon, 0)))
    return Delivery.TrackEntity(wagon)
end

local function isDriving(ped)
    return IsPedInVehicle(ped, state.wagon, false) and GetPedInVehicleSeat(state.wagon, DRIVER_SEAT) == ped
end

local function wagonProblem(ped)
    if not DoesEntityExist(state.wagon) or IsEntityDead(state.wagon) then
        return 'destroyed'
    end
    if #(GetEntityCoords(ped) - GetEntityCoords(state.wagon)) > Cfg.AbandonDistance then
        return 'abandoned'
    end
    return nil
end

local function warnTimer()
    local remaining = (state.deadline - GetGameTimer()) / 1000
    for _, seconds in ipairs(Cfg.TimerWarnings) do
        if remaining <= seconds and not state.warned[seconds] then
            state.warned[seconds] = true
            UI.Notify('warning', Texts.TimerWarning:format(Delivery.FormatTime(remaining)), Cfg.Label)
        end
    end
end

-- The wagon counts, not the driver: with horses the vehicle is long and the driver sits in front.
local function deliveryFrame(ped, destination)
    local coords = vector3(destination.x, destination.y, destination.z)
    local distance = #(GetEntityCoords(state.wagon) - coords)
    if distance > Config.MarkerDrawDistance then
        return false
    end

    Delivery.DrawMarker(coords, Cfg.DestinationRadius)

    -- Delivery works from the seat or on foot next to the wagon: it just has to be stopped in the circle.
    local speed = GetEntitySpeed(state.wagon)
    local playerDistance = #(GetEntityCoords(ped) - GetEntityCoords(state.wagon))
    local canDeliver = distance <= Cfg.DestinationRadius
        and speed <= Cfg.MaxDeliverySpeed
        and playerDistance <= Cfg.DeliverPlayerDistance

    if Config.Debug and GetGameTimer() >= state.nextDebugAt then
        state.nextDebugAt = GetGameTimer() + DEBUG_INTERVAL_MS
        Delivery.Log('delivery: distance %.1f/%.1f, speed %.2f/%.2f, player %.1f/%.1f, on seat %s',
            distance, Cfg.DestinationRadius, speed, Cfg.MaxDeliverySpeed,
            playerDistance, Cfg.DeliverPlayerDistance, tostring(isDriving(ped)))
    end

    if canDeliver then
        DeliverPrompt.Show()
        if DeliverPrompt.Pressed() then
            Delivery.SendAction('deliver')
        end
    end

    return true
end

local function driveLoop(token)
    while Delivery.IsActive(token) do
        local sleep = 500
        local ped = PlayerPedId()
        local problem = wagonProblem(ped)

        if problem then
            Delivery.SendAction('fail', { reason = problem })
            sleep = 2000
        elseif not state.deadline then
            -- Repeated until the server confirms with timerStarted.
            if isDriving(ped) then
                Delivery.SendAction('seated')
                sleep = 2000
            end
        else
            warnTimer()
            if deliveryFrame(ped, state.destination.Coords) then
                sleep = 0
            end
        end

        Wait(sleep)
    end
end

Delivery.RegisterJob('wagon', {
    Start = function(payload, token, place)
        ensurePrompt()
        local entry = Cfg.Models[payload.model]
        state = {
            destination = place.Destinations[payload.destination],
            warned = {},
            nextDebugAt = 0,
        }

        CreateThread(function()
            local wagon = spawnWagon(entry, place.SpawnPoint)
            if not Delivery.IsActive(token) then
                if wagon then Delivery.DeleteEntity(wagon) end
                return
            end

            if not wagon then
                Delivery.SendAction('fail', { reason = 'spawn' })
                return
            end

            state.wagon = wagon
            Delivery.AddJobEntityBlip(wagon, Cfg.WagonBlip)
            Delivery.SendAction('spawned', { netId = NetworkGetNetworkIdFromEntity(wagon) })
            UI.Notify('info', Texts.Board, Cfg.Label)
            driveLoop(token)
        end)
    end,

    -- Get off before deleting the wagon, otherwise the player falls out of nowhere.
    Stop = function(outcome)
        local wagon = state and state.wagon
        state = nil
        if outcome == 'resource_stop' or not wagon or not DoesEntityExist(wagon) then return end

        local ped = PlayerPedId()
        if IsPedInVehicle(ped, wagon, false) then
            TaskLeaveVehicle(ped, wagon, 0)
            local timeoutAt = GetGameTimer() + LEAVE_TIMEOUT_MS
            while IsPedInVehicle(ped, wagon, false) and GetGameTimer() < timeoutAt do
                Wait(100)
            end
        end
    end,

    Events = {
        timerStarted = function(data)
            state.deadline = GetGameTimer() + data.seconds * 1000
            Delivery.AddJobBlip(state.destination.Coords, Cfg.DestinationBlip)
            local key = state.destination.Key
            UI.Notify('info', Texts.TimerStarted:format(Texts.Destinations[key] or key, Delivery.FormatTime(data.seconds)), Cfg.Label)
        end,
    },
})
