-- Job 2: all crates start from a single point; the server counts the ones left.
local Cfg = Config.Crates
local Security = Config.Security

-- The crate in hand goes back to the pickup point or fails the job, as configured.
local function loseCarriedCrate(session)
    if not session.carrying then return end

    if Cfg.OnDrop == 'fail' then
        Delivery.FailSession(session, Cfg.Texts.Failed)
        return
    end

    session.carrying = false
    session.remaining = session.remaining + 1
    Delivery.SendEvent(session, 'crateReturned', { remaining = session.remaining })
end

Delivery.RegisterJob('crates', {
    Start = function(session)
        if Cfg.Count <= 0 then
            Delivery.Error('Config.Crates.Count must be greater than zero.')
            return nil
        end

        session.remaining = Cfg.Count
        session.delivered = 0
        session.carrying = false

        return { remaining = session.remaining }
    end,

    Actions = {
        pickup = function(session)
            if session.carrying or session.remaining <= 0 then return end

            if not Delivery.IsNear(session.src, session.place.PickupPoint, Cfg.InteractDistance) then
                Delivery.Suspect(session, 'crate picked up from too far')
                return
            end

            session.carrying = true
            session.remaining = session.remaining - 1
            session.carryStartedAt = GetGameTimer()
            Delivery.SendEvent(session, 'pickupApproved', { remaining = session.remaining })
        end,

        deliver = function(session)
            if not session.carrying then return end

            local pickup = session.place.PickupPoint
            local deliveryPoint = session.place.DeliveryPoint
            local walked = #(vector3(pickup.x, pickup.y, pickup.z) - deliveryPoint)
            local minimumMs = walked / Security.MaxCarrySpeed * 1000

            if Delivery.ElapsedMs(session.carryStartedAt) < minimumMs then
                Delivery.Suspect(session, 'crate delivered too fast')
                loseCarriedCrate(session)
                return
            end

            if not Delivery.IsNear(session.src, deliveryPoint, Cfg.DeliveryRadius) then
                Delivery.Suspect(session, 'delivery far from the store')
                loseCarriedCrate(session)
                return
            end

            session.carrying = false
            session.delivered = session.delivered + 1

            if session.delivered >= Cfg.Count then
                Delivery.CompleteSession(session, { elapsed = os.time() - session.startedAt })
            else
                Delivery.SendEvent(session, 'delivered', { done = session.delivered, total = Cfg.Count })
            end
        end,

        dropped = loseCarriedCrate,
    },

    -- Dying only loses the crate: after respawn the job can go on.
    OnDeath = loseCarriedCrate,
})
