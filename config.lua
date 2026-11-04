Config = {}

Config.Debug = false

Config.Locale = 'en' -- 'it' | 'en'; all texts are in locales.lua

-- 'auto' | 'vorp' | 'rsg' | 'tzp'. With 'auto' it picks the framework from the started resources.
Config.Framework = 'auto'

-- Command to cancel the current job. '' to disable it.
Config.CancelCommand = 'canceljob'

-- Prompt keys (RedM control hashes).
Config.Keys = {
    Talk = 0xCEFD9220,      -- E
    Action = 0x760A9C6F,    -- G
    Interrupt = 0x8CC9CD42, -- X
}

Config.NpcSpawnDistance = 60.0    -- beyond this distance the NPC does not exist on the client
Config.NpcTalkDistance = 2.5
Config.MarkerDrawDistance = 40.0

Config.Marker = {
    Type = 0x94FDAE17,
    Size = { 2.0, 2.0, 0.7 },
    Color = { r = 214, g = 173, b = 92, a = 80 },
}

-- Server-side validation. Limits are deliberately loose: they stop cheats, not players.
Config.Security = {
    NpcDistance = 6.0,       -- max distance from the NPC to accept a job and collect the pay
    DistanceMargin = 2.0,    -- meters allowed beyond a point's radius (network delay)
    MinWorkRatio = 0.85,     -- minimum fraction of a timed action's duration
    MaxCarrySpeed = 7.0,     -- max m/s on foot while carrying a crate
    ActionThrottleMs = 150,  -- minimum pause between two actions of the same player
}

-- Full inventory: 'money' pays the item in cash (FallbackPrice), 'lose' drops it.
Config.InventoryFull = 'money'

-- Factions for Access: column of the characters table (see README).
Config.FactionAccess = {
    Column = 'faction',
    EmptyValues = { '', 'none' }, -- values meaning "no faction"
}

