# pk_delivery

Tre lavori cittadini per RedM: **spazzino**, **consegna casse all'emporio** e **trasporto viveri con carretto**. Supporta VORP, RSG e TZP-Core tramite bridge. Dialoghi, notifiche e barra di avanzamento vengono da `pk_library`.

## Installazione

1. Aggiorna `pk_library` (serve la versione con `OpenDialog`).
2. In `server.cfg`, dopo framework, inventario e `pk_library`: `ensure pk_delivery`
3. In `config.lua` sostituisci le coordinate di esempio e compila `Config.Wagon.Models`.

Non servono tabelle SQL: i cooldown stanno nel KVP della risorsa e sopravvivono ai riavvii.

## Struttura

```
config.lua                 tutti i valori
locales.lua                tutti i testi, in italiano e inglese
shared/utils.lua           log, rilevamento framework, hook
client/bridge.lua          unico file client che conosce il framework
client/ui.lua              unico file client che chiama pk_library
client/utils.lua           prompt, blip, marker, entita
client/main.lua            NPC, dialoghi, lavoro attivo
client/jobs/*.lua          un file per lavoro
server/bridge.lua          unico file server che conosce il framework
server/ui.lua              unico file server che chiama pk_library
server/rewards.lua         calcolo e consegna delle ricompense
server/main.lua            sessioni, cooldown, validazioni, disconnessioni
server/jobs/*.lua          un file per lavoro
```

## Come si aggiunge

- **Citta**: ogni lavoro ha le sue `Locations` in `config.lua`. Copia un blocco, cambia l'id e le coordinate. Il tag dell'NPC o battute proprie si aggiungono in `Locations` del lavoro in `locales.lua`; senza voci valgono i testi del lavoro. `Enabled = false` spegne una citta, `Reward` nella citta sostituisce quella del lavoro. Il cooldown e comune a tutte le citta.
- **Punti di pulizia**: righe in `Points` della citta. `PointsPerJob` indica quanti ne estrae il server.
- **Casse**: `PickupPoint` della citta e il punto unico da cui si prendono tutte; `Count` indica quante consegnarne.
- **NPC**: blocco `Npc` della citta (modello, `Coords` con heading, scenario, blip).
- **Carretto**: una voce in `Config.Wagon.Models`; i campi sono spiegati nel commento sopra la lista.
- **Destinazioni**: righe in `Destinations` della citta, con il nome di ogni `Key` in `Texts.Destinations` del lavoro `wagon` in `locales.lua`.
- **Lingua**: copia un blocco di `locales.lua`, traducilo e imposta `Config.Locale`. Le voci mancanti restano in italiano.
- **Oggetti di ricompensa**: `Reward.Mode = 'items'` o `'both'` e `Items = { { Name = 'nome_item', Min = 1, Max = 2, Chance = 50, FallbackPrice = 1.0 } }`.
- **Altro framework**: aggiungi la funzione in `Frameworks` in `server/bridge.lua` e `client/bridge.lua`, con la stessa interfaccia scritta in cima ai file, e il nome risorsa in `FRAMEWORK_RESOURCES` in `shared/utils.lua`.
- **Altro lavoro**: voce in `Config.Jobs`, testi in `Jobs` di `locales.lua`, poi `Delivery.RegisterJob` in `server/jobs/` e `client/jobs/`. L'interfaccia e descritta in cima a `server/main.lua` e `client/main.lua`.
- **Dialogo**: i testi sono nel blocco `Dialog` di ogni lavoro in `locales.lua`; il pannello e in `pk_library` (`html/npc-dialog.*`); la chiamata in `client/ui.lua`.

## Limitare un punto a job o fazione

Ogni punto in `Locations` puo avere un blocco `Access`. Senza `Access` il lavoro e aperto a tutti.

```lua
rhodes = {
    Access = {
        Jobs = { 'sceriffo', { Job = 'medico', MinGrade = 2 } },
        Factions = { 'Nome Fazione' },
        Mode = 'any',
    },
    Npc = { ... },
    Points = { ... },
},
```

- `Jobs`: nomi dei job. Con `{ Job = 'nome', MinGrade = 2 }` serve anche un grado minimo.
- `Factions`: nomi delle fazioni. `Factions = true` accetta chiunque abbia una fazione assegnata.
- `Mode`: `'any'` basta il job oppure la fazione (predefinito); `'all'` servono entrambi.

Maiuscole e minuscole non contano. Il controllo avviene sul server quando il giocatore accetta: l'NPC resta visibile a tutti, chi non ha i requisiti riceve un avviso.

### Fazioni: la colonna nel database

La fazione non arriva dal framework: `pk_delivery` la legge dalla tabella dei personaggi, in tempo reale, dalla colonna indicata in `Config.FactionAccess.Column` (predefinita `fazione`). Se aggiungi la colonna a `characters`, viene letta quella:

```sql
ALTER TABLE `characters` ADD COLUMN `fazione` VARCHAR(64) NULL DEFAULT NULL;
```

Se la colonna esiste gia, non serve fare nulla. Con un nome diverso basta cambiare `Column`.

Il valore nella colonna deve corrispondere al nome scritto in `Factions`. I valori in `Config.FactionAccess.EmptyValues` contano come "nessuna fazione". Se la colonna manca, in console compare un errore una sola volta: le regole sulle fazioni non fanno passare nessuno, quelle sui job continuano a funzionare.

Su VORP la riga si trova con `charidentifier`. Su RSG (`players`, `citizenid`) e TZP la tabella e da verificare in `Bridge.GetFactionRow`.

## Furto del carico

`Config.Robbery` resta `enabled = false`: non c'e nessuna logica di assalto. I punti di estensione sono descritti in cima a `server/jobs/wagon.lua`: hook `wagon:departed`, `wagon:tick`, `wagon:delivered`, `wagon:ended`, e `session.cargo` che moltiplica la paga.

## Comandi

- `/annullalavoro` annulla il lavoro in corso (`Config.CancelCommand`). Si puo anche rinunciare parlando con l'NPC del lavoro.
