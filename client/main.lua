-- NPCs, dialogs and life cycle of the active job on the client.
--
-- Every job registers with Delivery.RegisterJob(id, {
--     Start(payload, token, place)   start; token identifies this job, place is the town
--     Stop(outcome)           own cleanup; tracked blips and entities are removed by Delivery.Cleanup
--     Events = { name = function(data) end }   messages from the server
--     OnDeath()               optional
-- })
local Texts = Config.Texts

local Active = nil
local nextToken = 0
local Npcs = {}
local TalkPrompt = nil

function Delivery.RegisterJob(id, job)
    Delivery.Jobs[id] = job
end

function Delivery.IsActive(token)
    return Active ~= nil and Active.token == token
end

function Delivery.SendAction(action, data)
    TriggerServerEvent('pk_delivery:server:action', action, data)
end

-- The job is done: the pay is collected from the NPC, marked on the map.
function Delivery.SetAwaitingReturn()
    if not Active then return end
    Active.awaitingReturn = true
    Delivery.AddJobBlip(Active.place.Npc.Coords, Active.place.Npc.Blip)
end

local function stopActive(outcome)
    local active = Active
    if not active then return end

    Active = nil

    local job = Delivery.Jobs[active.id]
    if job.Stop then
        job.Stop(outcome)
    end
    Delivery.Cleanup()
end

RegisterNetEvent('pk_delivery:client:jobStarted', function(jobId, locationId, payload)
    local job = Delivery.Jobs[jobId]
    local place = Delivery.GetLocation(jobId, locationId)
    if not job or not place or Active then return end

    nextToken = nextToken + 1
    Active = { id = jobId, location = locationId, place = place, token = nextToken }
    job.Start(payload, nextToken, place)
end)

RegisterNetEvent('pk_delivery:client:jobEnded', function(jobId, outcome)
    if Active and Active.id == jobId then
        stopActive(outcome)
    end
end)

RegisterNetEvent('pk_delivery:client:jobEvent', function(jobId, name, data)
    if not Active or Active.id ~= jobId then return end

    local handler = Delivery.Jobs[jobId].Events[name]
    if handler then
        handler(data or {})
    end
end)

Bridge.OnDeath(function()
    if not Active then return end

    local job = Delivery.Jobs[Active.id]
    if job.OnDeath then
        job.OnDeath()
    end
    TriggerServerEvent('pk_delivery:server:died')
end)

-- A town can have its own lines; otherwise the job's ones apply.
local function openDialog(npc, dialogKey, buttons)
    local cityDialog = npc.place.Dialog or {}

    UI.Dialog({
        npc = npc.ped,
        name = npc.place.Npc.Name,
        tag = npc.place.Npc.Tag,
        lines = cityDialog[dialogKey] or Config.Jobs[npc.jobId].Dialog[dialogKey],
        buttons = buttons,
    })
end

local function talkTo(npc)
    if not Active then
        openDialog(npc, 'Offer', {
            {
                label = Texts.Accept,
                style = 'success',
                onSelect = function() TriggerServerEvent('pk_delivery:server:requestStart', npc.jobId, npc.locationId) end,
            },
            { label = Texts.Decline, style = 'danger' },
        })
        return
    end

    if Active.id ~= npc.jobId or Active.location ~= npc.locationId then
        UI.Notify('warning', Texts.OtherJobActive)
        return
    end

    if Active.awaitingReturn then
        openDialog(npc, 'Return', {
            {
                label = Texts.Collect,
                style = 'gold',
                onSelect = function() Delivery.SendAction('claim') end,
            },
        })
        return
    end

    openDialog(npc, 'Abandon', {
        { label = Texts.KeepGoing, style = 'success' },
        {
            label = Texts.Abandon,
            style = 'danger',
            onSelect = function() TriggerServerEvent('pk_delivery:server:cancel') end,
        },
    })
end

local function deleteNpc(npc)
    if npc.ped and DoesEntityExist(npc.ped) then
        DeleteEntity(npc.ped)
    end
    npc.ped = nil
end

-- Coordinates taken from the player are about one meter above the ground.
local NPC_GROUND_OFFSET = 1.0

local function spawnNpc(npc, config)
    local hash = Delivery.LoadModel(config.Model)
    if not hash then return end

    local coords = config.Coords
    local ped = CreatePed(hash, coords.x, coords.y, coords.z - NPC_GROUND_OFFSET, coords.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end

    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation: without it the ped is invisible
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    FreezeEntityPosition(ped, true)

    if config.Scenario and config.Scenario ~= '' then
        Delivery.StartScenario(ped, config.Scenario)
    end

    npc.ped = ped
end

-- Creates nearby NPCs and deletes far ones.
local function npcStreamLoop()
    while true do
        local coords = GetEntityCoords(PlayerPedId())
        for _, npc in ipairs(Npcs) do
            local distance = #(coords - npc.place.Npc.Coords.xyz)
            if distance <= Config.NpcSpawnDistance and not npc.ped then
                spawnNpc(npc, npc.place.Npc)
            elseif distance > Config.NpcSpawnDistance + 10.0 and npc.ped then
                deleteNpc(npc)
            end
        end
        Wait(1000)
    end
end

local function closestNpc(coords)
    for _, npc in ipairs(Npcs) do
        if npc.ped and #(coords - npc.place.Npc.Coords.xyz) <= Config.NpcTalkDistance then
            return npc
        end
    end
    return nil
end

local function talkPromptLoop()
    while true do
        local sleep = 500
        local ped = PlayerPedId()

        if not IsEntityDead(ped) and not IsPedInAnyVehicle(ped, false) then
            local npc = closestNpc(GetEntityCoords(ped))
            if npc then
                sleep = 0
                TalkPrompt.Show(npc.place.Npc.Name)
                if TalkPrompt.Pressed() and not UI.IsDialogOpen() then
                    talkTo(npc)
                end
            end
        end

        Wait(sleep)
    end
end

Bridge.OnLoaded(function()
    if Config.Enabled == false then return end

    TalkPrompt = Delivery.NewPrompt(Config.Keys.Talk, Texts.TalkPrompt, Texts.Title)

    for jobId, config in pairs(Config.Jobs) do
        if config.Enabled ~= false and Delivery.Jobs[jobId] then
            for locationId in pairs(config.Locations) do
                local place = Delivery.GetLocation(jobId, locationId)
                if place then
                    local npc = { jobId = jobId, locationId = locationId, place = place }
                    Npcs[#Npcs + 1] = npc
                    if place.Npc.Blip and place.Npc.Blip.Enabled then
                        npc.blip = Delivery.CreateBlip(place.Npc.Coords, place.Npc.Blip)
                    end
                end
            end
        end
    end

    CreateThread(npcStreamLoop)
    CreateThread(talkPromptLoop)
end)

if Config.CancelCommand ~= '' then
    RegisterCommand(Config.CancelCommand, function()
        TriggerServerEvent('pk_delivery:server:cancel')
    end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    stopActive('resource_stop')
    for _, npc in ipairs(Npcs) do
        deleteNpc(npc)
        if npc.blip then RemoveBlip(npc.blip) end
    end
    Delivery.DeletePrompts()
end)
