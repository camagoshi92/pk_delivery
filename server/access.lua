-- Who can accept a job at a location. The check is server-side only.
--
-- Access = {
--     Jobs = { 'job_name', { Job = 'job_name', MinGrade = 2 } },
--     Factions = { 'Faction Name' },   -- true = any assigned faction
--     Mode = 'any',                    -- 'any': job OR faction; 'all': job AND faction
-- }
local function normalize(value)
    return tostring(value or ''):lower():match('^%s*(.-)%s*$')
end

local function matchesJob(src, jobs)
    local name, grade = Bridge.GetJob(src)
    name = normalize(name)

    for _, rule in ipairs(jobs) do
        local wanted = type(rule) == 'table' and rule.Job or rule
        local minimum = type(rule) == 'table' and rule.MinGrade or 0
        if name ~= '' and normalize(wanted) == name and (grade or 0) >= minimum then
            return true
        end
    end

    return false
end

local function isAssigned(faction)
    for _, value in ipairs(Config.FactionAccess.EmptyValues) do
        if faction == normalize(value) then
            return false
        end
    end
    return faction ~= ''
end

local function matchesFaction(src, factions)
    local faction = normalize(Bridge.GetFaction(src))

    if factions == true then
        return isAssigned(faction)
    end

    for _, wanted in ipairs(factions) do
        if isAssigned(faction) and normalize(wanted) == faction then
            return true
        end
    end

    return false
end

local function hasRules(rules)
    return rules == true or (type(rules) == 'table' and #rules > 0)
end

function Delivery.HasAccess(src, place)
    local access = place.Access
    if not access then
        return true
    end

    local checkJobs = hasRules(access.Jobs)
    local checkFactions = hasRules(access.Factions)
    if not checkJobs and not checkFactions then
        return true
    end

    local jobOk = checkJobs and matchesJob(src, access.Jobs)
    local factionOk = checkFactions and matchesFaction(src, access.Factions)

    if access.Mode == 'all' then
        return (jobOk or not checkJobs) and (factionOk or not checkFactions)
    end

    return jobOk or factionOk
end
