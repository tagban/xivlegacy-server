# Atomos

How the server runs the Atomos event at five camps. It covers what 1.23b
did, what we built, and what is still missing.

## What 1.23b did

Patch 1.23b (September 12, 2012) brought Atomos, the voidsent-swallowing
moon, to ten camps. The ten fall into two groups:

- **Five camps where Atomos only appears** (patch note dev1485): Camp
  Dragonhead (Coerthas), Camp Emerald Moss and Camp Crimson Bark (Black
  Shroud), Camp Black Brush (Thanalan) and Camp Horizon (Thanalan).
- **Five camps where Atomos "behaves differently"** (dev1486): Camp
  Brittlebark, Revenant's Toll, Camp Ever Lakes, Camp Glory and Camp
  Bluefog. Teleporting to these five was free.

Players at the time described the timing like this. Atomos came at 18:00
and 00:00 Eorzea time over one group of camps, where it could be fought and
left a Voidstone behind. At 06:00 and 12:00 it came over the other group,
where it could not be attacked. Either way it stayed a little over three
Eorzean hours and then left. Voidsent came with it. Examining a Voidstone
gave an Over-aspected Cluster, Over-aspected Crystals or a short speed
boost. Over-aspected items could be traded for Grand Company seals during
the Foundation Day event of 2012 (September 12 to November 11).

Monster data the project already holds (from Gamer Escape) agrees with
this. A level 60 Atomos that drops the Voidstone is listed only at the
dev1486 camps, and no Atomos is listed at the dev1485 camps. Deepvoid
scamps, souls and warriors are listed at all ten camps. They are level 60
and drop Over-aspected Crystals.

The 1.23b client agrees too:

- The teleport menu script shows the dev1485 camps at no anima cost when
  the player's special event work is 20. It shows the dev1486 camps free
  all the time.
- Atomos's actor classes (2111001-2111024) have model 10070 and no class
  path. The client has a voidsent-object body
  (`/Chara/Npc/Monster/Animaobj/AnimaobjStandard`), and Atomos renders with
  it.

We take this to mean that **at the dev1485 camps Atomos can't be attacked,
appears at 06:00 and 12:00 Eorzea time, and releases voidsent**. That is
the encounter built here.

## What the server does

- **The switch.** The event is `atomos` in `settings/events.toml` and runs
  September 12 to November 11 by default, the dates of the 2012 run.
  `!event atomos on|off|auto` overrides the dates, and the override is kept
  over restarts.
- **Special event work.** While the event runs, every player gets special
  event work 20. Players already logged in get it within ten seconds or at
  once after `!event`. New arrivals get it at login and zone-in. When the
  event stops, everyone goes back to 18, the value the server always sent
  before. A seasonal event sets this value with `special_event_work = N`
  in its block.
- **Free teleport.** `IsTeleportFree` in `scripts/lua/aetheryte.lua`
  charges nothing for the five camps only while the work is 20. The
  dev1486 camps stay free all the time, as before. The server and the
  client menu use the same rule, so the menu shows 0 and the server
  charges 0.
- **The encounter.** At 06:00 and 12:00 Eorzea time, each camp in a
  loaded zone opens. Atomos appears a short way from the aetheryte, on the
  ground, and can't be killed. Six voidsent (deepvoid scamps, souls and
  warriors) spawn around it and attack anyone nearby. When a wave falls the
  next one comes, up to three waves. The camp closes when the last wave
  falls, when its time runs out (190 Eorzean minutes, about 9 real
  minutes), or when the event stops. Each voidsent has a 30% chance to drop
  an Over-aspected Crystal (drop list 99000001). Players in the zone see a
  system message when a camp opens, when each wave comes, and when it
  closes.
- **GM control.** `!atomos` shows which camps are open.
  `!atomos open|close [camp|all]` opens or closes one or all camps now. A
  camp opened by hand stays open when the event stops; close it with
  `!atomos close`.
- **Settings.** `[atomos]` in `settings/map.toml` sets the voidsent level,
  HP, wave size and count, and how long a camp stays open (see
  `settings/README.md`).

Code: `map-server/src/atomos.rs` (schedule, state and spawning),
`map-server/src/command_processor/atomos.rs` (`!atomos`),
`map-server/src/runtime/class_spawn.rs` (spawning a monster from its actor
class, shared with `!worldend`), and `map-server/src/seasonal.rs` (special
event work).

## Our choices and what is left out

- **Our choices.** Retail wave counts, wave sizes, voidsent HP and drop
  rates are not known, so ours are guesses, and so is closing early once
  the last wave falls. Atomos stands on the ground; it may have floated in
  1.0.
- **The dev1486 encounter** is not built: the attackable Atomos at 18:00
  and 00:00, the Voidstone, and what examining it gives (Cluster, Crystals,
  speed boost). Neither are the voidsent seen only at those camps (deepvoid
  pikeman, sludge, watcher and wizard).
- **Seal turn-in** for Over-aspected items is not built. The client's
  event crier NPC script is empty.
- **The event music** (quest etc304 plays track 29 under work 20) is not
  played.
- **Aggro rule.** A monster only aggroes a target whose level is close to
  its own, and the target's level is always read as 1 today (an older
  bug, not fixed here). So the voidsent use the "any level" detection
  flag. Monsters now never aggro townsfolk, which that flag would
  otherwise let them do.

## Sources

- Square Enix forum, patch 1.23b notes (thread 54142, September 12, 2012):
  <https://forum.square-enix.com/ffxiv/threads/54142>
- Gamer Escape, patch 1.23b notes:
  <https://gamerescape.com/2012/09/12/patch-1-23b-notes/>
- Eyes on FF, patch 1.23b thread (player reports of times and drops):
  <https://home.eyesonff.com/showthread.php/144893-FFXIV-Patch-1-23b-Released>
- Gamer Escape wiki, Foundation Day (2012):
  <https://ffxiv.gamerescape.com/wiki/Foundation_Day_(2012)>
- Monster locations already in the repo:
  `tools/world_spawns/data/xivl_ge_mob_locations.csv`
- The 1.23b client's teleport menu and quest scripts, and its actor class
  and model data (read for behavior only, nothing copied).
