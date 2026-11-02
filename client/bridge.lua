-- Unico punto del lato client che conosce il framework.
--
-- Interfaccia comune:
--   Bridge.IsLoaded()            -> boolean, personaggio caricato
--   Bridge.OnLoaded(callback)    -> personaggio caricato
--   Bridge.OnDeath(callback)     -> giocatore morto
--   Bridge.OnRespawn(callback)   -> giocatore rientrato in gioco
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

-- RSG e TZP non hanno qui un evento di morte verificato: si osserva il ped. Vale per ogni framework.
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
    -- Verificati su vorp_core/client e vorp_core/server/class/user.lua.
    vorp = function()
        RegisterNetEvent('vorp:SelectedCharacter', setLoaded)
        RegisterNetEvent('vorp_core:Client:OnPlayerDeath', function() fire(deathCallbacks) end)
        RegisterNetEvent('vorp_core:Client:OnPlayerRespawn', function() fire(respawnCallbacks) end)
    end,

    -- Evento visto in world_pickups e tp_libs. DA VERIFICARE: rsg-core non e su questo server.
    rsg = function()
        RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', setLoaded)
        watchDeath()
    end,

    -- Evento visto in tp_libs e tpz_stables. DA VERIFICARE: tpz_core non e su questo server.
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
    Delivery.Error('framework non trovato: i lavori restano disattivati.')
end

-- Dopo un riavvio della risorsa gli eventi di caricamento non arrivano piu: lo chiede al server.
RegisterNetEvent('pk_delivery:client:characterState', function(isLoaded)
    if isLoaded then setLoaded() end
end)

CreateThread(function()
    while Bridge.Name and not loaded do
        TriggerServerEvent('pk_delivery:server:checkCharacter')
        Wait(5000)
    end
end)
