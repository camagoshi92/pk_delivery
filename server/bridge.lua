-- Unico punto del lato server che conosce il framework.
--
-- Interfaccia comune:
--   Bridge.GetPlayer(src)                    -> oggetto personaggio o nil
--   Bridge.GetIdentifier(src)                -> stringa stabile del personaggio o nil
--   Bridge.AddMoney(src, amount, currency)   -> boolean ('cash' | 'gold')
--   Bridge.AddItem(src, item, count)         -> boolean
--   Bridge.CanCarry(src, item, count)        -> boolean
--   Bridge.IsAlive(src)                      -> boolean
--   Bridge.SupportsCurrency(currency)        -> boolean
--   Bridge.GetJob(src)                       -> nome del job, grado
--   Bridge.GetFactionRow(src)                -> tabella, colonna id, valore id del personaggio
--   Bridge.GetFaction(src)                   -> fazione letta dal database o nil
Bridge = {}

local Frameworks = {}

-- VORP: API verificate su vorp_core/server e vorp_inventory/server di questo server.
function Frameworks.vorp()
    local Core = exports.vorp_core:GetCore()
    local CURRENCIES = { cash = 0, gold = 1 }

    function Bridge.GetPlayer(src)
        local user = Core.getUser(src)
        local character = user and user.getUsedCharacter
        if not character or not character.charIdentifier then
            return nil
        end
        return character
    end

    function Bridge.GetIdentifier(src)
        local character = Bridge.GetPlayer(src)
        return character and ('%s:%s'):format(character.identifier, character.charIdentifier) or nil
    end

    function Bridge.AddMoney(src, amount, currency)
        local character = Bridge.GetPlayer(src)
        if not character then return false end
        character.addCurrency(CURRENCIES[currency] or 0, amount)
        return true
    end

    -- addItem non controlla la capienza: va sempre preceduto da CanCarry.
    function Bridge.AddItem(src, item, count)
        return exports.vorp_inventory:addItem(src, item, count) ~= false
    end

    function Bridge.CanCarry(src, item, count)
        return exports.vorp_inventory:canCarryItem(src, item, count) == true
    end

    function Bridge.IsAlive(src)
        local character = Bridge.GetPlayer(src)
        return character ~= nil and character.isdead ~= true and character.isdead ~= 1
    end

    function Bridge.SupportsCurrency(currency)
        return CURRENCIES[currency] ~= nil
    end

    function Bridge.GetJob(src)
        local character = Bridge.GetPlayer(src)
        if not character then return nil, 0 end
        return character.job, tonumber(character.jobGrade) or 0
    end

    function Bridge.GetFactionRow(src)
        local character = Bridge.GetPlayer(src)
        if not character then return nil end
        return 'characters', 'charidentifier', character.charIdentifier
    end
end

-- RSG: nomi presi da jo_libs (rsg-core_v2) e tp_libs (rsg.lua). Non testato: rsg-core non e su questo server.
function Frameworks.rsg()
    local Core = exports['rsg-core']:GetCoreObject()

    function Bridge.GetPlayer(src)
        return Core.Functions.GetPlayer(src)
    end

    function Bridge.GetIdentifier(src)
        local player = Bridge.GetPlayer(src)
        return player and player.PlayerData.citizenid or nil
    end

    function Bridge.AddMoney(src, amount, currency)
        local player = Bridge.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(Bridge.SupportsCurrency(currency) and currency or 'cash', amount) ~= false
    end

    function Bridge.AddItem(src, item, count)
        local player = Bridge.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddItem(item, count) ~= false
    end

    function Bridge.CanCarry(src, item, count)
        return exports['rsg-inventory']:CanAddItem(src, item, count) == true
    end

    function Bridge.IsAlive(src)
        local player = Bridge.GetPlayer(src)
        if not player then return false end
        -- DA VERIFICARE: nome del campo metadata della morte su RSG.
        return player.PlayerData.metadata == nil or player.PlayerData.metadata.isdead ~= true
    end

    function Bridge.SupportsCurrency(currency)
        -- DA VERIFICARE: nessuna valuta "gold" certa su RSG, quindi si paga in contanti.
        return currency == 'cash'
    end

    function Bridge.GetJob(src)
        local player = Bridge.GetPlayer(src)
        if not player then return nil, 0 end
        local job = player.PlayerData.job
        return job.name, job.grade and tonumber(job.grade.level) or 0
    end

    function Bridge.GetFactionRow(src)
        local player = Bridge.GetPlayer(src)
        if not player then return nil end
        -- DA VERIFICARE: tabella dei personaggi su RSG.
        return 'players', 'citizenid', player.PlayerData.citizenid
    end
