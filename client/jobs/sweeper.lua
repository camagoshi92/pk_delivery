-- Job 1: points cleaned one at a time, with a scenario or a broom in hand and a progress bar.
local Cfg = Config.Sweeper
local Texts = Cfg.Texts

local MAX_WORK_DRIFT = 2.5

local state = nil
local SweepPrompt = nil
local InterruptPrompt = nil

local function ensurePrompts()
    if SweepPrompt then return end
    SweepPrompt = Delivery.NewPrompt(Config.Keys.Action, Texts.Prompt, Texts.PromptGroup)
    InterruptPrompt = Delivery.NewPrompt(Config.Keys.Interrupt, Config.Texts.Interrupt, Texts.PromptGroup)
end

local function showPointBlip(index)
    state.blips[index] = Delivery.AddJobBlip(state.points[index], Cfg.Blip)
end

local function refreshBlips()
    for index = state.index, #state.points do
        if (Cfg.ShowAllBlips or index == state.index) and not state.blips[index] then
            showPointBlip(index)
        end
    end
end

local PROP_CLEAN_RADIUS = 3.0

local function startWorkAnimation(ped, heading)
    if Cfg.Work.Mode ~= 'prop' then
        state.objectsBefore = Delivery.SnapshotNearbyObjects(ped, PROP_CLEAN_RADIUS)
        Delivery.StartPlayerScenario(ped, Cfg.Work.Scenario, heading)
        return
    end

    local prop = Cfg.Work.Prop
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true, 0, false, false)
    ClearPedTasks(ped, true, false)

    local hash = Delivery.LoadModel(prop.Model)
    if hash then
        local coords = GetEntityCoords(ped)
        state.broom = Delivery.TrackEntity(CreateObject(hash, coords.x, coords.y, coords.z, true, true, false))
        SetModelAsNoLongerNeeded(hash)
        Delivery.AttachToPed(state.broom, ped, prop)
    end

    local dict = (not IsPedMale(ped) and prop.DictFemale) or prop.Dict
    if Delivery.LoadAnim(dict) then
        state.anim = { Dict = dict, Name = prop.Name, Flags = prop.Flags }
        Delivery.PlayAnim(ped, state.anim)
        if state.broom and prop.PropAnim then
            -- PLAY_ENTITY_ANIM: the broom follows the body movement
            Citizen.InvokeNative(0xDC6D22FAB76D4874, state.broom, prop.PropAnim, dict, 1000.0, true, true, false, 0.0, 0)
        end
    end
end

-- Restarts the loop if something interrupts it (bump, light ragdoll).
local function keepPropAnim(ped)
    local anim = state and state.anim
    if anim and not IsEntityPlayingAnim(ped, anim.Dict, anim.Name, 3) then
        Delivery.PlayAnim(ped, anim)
    end
end

local function stopWorkAnimation(ped, objectsBefore)
    if state then state.anim = nil end
    if state and state.broom then
        DetachEntity(state.broom, true, false)
        Delivery.DeleteEntity(state.broom)
        state.broom = nil
    end

    if not objectsBefore then
        ClearPedTasks(ped)
        return
    end

    -- The scenario's own broom: removed before leaving the animation, then
    -- swept again for any broom dropped during the exit.
    Delivery.DeleteNewNearbyObjects(ped, PROP_CLEAN_RADIUS, objectsBefore)
    ClearPedTasksImmediately(ped, true, true)
    Wait(300)
    Delivery.DeleteNewNearbyObjects(ped, PROP_CLEAN_RADIUS, objectsBefore)
    Wait(700)
    Delivery.DeleteNewNearbyObjects(ped, PROP_CLEAN_RADIUS, objectsBefore)
end

-- The "working" scenario drifts a little while sweeping: wider tolerance.
local SCENARIO_WORK_DRIFT = 6.0

