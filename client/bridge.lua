-- The only client-side place that knows the framework.
--
-- Common interface:
--   Bridge.IsLoaded()            -> boolean, character loaded
--   Bridge.OnLoaded(callback)    -> character loaded
--   Bridge.OnDeath(callback)     -> player died
--   Bridge.OnRespawn(callback)   -> player back in game
Bridge = {}

local loaded = false
local loadedCallbacks = {}
local deathCallbacks = {}
local respawnCallbacks = {}

local function setLoaded()
    if loaded then return end
    loaded = true
    for _, callback in ipairs(loadedCallbacks) do
        callback()
    end
end

local function fire(callbacks)
    for _, callback in ipairs(callbacks) do
        callback()
    end
end

-- RSG and TZP have no verified death event here: the ped is watched instead. Applies to every framework.
local function watchDeath()
    CreateThread(function()
        local wasDead = false
        while true do
            local isDead = IsEntityDead(PlayerPedId())
            if isDead and not wasDead then
                fire(deathCallbacks)
            elseif wasDead and not isDead then
                fire(respawnCallbacks)
            end
            wasDead = isDead
            Wait(1000)
        end
    end)
end

local Frameworks = {
    -- Verified against vorp_core/client and vorp_core/server/class/user.lua.
    vorp = function()
        RegisterNetEvent('vorp:SelectedCharacter', setLoaded)
        RegisterNetEvent('vorp_core:Client:OnPlayerDeath', function() fire(deathCallbacks) end)
        RegisterNetEvent('vorp_core:Client:OnPlayerRespawn', function() fire(respawnCallbacks) end)
    end,

    -- Event used by rsg-core. Tested in game on RSG.
    rsg = function()
        RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', setLoaded)
        watchDeath()
    end,

    -- Event taken from tp_libs and tpz_stables. Not tested in game on TPZ yet.
    tzp = function()
        RegisterNetEvent('tpz_core:isPlayerReady', setLoaded)
        watchDeath()
    end,
}

function Bridge.IsLoaded()
    return loaded
end

function Bridge.OnLoaded(callback)
    loadedCallbacks[#loadedCallbacks + 1] = callback
    if loaded then callback() end
end

function Bridge.OnDeath(callback)
    deathCallbacks[#deathCallbacks + 1] = callback
end

function Bridge.OnRespawn(callback)
    respawnCallbacks[#respawnCallbacks + 1] = callback
end

local framework = Delivery.DetectFramework()
if framework and Frameworks[framework] then
    Frameworks[framework]()
    Bridge.Name = framework
else
    Delivery.Error('framework not found: jobs stay disabled.')
end

-- After a resource restart the load events never arrive again: ask the server.
RegisterNetEvent('pk_delivery:client:characterState', function(isLoaded)
    if isLoaded then setLoaded() end
end)

CreateThread(function()
    while Bridge.Name and not loaded do
        TriggerServerEvent('pk_delivery:server:checkCharacter')
        Wait(5000)
    end
end)
