# pk_delivery

Three city jobs for RedM: **street sweeper**, **general store crate delivery** and **wagon supply run**. Works with **VORP**, **RSG** and **TPZ** through a bridge. Dialogs, notifications and the progress bar come from `pk_library`.

## Requirements

- One framework: `vorp_core`, `rsg-core` or `tpz_core` (detected automatically with `Config.Framework = 'auto'`)
- `pk_library` (version with `OpenDialog`)
- `oxmysql` (only used to read the faction column)

## Installation

1. Update `pk_library` to the version with NPC dialogs.
2. In `server.cfg`, after the framework, the inventory and `pk_library`: `ensure pk_delivery`
3. In `config.lua` set your coordinates and the wagon models in `Config.Wagon.Models`.

No SQL tables needed: cooldowns are stored in the resource KVP and survive restarts.

## Structure

```
config.lua                 all values
locales.lua                all texts, Italian and English
shared/utils.lua           logs, framework detection, hooks
client/bridge.lua          the only client file that knows the framework
client/ui.lua              the only client file that calls pk_library
client/utils.lua           prompts, blips, markers, entities
client/main.lua            NPCs, dialogs, active job
client/jobs/*.lua          one file per job
server/bridge.lua          the only server file that knows the framework
server/ui.lua              the only server file that calls pk_library
server/rewards.lua         reward calculation and delivery
server/main.lua            sessions, cooldowns, validation, disconnects
server/jobs/*.lua          one file per job
```

## How to add

- **Towns**: every job has its own `Locations` in `config.lua`. Copy a block and change the id and the coordinates. NPC tags or custom lines go in the job's `Locations` in `locales.lua`; without entries the job's texts are used. `Enabled = false` turns a town off, `Reward` in a town replaces the job's one. The cooldown is shared by all towns.
- **Sweeping points**: rows in the town's `Points`. `PointsPerJob` sets how many the server draws.
- **Crates**: the town's `PickupPoint` is the single point all crates are taken from; `Count` sets how many to deliver.
- **NPC**: the town's `Npc` block (model, `Coords` with heading, scenario, blip).
- **Wagon**: an entry in `Config.Wagon.Models`; the fields are explained in the comment above the list.
- **Destinations**: rows in the town's `Destinations`, with the name of every `Key` in `Texts.Destinations` of the `wagon` job in `locales.lua`.
- **Language**: copy a block of `locales.lua`, translate it and set `Config.Locale`. Missing entries stay in Italian.
- **Item rewards**: `Reward.Mode = 'items'` or `'both'` and `Items = { { Name = 'item_name', Min = 1, Max = 2, Chance = 50, FallbackPrice = 1.0 } }`.
- **Another framework**: add a function in `Frameworks` in `server/bridge.lua` and `client/bridge.lua`, with the interface described at the top of those files, and the resource name in `FRAMEWORK_RESOURCES` in `shared/utils.lua`.
- **Another job**: an entry in `Config.Jobs`, texts in `Jobs` of `locales.lua`, then `Delivery.RegisterJob` in `server/jobs/` and `client/jobs/`. The interface is described at the top of `server/main.lua` and `client/main.lua`.
- **Dialog**: texts are in each job's `Dialog` block in `locales.lua`; the panel lives in `pk_library` (`html/npc-dialog.*`); the call is in `client/ui.lua`.

## Restricting a location to a job or faction

Every entry in `Locations` can have an `Access` block. Without `Access` the job is open to everyone.

```lua
rhodes = {
    Access = {
        Jobs = { 'sheriff', { Job = 'doctor', MinGrade = 2 } },
        Factions = { 'Faction Name' },
        Mode = 'any',
    },
    Npc = { ... },
    Points = { ... },
},
```

- `Jobs`: job names. With `{ Job = 'name', MinGrade = 2 }` a minimum grade is required too.
- `Factions`: faction names. `Factions = true` accepts anyone with an assigned faction.
- `Mode`: `'any'` job or faction is enough (default); `'all'` both are required.

Case does not matter. The check runs on the server when the player accepts: the NPC stays visible to everyone, players without the requirements get a notice.

### Factions: the database column

The faction does not come from the framework: `pk_delivery` reads it live from the characters table, from the column set in `Config.FactionAccess.Column` (default `faction`). Add the column to `characters` if you need it:

```sql
ALTER TABLE `characters` ADD COLUMN `faction` VARCHAR(64) NULL DEFAULT NULL;
```

If your server already has a faction column, just set its name in `Column`.

The value in the column must match the name written in `Factions`. Values in `Config.FactionAccess.EmptyValues` count as "no faction". If the column is missing, an error shows in the console once: faction rules let nobody through, job rules keep working.

On VORP the row is found by `charidentifier`, on RSG by `citizenid` in `players`. On TPZ check the table in `Bridge.GetFactionRow`.

## Cargo robbery

`Config.Robbery` stays `enabled = false`: there is no robbery logic yet. The extension points are described at the top of `server/jobs/wagon.lua`: hooks `wagon:departed`, `wagon:tick`, `wagon:delivered`, `wagon:ended`, and `session.cargo`, which multiplies the pay.

## Commands

- `/canceljob` cancels the current job (`Config.CancelCommand`). You can also quit by talking to the job's NPC.
