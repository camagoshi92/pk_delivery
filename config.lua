Config = {}

Config.Debug = false

Config.Locale = 'it' -- 'it' | 'en'; tutti i testi sono in locales.lua

-- 'auto' | 'vorp' | 'rsg' | 'tzp'. Con 'auto' sceglie in base alle risorse avviate.
Config.Framework = 'auto'

-- Comando per annullare il lavoro in corso. '' per disattivarlo.
Config.CancelCommand = 'annullalavoro'

-- Tasti dei prompt (hash dei controlli RedM).
Config.Keys = {
    Talk = 0xCEFD9220,      -- E
    Action = 0x760A9C6F,    -- G
    Interrupt = 0x8CC9CD42, -- X
}

Config.NpcSpawnDistance = 60.0    -- oltre questa distanza l'NPC non esiste sul client
Config.NpcTalkDistance = 2.5
Config.MarkerDrawDistance = 40.0

Config.Marker = {
    Type = 0x94FDAE17,
    Size = { 2.0, 2.0, 0.7 },
    Color = { r = 214, g = 173, b = 92, a = 80 },
}

-- Validazioni lato server. I limiti sono volutamente larghi: bloccano i trucchi, non i giocatori.
Config.Security = {
    NpcDistance = 6.0,       -- distanza massima dall'NPC per accettare e riscuotere
    DistanceMargin = 2.0,    -- metri concessi oltre il raggio del punto (ritardo di rete)
    MinWorkRatio = 0.85,     -- frazione minima della durata di un'azione a tempo
    MaxCarrySpeed = 7.0,     -- m/s massimi a piedi con la cassa
    ActionThrottleMs = 150,  -- pausa minima tra due azioni dello stesso giocatore
}

-- Inventario pieno: 'money' paga l'oggetto in contanti (FallbackPrice), 'lose' lo perde.
Config.InventoryFull = 'money'

-- Fazioni per Access: colonna della tabella dei personaggi (vedi README).
Config.FactionAccess = {
    Column = 'fazione',
    EmptyValues = { '', 'nessuna', 'none' }, -- valori che significano "nessuna fazione"
}

--------------------------------------------------------------------------------
-- RICOMPENSE (stessa struttura per ogni lavoro)
--
-- Mode: 'money' | 'items' | 'both'
-- Money: Min/Max casuali; Currency: 'cash' | 'gold' (se il framework non ha l'oro paga in contanti).
-- Items: { Name = 'nome_item', Min = 1, Max = 2, Chance = 100, FallbackPrice = 1.0 }
--        Name vuoto = voce ignorata. Chance in percentuale.
--        FallbackPrice = prezzo unitario se l'inventario e pieno e InventoryFull = 'money'.
-- TimeBonus (lavori 2 e 3): sotto TargetSeconds il denaro aumenta di Percent. Solo sul denaro.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CITTA
--
-- Ogni lavoro ha le sue Locations: id della citta -> NPC e punti di quella citta.
-- Per aggiungerne una copia un blocco, cambia l'id e le coordinate.
-- Enabled = false spegne una sola citta. Reward nella citta sostituisce quella del lavoro.
-- Il cooldown e per lavoro, comune a tutte le citta.
--
-- Access nella citta limita chi puo accettare il lavoro in quel punto; senza, e aperto a tutti:
--     Access = {
--         Jobs = { 'sceriffo', { Job = 'medico', MinGrade = 2 } },
--         Factions = { 'Nome Fazione' },   -- true = qualunque fazione assegnata
--         Mode = 'any',                    -- 'any': job O fazione; 'all': job E fazione
--     },
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- LAVORO 1 - SPAZZINO
--------------------------------------------------------------------------------
Config.Sweeper = {
    Enabled = true,

    Locations = {
        rhodes = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(1342.79, -1330.82, 77.59, 147.76),
                Scenario = 'WORLD_HUMAN_SMOKE',
                Blip = { Enabled = true, Sprite = 'blip_shop_market_stall' },
            },
            Points = {
                vector4(1345.23, -1303.16, 77.42, 250.38),
                vector4(1349.19, -1322.26, 77.78, 253.09),
                vector4(1358.21, -1307.79, 77.73, 333.89),
                vector4(1368.27, -1312.05, 77.95, 329.05),
                vector4(1402.39, -1322.09, 78.21, 277.26),
                vector4(1358.23, -1386.78, 79.87, 73.14),
                vector4(1328.79, -1380.98, 80.28, 83.03),
                vector4(1247.75, -1313.81, 76.89, 343.90),
                vector4(1217.39, -1289.76, 76.90, 58.26),
                vector4(1228.90, -1291.31, 76.90, 232.39),
            },
        },

        strawberry = { -- COORDINATE DI ESEMPIO: da sostituire
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(-1786.36, -404.45, 156.49, 274.10),
                Scenario = 'WORLD_HUMAN_SMOKE',
                Blip = { Enabled = true, Sprite = 'blip_shop_market_stall' },
            },
            Points = {
                vector4(-1774.81, -400.66, 156.46, 4.70),
                vector4(-1759.38, -386.29, 157.69, 315.30),
                vector4(-1767.87, -382.21, 157.74, 260.94),
                vector4(-1791.09, -397.17, 160.23, 145.64),
                vector4(-1797.28, -382.80, 160.26, 341.29),
                vector4(-1807.56, -370.03, 162.84, 135.32),
                vector4(-1814.07, -421.94, 160.00, 170.78),
                vector4(-1802.31, -427.35, 158.78, 216.15)
            },
        },
    },

    PointsPerJob = 5,
    ShowAllBlips = false,      -- false: solo il punto corrente; true: tutti
    AutoPay = false,           -- true: paga dopo l'ultimo punto senza tornare dall'NPC
    InteractDistance = 2.0,
    WorkDuration = 12,         -- secondi per ogni punto

    Work = {
        Mode = 'scenario',     -- 'scenario' | 'prop'
        Scenario = 'WORLD_HUMAN_BROOM',
        -- Mode = 'prop': scopa in mano + animazione. Dict e Name vanno scelti in gioco.
        Prop = {
            Model = 'p_broom01x',
            Bone = 'SKEL_R_Hand',
            Offset = vector3(0.0, 0.0, 0.0),
            Rotation = vector3(0.0, 0.0, 0.0),
            Dict = '',
            Name = '',
            Flags = 31,
        },
    },

    Blip = { Sprite = 'blip_ambient_tracking' },

    Cooldown = { Success = 0, Fail = 0 },

    Reward = {
        Mode = 'money',
        Money = { Min = 4.0, Max = 7.0, Currency = 'cash' },
        Items = {
            { Name = '', Min = 1, Max = 1, Chance = 50, FallbackPrice = 1.0 },
        },
    },
}

