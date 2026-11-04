-- Job 3: wagon transport. The server times the trip and checks the vehicle.
--
-- Extension points for cargo robbery (Config.Robbery), not implemented:
--   Delivery.On('wagon:departed', function(session) end)   player on the seat, timer started
--   Delivery.On('wagon:tick', function(session) end)       every second during the trip
--   Delivery.On('wagon:delivered', function(session) end)  before the payment
--   Delivery.On('wagon:ended', function(session, outcome) end)
-- session.cargo (0.0 to 1.0) is the share of cargo left and multiplies the pay:
-- lower it from a hook for a partial loss.
local Cfg = Config.Wagon
local Security = Config.Security

local BOARD_DISTANCE = 6.0

local CLIENT_FAILURES = {
    destroyed = Cfg.Texts.Destroyed,
    abandoned = Cfg.Texts.Abandoned,
    spawn = Cfg.Texts.SpawnFailed,
}

local function getWagon(session)
    if not session.netId then
        return nil
    end

    local entity = NetworkGetEntityFromNetworkId(session.netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end

    return nil
end

-- The netId can be reassigned after deletion: the model is checked too.
local function deleteWagon(netId, modelHash)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) and (GetEntityModel(entity) & 0xFFFFFFFF) == modelHash then
        DeleteEntity(entity)
    end
end

local function isWagonAt(entity, coords)
    local wagonCoords = GetEntityCoords(entity)
    return #(wagonCoords - vector3(coords.x, coords.y, coords.z)) <= Cfg.DestinationRadius + Security.DistanceMargin
end

Delivery.RegisterJob('wagon', {
    Start = function(session)
        if #Cfg.Models == 0 then
            Delivery.Error('Config.Wagon.Models is empty: add a model to enable the job.')
            return nil, Cfg.Texts.NoModels
        end

        local destinations = session.place.Destinations
        if #destinations == 0 then
            Delivery.Error('wagon, town %s: Destinations is empty.', session.location)
            return nil
        end

        local modelIndex = math.random(1, #Cfg.Models)
        local destinationIndex = math.random(1, #destinations)

        session.destination = destinations[destinationIndex]
        session.modelHash = GetHashKey(Cfg.Models[modelIndex].Model) & 0xFFFFFFFF
        session.cargo = 1.0
        session.boardDeadline = os.time() + Cfg.BoardSeconds

        return { model = modelIndex, destination = destinationIndex }
    end,

    Actions = {
        spawned = function(session, data)
            if session.netId then return end
            session.netId = tonumber(data.netId)
            Delivery.Log('wagon created, netId %s', tostring(session.netId))
        end,

        seated = function(session)
            if session.departedAt then return end

            local wagon = getWagon(session)
            if not wagon or not Delivery.IsNear(session.src, GetEntityCoords(wagon), BOARD_DISTANCE) then
                return
            end

            session.departedAt = os.time()
            session.deadline = session.departedAt + Cfg.MaxSeconds
            Delivery.SendEvent(session, 'timerStarted', { seconds = Cfg.MaxSeconds })
            Delivery.RunHook('wagon:departed', session)
        end,

        deliver = function(session)
            if not session.departedAt then return end

            local wagon = getWagon(session)
            local coords = session.destination.Coords
            if not wagon then return end

            if not isWagonAt(wagon, coords) or not Delivery.IsNear(session.src, GetEntityCoords(wagon), Cfg.DeliverPlayerDistance) then
                Delivery.Suspect(session, 'delivery far from the destination')
                return
            end

            Delivery.RunHook('wagon:delivered', session)
            Delivery.CompleteSession(session, { elapsed = os.time() - session.departedAt, multiplier = session.cargo })
        end,

        -- The client can only report a failure, never a success.
        fail = function(session, data)
            local message = CLIENT_FAILURES[data.reason]
            if message then
                Delivery.FailSession(session, message)
            end
        end,
    },

    Tick = function(session)
        local now = os.time()

        if not session.departedAt then
            if now >= session.boardDeadline then
                Delivery.FailSession(session, Cfg.Texts.BoardExpired)
            end
            return
        end

        if now >= session.deadline then
            Delivery.FailSession(session, Cfg.Texts.Expired)
            return
        end

        local wagon = getWagon(session)
        if not wagon then
            Delivery.FailSession(session, Cfg.Texts.Destroyed)
            return
        end

        local playerCoords = Delivery.GetPlayerCoords(session.src)
        if playerCoords and #(playerCoords - GetEntityCoords(wagon)) > Cfg.AbandonDistance then
            Delivery.FailSession(session, Cfg.Texts.Abandoned)
            return
        end

        Delivery.RunHook('wagon:tick', session)
    end,

    OnEnd = function(session, outcome)
        Delivery.RunHook('wagon:ended', session, outcome)

        local netId, modelHash = session.netId, session.modelHash
        if not netId then return end

        -- The client deletes the wagon; the server covers disconnects and unresponsive clients.
        if outcome == 'disconnected' or outcome == 'resource_stop' then
            deleteWagon(netId, modelHash)
        else
            SetTimeout(10000, function() deleteWagon(netId, modelHash) end)
        end
    end,
})

if Config.Robbery.enabled then
    Delivery.Warn('Config.Robbery.enabled is on, but cargo robbery is not implemented.')
end
