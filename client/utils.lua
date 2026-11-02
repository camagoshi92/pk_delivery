-- Prompt, blip, marker ed entita. Blip ed entita creati qui vengono eliminati da Delivery.Cleanup().
local BLIP_STYLE = 1664425300
local BLIP_STYLE_ENTITY = 631964804

local jobBlips = {}
local jobEntities = {}
local prompts = {}

local function varString(text)
    return CreateVarString(10, 'LITERAL_STRING', text)
end

-- Prompt in un suo gruppo: Show va chiamata ogni frame in cui deve comparire.
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

-- Blip permanente, non legato a un lavoro.
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

-- Con radius il cerchio mostra l'area valida; senza, usa la misura di Config.Marker.
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
        Delivery.Error('modello inesistente: %s', tostring(model))
        return nil
    end

    RequestModel(hash)
    local timeoutAt = GetGameTimer() + 8000
    while not HasModelLoaded(hash) do
        if GetGameTimer() >= timeoutAt then
            Delivery.Error('modello non caricato: %s', tostring(model))
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
            Delivery.Error('animazione non caricata: %s', dict)
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
    -- Con la collisione attiva l'oggetto in mano solleva il personaggio da terra.
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