-- While the bar runs: the interrupt key, moving away or dying stop it.
-- In scenario mode, restarts the animation if it ends on its own.
local function watchInterrupt(token, ped, isDone, heading)
    CreateThread(function()
        local startCoords = GetEntityCoords(ped)
        local scenarioMode = Cfg.Work.Mode ~= 'prop'
        local maxDrift = scenarioMode and SCENARIO_WORK_DRIFT or MAX_WORK_DRIFT
        local nextCheckAt = GetGameTimer() + 1000

        while not isDone() do
            InterruptPrompt.Show()
            local interrupted = InterruptPrompt.Pressed()
                or IsEntityDead(ped)
                or not Delivery.IsActive(token)
                or #(GetEntityCoords(ped) - startCoords) > maxDrift

            if interrupted then
                UI.CancelProgress()
                return
            end

            if not scenarioMode and GetGameTimer() >= nextCheckAt then
                nextCheckAt = GetGameTimer() + 500
                keepPropAnim(ped)
            elseif scenarioMode and GetGameTimer() >= nextCheckAt then
                nextCheckAt = GetGameTimer() + 500
                -- IS_PED_USING_ANY_SCENARIO
                if not Citizen.InvokeNative(0x57AB4A3080F85143, ped) then
                    Citizen.InvokeNative(0x524B54361229154F, ped, joaat(Cfg.Work.Scenario), -1, false, 0, heading + 0.0, false)
                    nextCheckAt = GetGameTimer() + 1500
                end
            end
            Wait(0)
        end
    end)
end

local function doWork(token, index)
    local ped = PlayerPedId()
    local point = state.points[index]

    state.working = true
    SetEntityHeading(ped, point.h)
    startWorkAnimation(ped, point.h)
    local objectsBefore = state and state.objectsBefore
    if state then state.objectsBefore = nil end

    local done = false
    watchInterrupt(token, ped, function() return done end, point.h or GetEntityHeading(ped))
    local completed = UI.Progress(Texts.Progress, Cfg.WorkDuration)
    done = true

    stopWorkAnimation(ped, objectsBefore)
    if not Delivery.IsActive(token) then return end

    state.working = false
    if completed then
        Delivery.SendAction('finish', { index = index })
    else
        Delivery.SendAction('abort')
        UI.Notify('warning', Texts.Interrupted, Cfg.Label)
    end
end

local function workLoop(token)
    while Delivery.IsActive(token) do
        local sleep = 500
        local point = state.points[state.index]
        local ped = PlayerPedId()

        if point and not state.working and not IsEntityDead(ped) then
            local distance = #(GetEntityCoords(ped) - vector3(point.x, point.y, point.z))

            if distance <= Config.MarkerDrawDistance then
                sleep = 0
                Delivery.DrawMarker(point)
            end

            if distance <= Cfg.InteractDistance then
                SweepPrompt.Show()
                if SweepPrompt.Pressed() then
                    Delivery.SendAction('begin', { index = state.index })
                end
            end
        end

        Wait(sleep)
    end
end

Delivery.RegisterJob('sweeper', {
    Start = function(payload, token)
        ensurePrompts()
        state = { token = token, points = payload.points, index = 1, blips = {}, working = false }
        refreshBlips()
        UI.Notify('info', Texts.NextPoint, Cfg.Label)
        CreateThread(function() workLoop(token) end)
    end,

    Stop = function()
        if state and state.working then
            UI.CancelProgress()
        end
        state = nil
    end,

    OnDeath = function()
        UI.CancelProgress()
    end,

    Events = {
        workApproved = function(data)
            if state.working or data.index ~= state.index then return end
            local token = state.token
            CreateThread(function() doWork(token, data.index) end)
        end,

        pointDone = function(data)
            Delivery.RemoveBlip(state.blips[data.done])
            state.blips[data.done] = nil
            state.index = data.done + 1
            UI.Notify('success', Texts.PointDone:format(data.done, data.total), Cfg.Label)

            if data.done < data.total then
                refreshBlips()
            end
        end,

        allDone = function()
            Delivery.SetAwaitingReturn()
            UI.Notify('info', Config.Texts.ReturnToNpc, Cfg.Label)
        end,
    },
})
