-- Stato dei lavori: unica fonte di verita. Il client chiede, il server decide.
--
-- Ogni lavoro si registra con Delivery.RegisterJob(id, {
--     Start(session)            -> payload per il client, oppure nil e testo d'errore
--     Actions = { nome = function(session, data) end }   richieste dal client
--     Tick(session)             facoltativo, ogni secondo
--     OnDeath(session)          facoltativo, di default il lavoro fallisce
--     OnEnd(session, outcome)   facoltativo, pulizia lato server
-- })
local Texts = Config.Texts
local Security = Config.Security

local Sessions = {}
local LastAction = {}

function Delivery.RegisterJob(id, job)
    Delivery.Jobs[id] = job
end

function Delivery.GetPlayerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

-- Vero se il giocatore e entro radius da coords, piu il margine di rete.
function Delivery.IsNear(src, coords, radius)
    local playerCoords = Delivery.GetPlayerCoords(src)
    if not playerCoords then
        return false
    end
    return #(playerCoords - vector3(coords.x, coords.y, coords.z)) <= radius + Security.DistanceMargin
end

function Delivery.SendEvent(session, name, data)
    TriggerClientEvent('pk_delivery:client:jobEvent', session.src, session.id, name, data)
end

function Delivery.Suspect(session, reason, ...)
    Delivery.Warn('azione rifiutata, giocatore %s, lavoro %s: %s', session.src, session.id, reason:format(...))
end

function Delivery.ElapsedMs(startedAt)
    return GetGameTimer() - startedAt
end