--------------------------------------------------------------------------------
-- REWARDS (same structure for every job)
--
-- Mode: 'money' | 'items' | 'both'
-- Money: random Min/Max; Currency: 'cash' | 'gold' (paid in cash if the framework has no gold).
-- Items: { Name = 'item_name', Min = 1, Max = 2, Chance = 100, FallbackPrice = 1.0 }
--        Empty Name = entry ignored. Chance is a percentage.
--        FallbackPrice = unit price paid when the inventory is full and InventoryFull = 'money'.
-- TimeBonus (jobs 2 and 3): under TargetSeconds the money grows by Percent. Money only.
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- TOWNS
--
-- Every job has its own Locations: town id -> NPC and points of that town.
-- To add one, copy a block and change the id and the coordinates.
-- Enabled = false turns off a single town. Reward in a town replaces the job's one.
-- The cooldown is per job, shared by all towns.
--
-- Access in a town limits who can accept the job there; without it the job is open to everyone:
--     Access = {
--         Jobs = { 'sheriff', { Job = 'doctor', MinGrade = 2 } },
--         Factions = { 'Faction Name' },   -- true = any assigned faction
--         Mode = 'any',                    -- 'any': job OR faction; 'all': job AND faction
--     },
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- JOB 1 - STREET SWEEPER
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

        strawberry = {
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
    ShowAllBlips = false,      -- false: current point only; true: all of them
    AutoPay = false,           -- true: pays after the last point without going back to the NPC
    InteractDistance = 2.0,
    WorkDuration = 12,         -- seconds per point

    Work = {
        Mode = 'scenario',     -- 'scenario' | 'prop'
        Scenario = 'WORLD_HUMAN_BROOM',
        -- Mode = 'prop': broom in hand + animation. Dict and Name must be picked in game.
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
-- JOB 2 - GENERAL STORE CRATE DELIVERY
--------------------------------------------------------------------------------
Config.Crates = {
    Enabled = true,

    Locations = {
        valentine = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(-1795.89, -385.15, 160.33, 276.24),
                Scenario = 'WORLD_HUMAN_CLIPBOARD',
                Blip = { Enabled = true, Sprite = 'blip_shop_store' },
            },
            PickupPoint = vector4(-1761.85, -394.43, 156.27, 281.35),
            DeliveryPoint = vector4(-1791.43, -384.62, 160.33, 49.02),
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

    Count = 5,                 -- crates to deliver
    Model = 'p_package04bx',
    DeliveryRadius = 2.0,
    InteractDistance = 1.0,

    OnDrop = 'return',         -- 'return': the crate goes back to the pickup point; 'fail': job failed
    DropOnRagdoll = true,      -- falling down drops the crate

    Carry = {
        Bone = 'SKEL_L_Hand',
        Offset = vector3(0.1, -0.14, 0.21),       -- starting values, fine-tune in game
        Rotation = vector3(263.29, 709.19, 244.3),
        Anim = { Dict = 'mech_carry_box', Name = 'idle', Flags = 31 },
        PutDown = { Scenario = 'WORLD_HUMAN_CROUCH_INSPECT', Duration = 1500 },
        MoveRatio = 1.0,       -- 1.0 walk, 0 = no speed limit
        BlockedControls = {
            0x8FFC75D6, -- sprint
            0xD9D0E1C0, -- jump and climb
            0xF84FA74F, -- aim
            0x07CE1E61, -- attack
            0xAC4BD4F1, -- weapon wheel
            0xCEFD9220, -- mount a horse or a vehicle
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
-- JOB 3 - SUPPLY RUN WITH A WAGON
--------------------------------------------------------------------------------
Config.Wagon = {
    Enabled = true,

    Locations = {
        valentine = {
            Npc = {
                Model = 'a_m_m_valfarmer_01',
                Coords = vector4(-1768.09, -425.57, 155.21, 145.59),
                Scenario = 'WORLD_HUMAN_SMOKE',
                Blip = { Enabled = true, Sprite = 'blip_teamsters' },
            },
            SpawnPoint = vector4(-1775.56, -428.89, 154.65, 145.97),
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
            SpawnPoint = vector4(1339.07, -1266.65, 77.58, 75.23), -- next to the NPC
            Destinations = {
                --{ Key = 'emerald', Coords = vector4(1420.0, 280.0, 89.5, 0.0) },
                --{ Key = 'valentine', Coords = vector4(-290.0, 780.0, 118.0, 0.0) },
                { Key = 'annesburg', Coords = vector3(1331.06, -1226.04, 79.09) },
            },
        },
    },

    -- WAGON MODELS. With an empty list the job does not start
    -- and an error shows in the console. The server picks one at random.
    --
    -- Models = {
    --     {
    --         Model = 'model_name',                 -- required
    --         Horses = true,                       -- false = no automatic horses
    --         Propset = 'propset_name',            -- optional: native cargo of the vehicle
    --         Props = {                            -- optional: props attached as cargo
    --             { Model = 'p_crate14x', Offset = vector3(0.0, -1.0, 0.8), Rotation = vector3(0.0, 0.0, 0.0) },
    --         },
    --         SpawnOffset = vector3(0.0, 0.0, 0.0), -- relative to SpawnPoint, rotated by its heading
    --     },
    -- },
    Models = {
        { Model = 'wagon02x', Horses = true },
    },

    DestinationRadius = 3.0,
    DeliverPlayerDistance = 6.0, -- max distance from the wagon to deliver

    MaxSeconds = 900,          -- max time from when you take the reins
    BoardSeconds = 300,        -- time to board the wagon after accepting
    AbandonDistance = 80.0,    -- beyond this distance from the wagon the job fails
    MaxDeliverySpeed = 0.5,    -- m/s: the wagon must be stopped to deliver
    TimerWarnings = { 300, 60 }, -- warnings at these seconds before the deadline

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
-- CARGO ROBBERY: PREPARED, NOT IMPLEMENTED
-- Leave enabled = false. Extension points in server/jobs/wagon.lua (Hooks).
--------------------------------------------------------------------------------
Config.Robbery = {
    enabled = false,
    Chance = 0,            -- robbery chance per trip
    MinDistance = 0.0,     -- meters traveled before a possible robbery
    Bandits = { Count = 0, Models = {} },
    CargoLossPercent = 0,  -- partial cargo loss (lowers the pay)
}

-- Master switch: false turns off every job (no NPCs, blips or starts).
Config.Enabled = true

-- Job list: the key is the id used by client and server. Only jobs listed here.
Config.Jobs = {
    sweeper = Config.Sweeper,
    crates = Config.Crates,
    wagon = Config.Wagon,
}
