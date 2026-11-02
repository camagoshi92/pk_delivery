-- Tutti i testi della risorsa. La lingua si sceglie con Config.Locale.
-- Per aggiungere una lingua copia un blocco, cambia la chiave e traduci i valori:
-- le voci mancanti restano in italiano.
--
-- Common finisce in Config.Texts; ogni voce di Jobs si fonde col lavoro omonimo di Config.Jobs,
-- quindi ha la stessa struttura (Dialog, Texts, nomi dei blip).
-- Npc vale per tutte le citta del lavoro. Locations.<citta> sovrascrive una sola citta e puo
-- contenere Npc e Dialog: una citta nuova funziona anche senza voci qui.
-- Texts.Destinations del carretto usa le Key delle Destinations in config.lua.
Locales = {}

Locales.it = {
    Common = {
        Title = 'Lavori',
        TalkPrompt = 'Parla',
        Accept = 'Accetta',
        Decline = 'Rifiuta',
        Collect = 'Ritira la paga',
        Abandon = 'Rinuncia al lavoro',
        KeepGoing = 'Continuo',
        Interrupt = 'Interrompi',

        AlreadyActive = 'Hai gia un lavoro in corso.',
        OtherJobActive = 'Finisci prima il lavoro che hai in corso.',
        NoActiveJob = 'Non hai nessun lavoro in corso.',
        Cooldown = 'Non ho altro lavoro per te, torna tra %s.',
        TooFar = 'Sei troppo lontano.',
        NotAlive = 'Non puoi lavorare in queste condizioni.',
        NoAccess = 'Questo lavoro non e per te.',
        Unavailable = 'Questo lavoro non e disponibile al momento.',
        Started = 'Lavoro accettato: %s.',
        Cancelled = 'Hai rinunciato al lavoro.',
        Died = 'Sei morto: il lavoro e fallito.',
        Failed = 'Lavoro fallito.',
        ReturnToNpc = 'Hai finito: torna a ritirare la paga.',

        RewardMoney = 'Hai ricevuto $%.2f.',
        RewardGold = 'Hai ricevuto %.2f oro.',
        RewardItem = 'Hai ricevuto %dx %s.',
        RewardBonus = 'Bonus tempo incluso: +%d%%.',
        RewardNone = 'Lavoro concluso, ma stavolta non c\'e paga.',
        InventoryFullMoney = 'Inventario pieno: %s pagato in contanti ($%.2f).',
        InventoryFullLost = 'Inventario pieno: hai perso %s.',
    },

    Jobs = {
        sweeper = {
            Label = 'Spazzino',
            Npc = {
                Name = 'Addetto comunale',
                Blip = { Name = 'Lavoro: Spazzino' },
            },
            Locations = {
                valentine = { Npc = { Tag = 'Valentine' } },
                rhodes = { Npc = { Tag = 'Rhodes' } },
            },
            Dialog = {
                Offer = {
                    'La citta e un disastro: fango, cartacce e sterco di cavallo ovunque.',
                    'Ti pago se dai una bella ripulita alle strade. Ci stai?',
                },
                Return = { 'Ottimo lavoro, le strade sono di nuovo presentabili. Ecco la paga.' },
                Abandon = { 'Non hai ancora finito. Vuoi lasciar perdere?' },
            },
            Blip = { Name = 'Da pulire' },
            Texts = {
                Prompt = 'Spazza',
                PromptGroup = 'Pulizia',
                Progress = 'Stai spazzando',
                Interrupted = 'Hai interrotto la pulizia.',
                PointDone = 'Punto pulito (%d/%d).',
                NextPoint = 'Vai al prossimo punto segnato sulla mappa.',
            },
        },

        crates = {
            Label = 'Consegna casse',
            Npc = {
                Name = 'Proprietario dell\'emporio',
                Tag = 'Emporio',
                Blip = { Name = 'Lavoro: Consegna casse' },
            },
            Dialog = {
                Offer = {
                    'Mi e arrivata della merce alla stazione e gli scaffali sono vuoti.',
                    'Portami le casse in negozio e ti pago bene. Ci stai?',
                },
                Abandon = { 'Mancano ancora delle casse. Vuoi lasciar perdere?' },
            },
            PickupBlip = { Name = 'Ritiro casse' },
            DeliveryBlip = { Name = 'Consegna casse' },
            Texts = {
                PickupPrompt = 'Prendi cassa',
                PickupGroup = 'Casse',
                DeliverPrompt = 'Posa cassa',
                DropPrompt = 'Lascia cassa',
                Delivered = 'Cassa consegnata (%d/%d).',
                Returned = 'Hai perso la cassa: e tornata al punto di ritiro.',
                Failed = 'Hai perso la cassa: il lavoro e fallito.',
                GoPickup = 'Vai a prendere le casse al punto segnato sulla mappa.',
            },
        },

        wagon = {
            Label = 'Trasporto viveri',
            Npc = {
                Name = 'Spedizioniere',
                Tag = 'Trasporti',
                Blip = { Name = 'Lavoro: Trasporto viveri' },
            },
            Dialog = {
                Offer = {
                    'Ho un carico di viveri che deve arrivare a destinazione oggi stesso.',
                    'Il carretto e pronto. Il tempo parte quando sali a cassetta. Ci stai?',
                },
                Abandon = { 'La merce non e ancora arrivata. Vuoi lasciar perdere?' },
            },
            WagonBlip = { Name = 'Carretto' },
            DestinationBlip = { Name = 'Destinazione' },
            Texts = {
                Prompt = 'Consegna merce',
                PromptGroup = 'Carico',
                Board = 'Sali a cassetta del carretto per far partire il tempo.',
                TimerStarted = 'Destinazione: %s. Hai %s.',
                TimerWarning = 'Ti restano %s.',
                Expired = 'Tempo scaduto: la merce e andata a male.',
                BoardExpired = 'Non sei partito in tempo: il carico e stato affidato ad altri.',
                Destroyed = 'Il carretto e distrutto.',
                Abandoned = 'Hai abbandonato il carretto.',
                NoModels = 'Non ci sono carretti disponibili.',
                SpawnFailed = 'Il carretto non e disponibile.',
                Destinations = {
                    emerald = 'Emerald Ranch',
                    rhodes = 'Rhodes',
                    valentine = 'Valentine',
                    annesburg = 'Annesburg',
                },
            },
        },
    },
}