-- Mescola una copia della lista e ne restituisce i primi count elementi, senza ripetizioni.
function Delivery.PickRandom(list, count)
    local pool = {}
    for index, value in ipairs(list) do
        pool[index] = value
    end

    local picked = {}
    for index = 1, math.min(count, #pool) do
        local swap = math.random(index, #pool)
        pool[index], pool[swap] = pool[swap], pool[index]
        picked[index] = pool[index]
    end

    return picked
end

local function cooldownKey(charKey, jobId)
    return ('cooldown:%s:%s'):format(jobId, charKey)
end

-- Con i cooldown del lavoro a 0 non si aspetta, nemmeno se resta un'attesa gia salvata.
local function cooldownRemaining(charKey, jobId, cooldown)
    if (cooldown.Success or 0) <= 0 and (cooldown.Fail or 0) <= 0 then
        return 0
    end
    return math.max(0, GetResourceKvpInt(cooldownKey(charKey, jobId)) - os.time())
end

local function setCooldown(charKey, jobId, seconds)
    if seconds and seconds > 0 then
        SetResourceKvpInt(cooldownKey(charKey, jobId), os.time() + seconds)
    end
end

-- Chiude il lavoro una sola volta: il record sparisce prima di qualsiasi pagamento.
local function closeSession(session, outcome)
    if Sessions[session.src] ~= session then
        return false
    end

    Sessions[session.src] = nil

    local job = Delivery.Jobs[session.id]
    if job.OnEnd then
        job.OnEnd(session, outcome)
    end

    local cooldown = session.config.Cooldown or {}
    setCooldown(session.charKey, session.id, outcome == 'success' and cooldown.Success or cooldown.Fail)
    Delivery.Log('lavoro %s giocatore %s: %s', session.id, session.src, outcome)
    return true
end

local function notifyEnded(session, outcome)
    TriggerClientEvent('pk_delivery:client:jobEnded', session.src, session.id, outcome)
end

function Delivery.FailSession(session, message, outcome)
    outcome = outcome or 'failed'
    if closeSession(session, outcome) then
        notifyEnded(session, outcome)
        UI.Notify(session.src, 'error', message or Texts.Failed, session.config.Label)
    end
end

-- Unica via verso il pagamento. options come in Delivery.GiveReward.
function Delivery.CompleteSession(session, options)
    if closeSession(session, 'success') then
        notifyEnded(session, 'success')
        Delivery.GiveReward(session.src, session.place.Reward or session.config.Reward, session.config.Label, options)
    end
end

local function handleDeath(session)
    local job = Delivery.Jobs[session.id]
    if job.OnDeath then
        job.OnDeath(session)
    else
        Delivery.FailSession(session, Texts.Died)
    end
end

RegisterNetEvent('pk_delivery:server:checkCharacter', function()
    local src = source
    TriggerClientEvent('pk_delivery:client:characterState', src, Bridge.GetPlayer(src) ~= nil)
end)

RegisterNetEvent('pk_delivery:server:requestStart', function(jobId, locationId)
    local src = source
    local config = Config.Jobs[jobId]
    local job = Delivery.Jobs[jobId]
    local place = Delivery.GetLocation(jobId, locationId)

    if Config.Enabled == false or not config or not job or not place or config.Enabled == false then
        UI.Notify(src, 'error', Texts.Unavailable)
        return
    end

    if Sessions[src] then
        UI.Notify(src, 'warning', Texts.AlreadyActive)
        return
    end

    local charKey = Bridge.GetIdentifier(src)
    if not charKey then
        UI.Notify(src, 'error', Texts.Unavailable)
        return
    end

    if not Bridge.IsAlive(src) then
        UI.Notify(src, 'error', Texts.NotAlive)
        return
    end

    if not Delivery.IsNear(src, place.Npc.Coords, Security.NpcDistance) then
        UI.Notify(src, 'error', Texts.TooFar)
        return
    end

    if not Delivery.HasAccess(src, place) then
        UI.Notify(src, 'error', Texts.NoAccess, config.Label)
        return
    end

    local remaining = cooldownRemaining(charKey, jobId, config.Cooldown or {})
    if remaining > 0 then
        UI.Notify(src, 'warning', Texts.Cooldown:format(Delivery.FormatTime(remaining)), config.Label)
        return
    end

    local session = {
        src = src,
        id = jobId,
        config = config,
        location = locationId,
        place = place,
        charKey = charKey,
        startedAt = os.time(),
    }

    local payload, message = job.Start(session)
    if not payload then
        UI.Notify(src, 'error', message or Texts.Unavailable, config.Label)
        return
    end

    Sessions[src] = session
    TriggerClientEvent('pk_delivery:client:jobStarted', src, jobId, locationId, payload)
    UI.Notify(src, 'info', Texts.Started:format(config.Label), config.Label)
end)

RegisterNetEvent('pk_delivery:server:action', function(action, data)
    local src = source
    local session = Sessions[src]
    if not session then return end

    local now = GetGameTimer()
    if now - (LastAction[src] or 0) < Security.ActionThrottleMs then return end
    LastAction[src] = now

    local handler = Delivery.Jobs[session.id].Actions[action]
    if handler then
        handler(session, type(data) == 'table' and data or {})
    else
        Delivery.Suspect(session, 'azione sconosciuta %s', tostring(action))
    end
end)

RegisterNetEvent('pk_delivery:server:cancel', function()
    local src = source
    local session = Sessions[src]
    if not session then
        UI.Notify(src, 'warning', Texts.NoActiveJob)
        return
    end

    if closeSession(session, 'cancelled') then
        notifyEnded(session, 'cancelled')
        UI.Notify(src, 'warning', Texts.Cancelled, session.config.Label)
    end
end)

RegisterNetEvent('pk_delivery:server:died', function()
    local session = Sessions[source]
    if session then handleDeath(session) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local session = Sessions[src]
    if session then
        closeSession(session, 'disconnected')
    end
    LastAction[src] = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, session in pairs(Sessions) do
        local job = Delivery.Jobs[session.id]
        if job.OnEnd then
            job.OnEnd(session, 'resource_stop')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        for _, session in pairs(Sessions) do
            local job = Delivery.Jobs[session.id]
            if Bridge.GetIdentifier(session.src) ~= session.charKey then
                closeSession(session, 'disconnected')
                notifyEnded(session, 'disconnected')
            elseif not Bridge.IsAlive(session.src) then
                handleDeath(session)
            elseif job.Tick then
                job.Tick(session)
            end
        end
    end
end)
