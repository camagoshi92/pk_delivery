-- Functions shared by client and server.
Delivery = {
    Jobs = {},
    Hooks = {},
}

local RESOURCE_NAME = GetCurrentResourceName()

-- Keys are the Config.Framework values, lists are the resource names to look for.
-- The TPZ resource is published as tpz_core; 'tzp-core' is accepted too.
local FRAMEWORK_RESOURCES = {
    { name = 'vorp', resources = { 'vorp_core' } },
    { name = 'rsg', resources = { 'rsg-core' } },
    { name = 'tzp', resources = { 'tpz_core', 'tzp-core' } },
}

function Delivery.Log(message, ...)
    if Config.Debug then
        print(('[%s] %s'):format(RESOURCE_NAME, message:format(...)))
    end
end

function Delivery.Warn(message, ...)
    print(('^3[%s] %s^7'):format(RESOURCE_NAME, message:format(...)))
end

function Delivery.Error(message, ...)
    print(('^1[%s] ERROR: %s^7'):format(RESOURCE_NAME, message:format(...)))
end

local function isStarted(resources)
    for _, resource in ipairs(resources) do
        if GetResourceState(resource) == 'started' then
            return true
        end
    end
    return false
end

function Delivery.DetectFramework()
    local wanted = Config.Framework
    if wanted == 'tpz' then wanted = 'tzp' end

    for _, framework in ipairs(FRAMEWORK_RESOURCES) do
        if wanted == framework.name then
            return framework.name
        end
        if wanted == 'auto' and isStarted(framework.resources) then
            return framework.name
        end
    end

    return nil
end

-- Data of a job's town, or nil if it does not exist or is disabled.
function Delivery.GetLocation(jobId, locationId)
    local config = Config.Jobs[jobId]
    local place = config and config.Locations[locationId]
    if not place or place.Enabled == false then
        return nil
    end
    return place
end

-- Formats a time in seconds for texts: 90 -> "1m 30s".
function Delivery.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds))
    local minutes = math.floor(seconds / 60)
    if minutes <= 0 then
        return ('%ds'):format(seconds)
    end
    if seconds % 60 == 0 then
        return ('%dm'):format(minutes)
    end
    return ('%dm %ds'):format(minutes, seconds % 60)
end

-- Extension points: Delivery.On('wagon:tick', function(session) ... end)
function Delivery.On(name, callback)
    Delivery.Hooks[name] = Delivery.Hooks[name] or {}
    table.insert(Delivery.Hooks[name], callback)
end

function Delivery.RunHook(name, ...)
    for _, callback in ipairs(Delivery.Hooks[name] or {}) do
        local ok, err = pcall(callback, ...)
        if not ok then
            Delivery.Error('hook %s: %s', name, tostring(err))
        end
    end
end