--------------------------------------------------------------------------------
-- LAVORO 2 - CONSEGNA CASSE ALL'EMPORIO
--------------------------------------------------------------------------------
Config.Crates = {
    Enabled = true,

    Locations = { -- COORDINATE DI ESEMPIO: da sostituire. Tutte le casse si prendono da PickupPoint.
        valentine = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(-324.6, 803.9, 116.9, 280.0), -- davanti all'emporio, da verificare
                Scenario = 'WORLD_HUMAN_CLIPBOARD',
                Blip = { Enabled = true, Sprite = 'blip_shop_store' },
            },
            PickupPoint = vector4(-170.0, 640.0, 113.6, 0.0),
            DeliveryPoint = vector3(-322.5, 803.0, 116.9),
        },

        rhodes = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords =vector4(1260.22, -1324.81, 76.90, 6.01),
                Scenario = 'WORLD_HUMAN_CLIPBOARD',
                Blip = { Enabled = true, Sprite = 'blip_shop_store' },
            },
            PickupPoint = vector4(1254.65, -1329.14, 76.90, 189.53),
            DeliveryPoint = vector3(1323.48, -1292.13, 77.03),
        },
    },

    Count = 5,                 -- casse da consegnare
    Model = 'p_package04bx',
    DeliveryRadius = 2.0,
    InteractDistance = 1.0,

    OnDrop = 'return',         -- 'return': la cassa torna al punto di ritiro; 'fail': lavoro fallito
    DropOnRagdoll = true,      -- cadendo si perde la cassa

    Carry = {
        Bone = 'SKEL_L_Hand',
        Offset = vector3(0.1, -0.14, 0.21),       -- valori di partenza, da rifinire in gioco
        Rotation = vector3(263.29, 709.19, 244.3),
        Anim = { Dict = 'mech_carry_box', Name = 'idle', Flags = 31 },
        PutDown = { Scenario = 'WORLD_HUMAN_CROUCH_INSPECT', Duration = 1500 },
        MoveRatio = 1.0,       -- 1.0 camminata, 0 = nessun limite di velocita
        BlockedControls = {
            0x8FFC75D6, -- corsa
            0xD9D0E1C0, -- salto e arrampicata
            0xF84FA74F, -- mira
            0x07CE1E61, -- attacco
            0xAC4BD4F1, -- ruota armi
            0xCEFD9220, -- salire a cavallo o su un mezzo
        },
    },

    PickupBlip = { Sprite = 'blip_ambient_tracking' },
    DeliveryBlip = { Sprite = 'blip_shop_store' },

    Cooldown = { Success = 0, Fail = 0 },

    Reward = {
        Mode = 'money',
        Money = { Min = 8.0, Max = 12.0, Currency = 'cash' },
        Items = {
            { Name = '', Min = 1, Max = 2, Chance = 25, FallbackPrice = 1.0 },
        },
        TimeBonus = { Enabled = true, TargetSeconds = 300, Percent = 20 },
    },
}

