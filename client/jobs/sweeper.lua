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

local function startWorkAnimation(ped)
    if Cfg.Work.Mode ~= 'prop' then
        Delivery.StartScenario(ped, Cfg.Work.Scenario)
        return
    end

    local prop = Cfg.Work.Prop
    local hash = Delivery.LoadModel(prop.Model)
    if hash then
        local coords = GetEntityCoords(ped)
        state.broom = Delivery.TrackEntity(CreateObject(hash, coords.x, coords.y, coords.z, true, true, false))
        SetModelAsNoLongerNeeded(hash)
        Delivery.AttachToPed(state.broom, ped, prop)
    end

    if Delivery.LoadAnim(prop.Dict) then
        Delivery.PlayAnim(ped, { Dict = prop.Dict, Name = prop.Name, Flags = prop.Flags })
    end
end

local function stopWorkAnimation(ped)
    ClearPedTasks(ped)
    if state and state.broom then
        Delivery.DeleteEntity(state.broom)
        state.broom = nil
    end
end

-- While the bar runs: the interrupt key, moving away or dying stop it.
local function watchInterrupt(token, ped, isDone)
    CreateThread(function()
        local startCoords = GetEntityCoords(ped)
        while not isDone() do
            InterruptPrompt.Show()
            local interrupted = InterruptPrompt.Pressed()
                or IsEntityDead(ped)
                or not Delivery.IsActive(token)
                or #(GetEntityCoords(ped) - startCoords) > MAX_WORK_DRIFT

            if interrupted then
                UI.CancelProgress()
                return
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
    startWorkAnimation(ped)

    local done = false
    watchInterrupt(token, ped, function() return done end)
    local completed = UI.Progress(Texts.Progress, Cfg.WorkDuration)
    done = true

    stopWorkAnimation(ped)
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