Locales.en = {
    Common = {
        Title = 'Jobs',
        TalkPrompt = 'Talk',
        Accept = 'Accept',
        Decline = 'Decline',
        Collect = 'Collect your pay',
        Abandon = 'Give up the job',
        KeepGoing = 'Keep going',
        Interrupt = 'Stop',

        AlreadyActive = 'You already have a job in progress.',
        OtherJobActive = 'Finish the job you are doing first.',
        NoActiveJob = 'You have no job in progress.',
        Cooldown = 'I have no more work for you, come back in %s.',
        TooFar = 'You are too far away.',
        NotAlive = 'You cannot work in this condition.',
        NoAccess = 'This job is not for you.',
        Unavailable = 'This job is not available right now.',
        Started = 'Job accepted: %s.',
        Cancelled = 'You gave up the job.',
        Died = 'You died: the job failed.',
        Failed = 'Job failed.',
        ReturnToNpc = 'All done: go back and collect your pay.',

        RewardMoney = 'You received $%.2f.',
        RewardGold = 'You received %.2f gold.',
        RewardItem = 'You received %dx %s.',
        RewardBonus = 'Time bonus included: +%d%%.',
        RewardNone = 'Job finished, but there is no pay this time.',
        InventoryFullMoney = 'Inventory full: %s paid in cash ($%.2f).',
        InventoryFullLost = 'Inventory full: you lost %s.',
    },

    Jobs = {
        sweeper = {
            Label = 'Street sweeper',
            Npc = {
                Name = 'Town clerk',
                Blip = { Name = 'Job: Street sweeper' },
            },
            Locations = {
                valentine = { Npc = { Tag = 'Valentine' } },
                rhodes = { Npc = { Tag = 'Rhodes' } },
            },
            Dialog = {
                Offer = {
                    'This town is a mess: mud, litter and horse dung everywhere.',
                    'I will pay you to clean up the streets. Are you in?',
                },
                Return = { 'Good work, the streets look decent again. Here is your pay.' },
                Abandon = { 'You are not done yet. Do you want to quit?' },
            },
            Blip = { Name = 'To clean' },
            Texts = {
                Prompt = 'Sweep',
                PromptGroup = 'Cleaning',
                Progress = 'Sweeping',
                Interrupted = 'You stopped cleaning.',
                PointDone = 'Spot cleaned (%d/%d).',
                NextPoint = 'Go to the next spot marked on the map.',
            },
        },

        crates = {
            Label = 'Crate delivery',
            Npc = {
                Name = 'General store owner',
                Tag = 'General store',
                Blip = { Name = 'Job: Crate delivery' },
            },
            Dialog = {
                Offer = {
                    'My goods are waiting at the station and the shelves are empty.',
                    'Bring the crates to the store and I will pay you well. Are you in?',
                },
                Abandon = { 'There are still crates to bring. Do you want to quit?' },
            },
            PickupBlip = { Name = 'Crate pickup' },
            DeliveryBlip = { Name = 'Crate delivery' },
            Texts = {
                PickupPrompt = 'Take crate',
                PickupGroup = 'Crates',
                DeliverPrompt = 'Put crate down',
                DropPrompt = 'Drop crate',
                Delivered = 'Crate delivered (%d/%d).',
                Returned = 'You lost the crate: it went back to the pickup point.',
                Failed = 'You lost the crate: the job failed.',
                GoPickup = 'Go and take the crates at the point marked on the map.',
            },
        },

        wagon = {
            Label = 'Food transport',
            Npc = {
                Name = 'Shipping agent',
                Tag = 'Transport',
                Blip = { Name = 'Job: Food transport' },
            },
            Dialog = {
                Offer = {
                    'I have a load of food that must reach its destination today.',
                    'The cart is ready. The clock starts when you take the reins. Are you in?',
                },
                Abandon = { 'The goods have not arrived yet. Do you want to quit?' },
            },
            WagonBlip = { Name = 'Cart' },
            DestinationBlip = { Name = 'Destination' },
            Texts = {
                Prompt = 'Deliver goods',
                PromptGroup = 'Load',
                Board = 'Take the reins of the cart to start the clock.',
                TimerStarted = 'Destination: %s. You have %s.',
                TimerWarning = '%s left.',
                Expired = 'Time is up: the goods have spoiled.',
                BoardExpired = 'You did not leave in time: the load went to someone else.',
                Destroyed = 'The cart is destroyed.',
                Abandoned = 'You abandoned the cart.',
                NoModels = 'There are no carts available.',
                SpawnFailed = 'The cart is not available.',
                Destinations = {
                    emerald = 'Emerald Ranch',
                    rhodes = 'Rhodes',
                    valentine = 'Valentine',
                    annesburg = 'Annesburg',
                },
            },
        },
    },
}

