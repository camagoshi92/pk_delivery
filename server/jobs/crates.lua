-- Lavoro 2: tutte le casse partono da un unico punto; il server conta quelle rimaste.
local Cfg = Config.Crates
local Security = Config.Security

-- La cassa in mano torna al punto di ritiro oppure fa fallire il lavoro, come da config.
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
            Delivery.Error('Config.Crates.Count deve essere maggiore di zero.')
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
                Delivery.Suspect(session, 'cassa presa da lontano')
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
                Delivery.Suspect(session, 'cassa consegnata troppo in fretta')
                loseCarriedCrate(session)
                return
            end

            if not Delivery.IsNear(session.src, deliveryPoint, Cfg.DeliveryRadius) then
                Delivery.Suspect(session, 'consegna lontano dal negozio')
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

    -- Da morto si perde solo la cassa: dopo il respawn il lavoro puo continuare.
    OnDeath = loseCarriedCrate,
})
