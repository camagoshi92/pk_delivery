-- Lavoro 2: la cassa al punto di ritiro e visibile solo al giocatore e resta finche ne rimangono;
-- quella in mano e in rete, cosi la vedono tutti.
local Cfg = Config.Crates
local Texts = Cfg.Texts
local Carry = Cfg.Carry

local PICKUP_RETRY_MS = 1500

local state = nil
local PickupPrompt = nil
local DeliverPrompt = nil
local DropPrompt = nil

local function ensurePrompts()
    if PickupPrompt then return end
    PickupPrompt = Delivery.NewPrompt(Config.Keys.Action, Texts.PickupPrompt, Texts.PickupGroup)
    DeliverPrompt = Delivery.NewPrompt(Config.Keys.Action, Texts.DeliverPrompt, Texts.PickupGroup)
    DropPrompt = Delivery.NewPrompt(Config.Keys.Interrupt, Texts.DropPrompt, Texts.PickupGroup)
end

local function spawnPile()
    local point = state.pickupPoint
    local hash = Delivery.LoadModel(Cfg.Model)
    if not hash or not state then return end

    local object = CreateObject(hash, point.x, point.y, point.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(object, point.w)
    PlaceObjectOnGroundProperly(object)
    FreezeEntityPosition(object, true)
    state.pile = Delivery.TrackEntity(object)
end

-- La cassa al punto di ritiro c'e finche ne resta almeno una.
local function updatePile(remaining)
    state.remaining = remaining

    if remaining > 0 and not state.pile then
        spawnPile()
    elseif remaining <= 0 and state.pile then
        Delivery.DeleteEntity(state.pile)
        state.pile = nil
    end
end

local function startCarry(ped)
    local hash = Delivery.LoadModel(Cfg.Model)
    if not hash or not state then return end

    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true, 0, false, false)

    local coords = GetEntityCoords(ped)
    local object = CreateObject(hash, coords.x, coords.y, coords.z, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    state.carried = Delivery.TrackEntity(object)
    Delivery.AttachToPed(object, ped, Carry)

    if Delivery.LoadAnim(Carry.Anim.Dict) then
        Delivery.PlayAnim(ped, Carry.Anim)
    end
end

local function stopCarry(ped)
    ClearPedTasks(ped)
    if state and state.carried then
        Delivery.DeleteEntity(state.carried)
        state.carried = nil
    end
end

-- Va ripetuta ogni frame finche la cassa e in mano.
local function applyCarryRestrictions(ped)
    for _, control in ipairs(Carry.BlockedControls) do
        DisableControlAction(0, control, true)
    end
    DisablePlayerFiring(PlayerId(), true)

    if Carry.MoveRatio > 0 then
        SetPedMaxMoveBlendRatio(ped, Carry.MoveRatio)
    end

    if not IsEntityPlayingAnim(ped, Carry.Anim.Dict, Carry.Anim.Name, 3) then
        Delivery.PlayAnim(ped, Carry.Anim)
    end
end

local function putDownCrate(ped)
    state.busy = true
    Delivery.StartScenario(ped, Carry.PutDown.Scenario)
    Wait(Carry.PutDown.Duration)
    if state then
        Delivery.SendAction('deliver')
    end
end

local function dropCrate()
    state.busy = true
    Delivery.SendAction('dropped')
end

local function carryFrame(ped, coords)
    if state.busy then return end

    applyCarryRestrictions(ped)

    local distance = #(coords - state.deliveryPoint)
    if distance <= Config.MarkerDrawDistance then
        Delivery.DrawMarker(state.deliveryPoint)
    end

    if distance <= Cfg.DeliveryRadius then
        DeliverPrompt.Show()
        if DeliverPrompt.Pressed() then
            putDownCrate(ped)
        end
        return
    end

    DropPrompt.Show()
    if DropPrompt.Pressed() or (Cfg.DropOnRagdoll and IsPedRagdoll(ped)) then
        dropCrate()
    end
end

local function isAtPile(coords)
    local point = state.pickupPoint
    return state.pile ~= nil and #(coords - vector3(point.x, point.y, point.z)) <= Cfg.InteractDistance
end

local function jobLoop(token)
    while Delivery.IsActive(token) do
        local sleep = 300
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        if state.carrying then
            sleep = 0
            carryFrame(ped, coords)
        elseif GetGameTimer() >= state.nextPickupAt and not IsEntityDead(ped) then
            if isAtPile(coords) then
                sleep = 0
                PickupPrompt.Show()
                if PickupPrompt.Pressed() then
                    state.nextPickupAt = GetGameTimer() + PICKUP_RETRY_MS
                    Delivery.SendAction('pickup')
                end
            end
        end

        Wait(sleep)
    end
end

Delivery.RegisterJob('crates', {
    Start = function(payload, token, place)
        ensurePrompts()
        state = {
            pickupPoint = place.PickupPoint,
            deliveryPoint = place.DeliveryPoint,
            busy = false,
            nextPickupAt = 0,
        }

        Delivery.AddJobBlip(state.pickupPoint, Cfg.PickupBlip)
        Delivery.AddJobBlip(state.deliveryPoint, Cfg.DeliveryBlip)
        UI.Notify('info', Texts.GoPickup, Cfg.Label)

        CreateThread(function()
            updatePile(payload.remaining)
            jobLoop(token)
        end)
    end,

    Stop = function()
        if state and state.carried then
            ClearPedTasks(PlayerPedId())
        end
        state = nil
    end,

    Events = {
        pickupApproved = function(data)
            updatePile(data.remaining)
            state.carrying = true
            state.busy = false
            startCarry(PlayerPedId())
        end,

        delivered = function(data)
            stopCarry(PlayerPedId())
            state.carrying = nil
            state.busy = false
            UI.Notify('success', Texts.Delivered:format(data.done, data.total), Cfg.Label)
        end,

        crateReturned = function(data)
            stopCarry(PlayerPedId())
            state.carrying = nil
            state.busy = false
            updatePile(data.remaining)
            UI.Notify('warning', Texts.Returned, Cfg.Label)
        end,
    },
})