-- Le liste (come le battute dei dialoghi) si sostituiscono intere: una traduzione
-- piu corta non deve lasciare righe in un'altra lingua.
local function merge(target, source)
    for key, value in pairs(source) do
        if type(value) == 'table' and value[1] == nil and type(target[key]) == 'table' then
            merge(target[key], value)
        else
            target[key] = value
        end
    end
end

-- Solo le citta presenti in config.lua: quelle tolte dal config non devono ricomparire da qui.
local function applyJob(job, texts)
    local locationTexts = texts.Locations or {}

    for key, value in pairs(texts) do
        if key ~= 'Npc' and key ~= 'Locations' then
            merge(job, { [key] = value })
        end
    end

    for locationId, location in pairs(job.Locations) do
        merge(location.Npc, texts.Npc or {})
        merge(location, locationTexts[locationId] or {})
    end
end

local function applyLocale(locale)
    Config.Texts = Config.Texts or {}
    merge(Config.Texts, locale.Common or {})

    for jobId, texts in pairs(locale.Jobs or {}) do
        if Config.Jobs[jobId] then
            applyJob(Config.Jobs[jobId], texts)
        end
    end
end

applyLocale(Locales.it)

if Config.Locale ~= 'it' then
    if Locales[Config.Locale] then
        applyLocale(Locales[Config.Locale])
    else
        print(('^3[%s] Lingua %s non trovata: uso l\'italiano.^7'):format(GetCurrentResourceName(), tostring(Config.Locale)))
    end
end
