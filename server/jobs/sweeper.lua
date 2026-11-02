-- Lavoro 1: il server estrae i punti e valida ogni pulizia.
local Cfg = Config.Sweeper
local Security = Config.Security

local function toPayload(point)
    return { x = point.x, y = point.y, z = point.z, h = point.w }
end

local function currentPoint(session, index)
    if tonumber(index) ~= session.index then
        return nil
    end
    return session.points[session.index]
end

local function finishJob(session)
    if Cfg.AutoPay then
        Delivery.CompleteSession(session)
        return
    end

    session.awaitingReturn = true
    Delivery.SendEvent(session, 'allDone')
end

Delivery.RegisterJob('sweeper', {
    Start = function(session)
        local points = Delivery.PickRandom(session.place.Points, Cfg.PointsPerJob)
        if #points == 0 then
            Delivery.Error('spazzino, citta %s: Points e vuota.', session.location)
            return nil
        end

        session.points = points
        session.index = 1
        session.workStartedAt = nil

        local payload = {}
        for index, point in ipairs(points) do
            payload[index] = toPayload(point)
        end
        return { points = payload }
    end,

    Actions = {
        begin = function(session, data)
            local point = currentPoint(session, data.index)
            if not point then return end

            if not Delivery.IsNear(session.src, point, Cfg.InteractDistance) then
                Delivery.Suspect(session, 'pulizia lontano dal punto %d', session.index)
                return
            end

            session.workStartedAt = GetGameTimer()
            Delivery.SendEvent(session, 'workApproved', { index = session.index })
        end,

        abort = function(session)
            session.workStartedAt = nil
        end,

        finish = function(session, data)
            local point = currentPoint(session, data.index)
            local startedAt = session.workStartedAt
            if not point or not startedAt then return end

            session.workStartedAt = nil

            if Delivery.ElapsedMs(startedAt) < Cfg.WorkDuration * 1000 * Security.MinWorkRatio then
                Delivery.Suspect(session, 'pulizia troppo veloce')
                return
            end

            if not Delivery.IsNear(session.src, point, Cfg.InteractDistance) then
                Delivery.Suspect(session, 'fine pulizia lontano dal punto %d', session.index)
                return
            end

            local done = session.index
            session.index = done + 1
            Delivery.SendEvent(session, 'pointDone', { done = done, total = #session.points })

            if done >= #session.points then
                finishJob(session)
            end
        end,

        claim = function(session)
            if session.awaitingReturn and Delivery.IsNear(session.src, session.place.Npc.Coords, Security.NpcDistance) then
                Delivery.CompleteSession(session)
            end
        end,
    },
})
