-- Prompts, blips, markers and entities. Blips and entities created here are removed by Delivery.Cleanup().
local BLIP_STYLE = 1664425300
local BLIP_STYLE_ENTITY = 631964804

local jobBlips = {}
local jobEntities = {}
local prompts = {}

local function varString(text)
    return CreateVarString(10, 'LITERAL_STRING', text)
end

-- Prompt in its own group: Show must be called every frame it has to appear.
function Delivery.NewPrompt(control, label, groupLabel)
    local group = GetRandomIntInRange(0, 0xffffff)
    local handle = UiPromptRegisterBegin()
    UiPromptSetControlAction(handle, control)
    UiPromptSetText(handle, varString(label))
    UiPromptSetEnabled(handle, true)
    UiPromptSetVisible(handle, true)
    UiPromptSetStandardMode(handle, true)
    UiPromptSetGroup(handle, group, 0)
    UiPromptRegisterEnd(handle)

    prompts[#prompts + 1] = handle

    local prompt = {}

    function prompt.Show(title)
        UiPromptSetActiveGroupThisFrame(group, varString(title or groupLabel), 0, 0, 0, 0)
    end

    function prompt.Pressed()
        return UiPromptHasStandardModeCompleted(handle, 0)
    end

    return prompt
end

function Delivery.DeletePrompts()
    for _, handle in ipairs(prompts) do
        UiPromptDelete(handle)
    end
    prompts = {}
end

local function styleBlip(blip, config)
    if config.Sprite then
        SetBlipSprite(blip, joaat(config.Sprite), true)
    end
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, config.Name or '')
end

-- Permanent blip, not tied to a job.
function Delivery.CreateBlip(coords, config)
    local blip = BlipAddForCoords(BLIP_STYLE, coords.x, coords.y, coords.z)
    styleBlip(blip, config)
    return blip
end

function Delivery.AddJobBlip(coords, config)
    local blip = Delivery.CreateBlip(coords, config)
    jobBlips[blip] = true
    return blip
end

function Delivery.AddJobEntityBlip(entity, config)
    local blip = Citizen.InvokeNative(0x23f74c2fda6e7c61, BLIP_STYLE_ENTITY, entity)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, config.Name or '')
    jobBlips[blip] = true
    return blip
end

function Delivery.RemoveBlip(blip)
    if blip then
        jobBlips[blip] = nil
        RemoveBlip(blip)
    end
end

-- With radius the circle shows the valid area; without it, Config.Marker's size is used.
function Delivery.DrawMarker(coords, radius)
    local marker = Config.Marker
    local color = marker.Color
    local sizeX = radius and radius * 2.0 or marker.Size[1]
    local sizeY = radius and radius * 2.0 or marker.Size[2]
    Citizen.InvokeNative(
        0x2A32FAA57B937173, marker.Type,
        coords.x, coords.y, coords.z - 0.9,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        sizeX, sizeY, marker.Size[3],
        color.r, color.g, color.b, color.a,
        false, true, 2, false, false, false, false
    )
end

function Delivery.LoadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then
        Delivery.Error('model does not exist: %s', tostring(model))
        return nil
    end

    RequestModel(hash)
    local timeoutAt = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() >= timeoutAt then
            Delivery.Error('model not loaded: %s', tostring(model))
            return nil
        end
        Wait(10)
    end

    return hash
end

function Delivery.LoadAnim(dict)
    if dict == nil or dict == '' then
        return false
    end

    RequestAnimDict(dict)
    local timeoutAt = GetGameTimer() + 8000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() >= timeoutAt then
            Delivery.Error('animation not loaded: %s', dict)
            return false
        end
        Wait(10)
    end

    return true
end

function Delivery.PlayAnim(ped, anim)
    TaskPlayAnim(ped, anim.Dict, anim.Name, 4.0, -4.0, -1, anim.Flags or 1, 0, false, 0, false, 0, false)
end

function Delivery.StartScenario(ped, scenario)
    TaskStartScenarioInPlace(ped, joaat(scenario), -1, true, false, false, false)
end

-- Player scenario: holsters the weapon, clears tasks and retries until
-- the scenario actually starts (otherwise the ped just stands still).
function Delivery.StartPlayerScenario(ped, scenario, heading)
    local hash = joaat(scenario)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true, 0, false, false)
    ClearPedTasks(ped, true, false)
    Wait(100)

    for _ = 1, 3 do
        -- TASK_START_SCENARIO_IN_PLACE_HASH
        Citizen.InvokeNative(0x524B54361229154F, ped, hash, -1, true, 0, (heading or -1.0) + 0.0, false)
        local timeoutAt = GetGameTimer() + 1500
        while GetGameTimer() < timeoutAt do
            -- IS_PED_USING_ANY_SCENARIO
            if Citizen.InvokeNative(0x57AB4A3080F85143, ped) then
                return true
            end
            Wait(50)
        end
        ClearPedTasksImmediately(ped, true, true)
        Wait(100)
    end
    return false
end

-- Objects near (or attached to) the ped: used to find the broom the
-- scenario spawns by itself, which would otherwise stay on the ground.
function Delivery.SnapshotNearbyObjects(ped, radius)
    local seen = {}
    local origin = GetEntityCoords(ped)
    for _, object in ipairs(GetGamePool('CObject')) do
        if IsEntityAttachedToEntity(object, ped) or #(GetEntityCoords(object) - origin) <= radius then
            seen[object] = true
        end
    end
    return seen
end

-- Deletes objects that appeared near the ped after the snapshot.
function Delivery.DeleteNewNearbyObjects(ped, radius, before)
    local origin = GetEntityCoords(ped)
    for _, object in ipairs(GetGamePool('CObject')) do
        if not before[object] then
            local attachedToMe = IsEntityAttachedToEntity(object, ped)
            local looseNearby = not IsEntityAttached(object) and #(GetEntityCoords(object) - origin) <= radius
            if attachedToMe or looseNearby then
                if attachedToMe then
                    DetachEntity(object, true, false)
                end
                Delivery.DeleteEntity(object)
            end
        end
    end
end

function Delivery.TrackEntity(entity)
    jobEntities[entity] = true
    return entity
end

function Delivery.DeleteEntity(entity)
    jobEntities[entity] = nil
    if not entity or not DoesEntityExist(entity) then
        return
    end

    if NetworkGetEntityIsNetworked(entity) and not NetworkHasControlOfEntity(entity) then
        NetworkRequestControlOfEntity(entity)
        local timeoutAt = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeoutAt do
            Wait(10)
        end
    end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
end

function Delivery.AttachToPed(entity, ped, config)
    local bone = GetEntityBoneIndexByName(ped, config.Bone)
    local offset, rotation = config.Offset, config.Rotation
    -- With collision on, the object in hand lifts the character off the ground.
    SetEntityCollision(entity, false, false)
    AttachEntityToEntity(
        entity, ped, bone,
        offset.x, offset.y, offset.z,
        rotation.x, rotation.y, rotation.z,
        false, false, false, false, 1, true, false, false
    )
end

function Delivery.Cleanup()
    for blip in pairs(jobBlips) do
        RemoveBlip(blip)
    end
    jobBlips = {}

    local entities = jobEntities
    jobEntities = {}
    for entity in pairs(entities) do
        Delivery.DeleteEntity(entity)
    end
end