end

-- TZP: nomi presi da tp_libs/server/frameworks/tpzcore.lua. Non testato: tpz_core non e su questo server.
function Frameworks.tzp()
    local Core = exports.tpz_core:getCoreAPI()
    local ACCOUNTS = { cash = 0, gold = 1 }

    function Bridge.GetPlayer(src)
        local player = Core.GetPlayer(src)
        if player and player.loaded() then
            return player
        end
        return nil
    end

    function Bridge.GetIdentifier(src)
        local player = Bridge.GetPlayer(src)
        return player and ('%s:%s'):format(player.getIdentifier(), player.getCharacterIdentifier()) or nil
    end

    function Bridge.AddMoney(src, amount, currency)
        local player = Bridge.GetPlayer(src)
        if not player then return false end
        player.addAccount(ACCOUNTS[currency] or 0, amount)
        return true
    end

    function Bridge.AddItem(src, item, count)
        local player = Bridge.GetPlayer(src)
        if not player then return false end
        player.addItem(item, count)
        return true
    end

    function Bridge.CanCarry(src, item, count)
        local player = Bridge.GetPlayer(src)
        return player ~= nil and player.canCarryItem(item, count) == true
    end

    function Bridge.IsAlive(src)
        -- DA VERIFICARE: tp_libs non espone lo stato di morte. La morte arriva dal client bridge.
        return Bridge.GetPlayer(src) ~= nil
    end

    function Bridge.SupportsCurrency(currency)
        return ACCOUNTS[currency] ~= nil
    end

    function Bridge.GetJob(src)
        local player = Bridge.GetPlayer(src)
        if not player then return nil, 0 end
        return player.getJob(), tonumber(player.getJobGrade()) or 0
    end

    function Bridge.GetFactionRow(src)
        local player = Bridge.GetPlayer(src)
        if not player then return nil end
        -- DA VERIFICARE: tabella dei personaggi su TZP.
        return 'characters', 'charidentifier', player.getCharacterIdentifier()
    end
end

local function unavailable()
    Bridge.GetPlayer = function() return nil end
    Bridge.GetIdentifier = function() return nil end
    Bridge.AddMoney = function() return false end
    Bridge.AddItem = function() return false end
    Bridge.CanCarry = function() return false end
    Bridge.IsAlive = function() return false end
    Bridge.SupportsCurrency = function() return false end
    Bridge.GetJob = function() return nil, 0 end
    Bridge.GetFactionRow = function() return nil end
end

local factionColumnErrorShown = false

-- La colonna e facoltativa: se manca o non si legge, l'errore compare una volta e nessuna
-- fazione risulta valida, mentre i controlli sul job continuano a funzionare.
function Bridge.GetFaction(src)
    local column = Config.FactionAccess.Column
    local tableName, idColumn, id = Bridge.GetFactionRow(src)
    if not tableName or not column:match('^[%w_]+$') then
        return nil
    end

    local ok, faction = pcall(function()
        return MySQL.scalar.await(('SELECT `%s` FROM `%s` WHERE `%s` = ? LIMIT 1'):format(column, tableName, idColumn), { id })
    end)

    if not ok then
        if not factionColumnErrorShown then
            factionColumnErrorShown = true
            Delivery.Error('colonna %s di %s non leggibile: %s', column, tableName, tostring(faction))
        end
        return nil
    end

    return faction
end

local framework = Delivery.DetectFramework()
local load = framework and Frameworks[framework]
local ok, err = false, 'nessun framework trovato'

if load then
    ok, err = pcall(load)
end

if ok then
    Bridge.Name = framework
    Delivery.Log('framework server: %s', framework)
else
    Delivery.Error('bridge server non inizializzato (%s): i lavori restano disattivati.', tostring(err))
    unavailable()
end