--------------------------------------------------------------------------------
-- LAVORO 3 - TRASPORTO VIVERI CON CARRETTO
--------------------------------------------------------------------------------
Config.Wagon = {
    Enabled = true,

    Locations = { -- COORDINATE DI ESEMPIO: da sostituire. Il nome di ogni Key sta in locales.lua.
        valentine = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(-250.0, 750.0, 117.0, 200.0),
                Scenario = 'WORLD_HUMAN_SMOKE',
                Blip = { Enabled = true, Sprite = 'blip_teamsters' },
            },
            SpawnPoint = vector4(-246.0, 745.0, 117.0, 200.0), -- accanto all'NPC
            Destinations = {
                { Key = 'emerald', Coords = vector4(1420.0, 280.0, 89.5, 0.0) },
                { Key = 'rhodes', Coords = vector4(1290.0, -1280.0, 77.0, 0.0) },
                { Key = 'annesburg', Coords = vector4(2930.0, 1290.0, 44.5, 0.0) },
            },
        },

        rhodes = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(1335.33, -1259.51, 77.60, 115.25),
                Scenario = 'WORLD_HUMAN_SMOKE',
                Blip = { Enabled = true, Sprite = 'blip_teamsters' },
            },
            SpawnPoint = vector4(1339.07, -1266.65, 77.58, 75.23), -- accanto all'NPC
            Destinations = {
                --{ Key = 'emerald', Coords = vector4(1420.0, 280.0, 89.5, 0.0) },
                --{ Key = 'valentine', Coords = vector4(-290.0, 780.0, 118.0, 0.0) },
                { Key = 'annesburg', Coords = vector3(1331.06, -1226.04, 79.09) },
            },
        },
    },

    -- MODELLI DEL CARRETTO: da compilare. Con la lista vuota il lavoro non parte
    -- e in console compare un errore. Il server ne sceglie uno a caso.
    --
    -- Models = {
    --     {
    --         Model = 'nome_modello',              -- obbligatorio
    --         Horses = true,                       -- false = senza cavalli automatici (DA VERIFICARE in gioco)
    --         Propset = 'nome_propset',            -- facoltativo: carico nativo del mezzo
    --         Props = {                            -- facoltativo: prop attaccati come carico
    --             { Model = 'p_crate14x', Offset = vector3(0.0, -1.0, 0.8), Rotation = vector3(0.0, 0.0, 0.0) },
    --         },
    --         SpawnOffset = vector3(0.0, 0.0, 0.0), -- rispetto a SpawnPoint, ruotato col suo heading
    --     },
    -- },
    Models = {
        { Model = 'wagon02x', Horses = true },
    },

    DestinationRadius = 3.0,
    DeliverPlayerDistance = 6.0, -- distanza massima dal carretto per consegnare

    MaxSeconds = 900,          -- tempo massimo da quando sali a cassetta
    BoardSeconds = 300,        -- tempo per salire sul carretto dopo l'accettazione
    AbandonDistance = 80.0,    -- oltre questa distanza dal carretto il lavoro fallisce
    MaxDeliverySpeed = 0.5,    -- m/s: per consegnare il carretto deve essere fermo
    TimerWarnings = { 300, 60 }, -- avvisi a tot secondi dalla scadenza

    DestinationBlip = { Sprite = 'blip_ambient_tracking' },

    Cooldown = { Success = 0, Fail = 0 },

    Reward = {
        Mode = 'money',
        Money = { Min = 15.0, Max = 25.0, Currency = 'cash' },
        Items = {
            { Name = '', Min = 1, Max = 1, Chance = 10, FallbackPrice = 5.0 },
        },
        TimeBonus = { Enabled = true, TargetSeconds = 480, Percent = 25 },
    },
}

--------------------------------------------------------------------------------
-- FURTO DEL CARICO: PREDISPOSIZIONE, NON IMPLEMENTATO
-- Lasciare enabled = false. Punti di estensione in server/jobs/wagon.lua (Hooks).
--------------------------------------------------------------------------------
Config.Robbery = {
    enabled = false,
    Chance = 0,            -- probabilita di assalto per viaggio
    MinDistance = 0.0,     -- metri percorsi prima di un possibile assalto
    Bandits = { Count = 0, Models = {} },
    CargoLossPercent = 0,  -- perdita parziale del carico (riduce la paga)
}

-- Interruttore generale: false spegne tutti i lavori (niente NPC, blip o avvii).
Config.Enabled = true

-- Elenco dei lavori: la chiave e l'id usato da client e server. Solo lavori qui dentro.
Config.Jobs = {
    sweeper = Config.Sweeper,
    crates = Config.Crates,
    wagon = Config.Wagon,
}
