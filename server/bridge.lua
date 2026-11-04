-- The only server-side place that knows the framework.
--
-- Common interface:
--   Bridge.GetPlayer(src)                    -> character object or nil
--   Bridge.GetIdentifier(src)                -> stable character string or nil
--   Bridge.AddMoney(src, amount, currency)   -> boolean ('cash' | 'gold')
--   Bridge.AddItem(src, item, count)         -> boolean
--   Bridge.CanCarry(src, item, count)        -> boolean
--   Bridge.IsAlive(src)                      -> boolean
--   Bridge.SupportsCurrency(currency)        -> boolean
--   Bridge.GetJob(src)                       -> job name, grade
--   Bridge.GetFactionRow(src)                -> table, id column, character id value
--   Bridge.GetFaction(src)                   -> faction read from the database or nil
Bridge = {}

local Frameworks = {}

-- VORP: APIs verified against vorp_core/server and vorp_inventory/server.
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

    -- addItem does not check capacity: always call CanCarry first.
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

-- RSG: names taken from jo_libs (rsg-core_v2) and tp_libs (rsg.lua). Tested in game.
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
        -- Death metadata field on RSG.
        return player.PlayerData.metadata == nil or player.PlayerData.metadata.isdead ~= true
    end

    function Bridge.SupportsCurrency(currency)
        -- No reliable "gold" currency on RSG, so it pays in cash.
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
        -- Characters table on RSG.
        return 'players', 'citizenid', player.PlayerData.citizenid
    end
end

-- TZP: names taken from tp_libs/server/frameworks/tpzcore.lua. Not tested in game yet.
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
        -- TO VERIFY: tp_libs does not expose the death state. Death comes from the client bridge.
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
        -- TO VERIFY: characters table on TZP.
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

-- The column is optional: if it is missing or unreadable the error shows once and no
-- faction is valid, while job checks keep working.
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
            Delivery.Error('column %s of %s not readable: %s', column, tableName, tostring(faction))
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
    Delivery.Error('server bridge not initialized (%s): jobs stay disabled.', tostring(err))
    unavailable()
end
