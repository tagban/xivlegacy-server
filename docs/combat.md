# Combat formulas

Every number the map server uses to resolve a fight, what it reads, where it
lives and where it came from. When you change a formula, change this page in
the same pull request.

Most rolls live in [`map-server/src/battle/utils.rs`](../map-server/src/battle/utils.rs).
Stat derivation lives in [`map-server/src/actor/chara.rs`](../map-server/src/actor/chara.rs).
Commands and status effects run Lua in `scripts/lua/commands/` and `scripts/lua/effects/`.

## Where the numbers come from

Each formula is tagged with its source, so it's clear which ones to replace
if better 1.0 data turns up:

| Tag | Meaning |
|---|---|
| **pmeteor** | Ported from Project Meteor's C# (`Map Server/Actors/Chara/Ai/Utils/BattleUtils.cs`), which tried to match 1.x |
| **pmeteor, fixed** | pmeteor's formula with a bug fixed; the fix is described |
| **retail** | Fitted to retail 1.x battle captures (xivl-captures) |
| **ours** | Chosen here because no source has a number. Fair game for tuning |

`dlvl` below is `defender level − attacker level`, unless a row says otherwise.

## Order of a physical action

`finish_action_physical`:

1. Roll a miss against `hitRate`.
2. On a hit, Stoneskin absorbs first.
3. Roll crit, then block, then parry. The first one that succeeds sets the hit type.
4. Subtract mitigation (Defense, then Damage Taken Down).
5. Scale enmity by the command's `enmityModifier`.

Spells (`finish_action_spell`) apply Stoneskin, roll resist, then crit, apply
Stoneskin again (pmeteor does both) and then subtract mitigation. Status
effect hooks (below) run around these steps and can change any rate before
it is rolled.

## Rates

All rates are percent and are clamped to 0–100 unless noted.

| Rate | Formula | Source | Code |
|---|---|---|---|
| Hit | `80 + clamp(2 × (attacker level − defender level), −60, +15) + clamp(RawHitRate + skill accuracyModifier, −100, 100) − RawEvadeRate + 0.5 × (status Accuracy − status Evasion)` | 80 base: pmeteor. Level term: ours (#121). pmeteor clamped hit buffs to 0..100, so accuracy downs did nothing; negatives count here. Accuracy/Evasion term: ours (#128) | `get_hit_rate` |
| Crit | `10 + 0.16 × skill bonusCritRate + RawCritRate` | pmeteor | `get_crit_rate` |
| Parry | `10 + 0.1 × Parry + RawParryRate`; 0 with a shield or from behind | pmeteor | `get_parry_rate` |
| Block | `min(2.5 × dlvl + 5 + 0.1 × DEX + 0.2 × BlockRate, 25) + RawBlockRate`; needs a shield, 0 from behind | pmeteor | `get_block_rate` |
| Resist (spells and elemental actions) | `15 + RawResistRate + 0.25 × (status MagicEvasion − status MagicAccuracy)` | 15 base: pmeteor. Magic accuracy term: ours (#128) | `get_resist_rate`, `magic_resist_shift` |
| Status from a command | `statusChance` (0–1; above 1 always lands). A spell's chance below 1 moves by the same magic shift as resist | pmeteor; shift ours (#128) | `try_status` |

The miss roll uses `action.hitRate` as it stands after the hooks have run, so
Paralysis (25% of physical actions set to 0) and Presence of Mind (−20 from
the sides and back) take effect (#126).

**Resist tiers.** `try_resist` keeps rolling against the resist rate, halving
it each time, for up to four tiers: single, double, triple, full. Each tier
removes 25% of the damage. pmeteor kept the resisted share instead of the
dealt share, so a single resist dealt 25% and a full resist 100%. That is
fixed here (**pmeteor, fixed**). As in pmeteor's `ActionLanded`, single and
double resists count as "not landed" and triple as landed. #121 deliberately
left that alone.

**Status share only.** The #128 terms (Accuracy, Evasion, MagicAccuracy,
MagicEvasion, potency) count only what status effects add or take away
(`Character::status_mod_totals`, carried on `CombatView.status`). Players
also derive these stats from DEX, MND and PIE, and gear can add them, but
the base rates above were tuned without those values, and monsters have
none. Counting the full totals would retune every fight, so that is left
for later.

## Damage

| Step | Formula | Source | Code |
|---|---|---|---|
| Level modifier | `dlvl ≥ 0: 0.35 × dlvl + 0.225`, else `0.01 × dlvl + 0.25`; clamped 0–1 | pmeteor | `calculate_dlvl_modifier` |
| Physical damage taken | `(amount − levelMod × Defense) × (1 − DamageTakenDown / 100)` | pmeteor | `calculate_physical_damage_taken` |
| Spell damage taken | `(amount − levelMod × (Defense + 0.67 × VIT + element resistance)) × (1 − DamageTakenDown / 100)` | pmeteor; elemental resistance term ours (#128). After patch 1.19, elements reduce damage taken. Negative resistance adds damage | `calculate_spell_damage_taken`, `elemental_resistance` |
| Crit | `amount × clamp(0.04 × dlvl² − 2 × dlvl + 1.20, 1.15, 1.75)` | pmeteor | `calculate_crit_damage` |
| Block | blocks `0.2% × Block + 0.1% × VIT` of the damage (all of it under Aegis Boon) | pmeteor | `calculate_block_damage` |
| Parry | deals 75% | pmeteor | `calculate_parry_damage` |
| Stoneskin | absorbs up to its remaining pool, which shrinks by what it took | pmeteor | `handle_stoneskin` |

Every amount is clamped to 0–9999.

### Auto-attack

`base = 0.4 × (WeaponDamagePower + 0.85 × STR + Attack)`, times a random
`0.96–1.04`, clamped 1–9999 (`attack_calculate_base_damage`).

Source: **pmeteor, fixed**, scaled to **retail**. pmeteor's live auto-attack is
a placeholder (`Random.Next(10) * 10`). This is the formula it sketched in a
comment in `weaponskill.lua`. That comment's spread reads `* 8`, a typo for
`* 0.08` (the text beside it says "~8% max deviation"). Our derived `Attack`
stands in for pmeteor's `0.65 × capped secondary stat`.

The `0.4` (`PHYSICAL_DAMAGE_SCALE`) is fitted to the retail 1.23b
`party_battle_leve` capture (xivl-captures `battle-result-actor-join`). There,
a level 27 gladiator's swings on level 30 monsters did 18–23, and the unscaled
sum gave about 3× that. Before it, a level 1–20 swing took 20–30% of a
same-level monster's HP and weaponskills one-shot them. Weaponskills scale off
this hit, so they shrink with it.

### Balance targets (levels 1–20)

`battle_balance_auto_attacks` checks these at levels 1, 5, 10, 15 and 20 for
all seven classes, with real weapons and no armor:

| Fight | Target | Now |
|---|---|---|
| A player's swing on a same-level monster | 5–15% of its HP | 6–13% (casters 6–7%, LNC and MRD 10–13%) |
| A monster's swing on a same-level player | 4–10% of the player's HP | 6–7% |
| Level 27 GLA on a level 30 monster | retail 18–23 | 17 |
| Level 30 monster on a level 27 GLA | retail 56–63 | 64 |
| A weaponskill or attack spell (`battle_behavior_l20_numbers`) | 4–75% of a same-level monster's HP | 18–65% (PUG's retail 5× multipliers are at the top) |

A monster's TP move takes 17–24% of a same-level player's HP.

### Monster melee stats

Monsters whose pool and genus rows give no stats get fallback stats
(`monster_melee_stats`, **ours**, sized to retail):

- Melee power `0.07 × player HP at that level + 1.5 + 0.3 × level` is split a
  quarter, a half and a quarter over WeaponDamagePower, STR (÷ 0.85) and
  Attack, before the 0.4 scale. A same-level swing then takes about 7% of a
  player's HP. Retail: a level 30 monster took 56–63 off a gladiator with 750
  HP.
- Defense equals the level. With the full level modifier, a level 30 monster
  takes about 30 off a level 27 player's swing. At the same level it takes
  0.225 × level.

### Skill power (seed 291, #111)

`skill_amount`:

- **Spells, heals and stat-scaled abilities** (`magicPotency > 0`):
  `magicPotency / 1000 × (4 × level + 20 + mainStatMod × mainStat + secondStatMod × secondStat)`,
  times `0.96–1.04`. The potencies and stat weights come from the
  Meteor-era command workbook (**pmeteor**). The `4 × level + 20` term is
  fitted (**retail**): a level 26–27 Cure (1000, MND × 0.2) healed 151–166,
  and Second Wind (1550, INT × 0.5) about 205.
- **Physical weaponskills:** the user's own auto-attack hit times the
  command's `damageMultiplier` (**retail**: Fast Blade 3.1× for a gladiator,
  Heavy Swing 1.8× for a marauder). Skills with no capture use 2.5×
  (**ours**).
- Commands with no power data keep their `basePotency`.

### Magic potency (#128)

`apply_magic_potency` scales damage spells by AttackMagicPotency and heals by
HealingMagicPotency:

- Status effects use the ratio of the current value to the value without
  them. Cleric Stance (×1.2 to one, ×0.8 to the other) gives exactly those
  factors. An actor whose potency without effects is 0, such as a monster,
  takes 1% per point instead.
- Gear and traits add 1% per point. Before, they went into the ratio too, so
  the level 8 thaumaturge trait's +8 over an INT-derived 7 doubled every spell
  (Fire took 63% of a level 10 monster), and conjurer traits made a level 18
  Cure ×2.6.

The scale is clamped to 0.25–4. Source: **ours**.

## Stats and pools

Players' primary stats are a **placeholder** (**ours**). The real 1.x growth
curves, race bases and guardian bonuses were never reversed, and pmeteor
leaves players at zero (`apply_player_stat_baseline`):

| Value | Formula |
|---|---|
| STR, VIT, DEX, INT, MND, PIE | `8 + 2 × level`, +2 to the two the class emphasizes |
| Max HP | `110 + 3.5 × level + 0.82 × level²` (**retail** fit: 126 at 3, 148 at 5, 758 at 26 and 750 at 27 in the captures; 2634 at 50 with gear) |
| Max MP | Casters (THM, CNJ): `80 + 20 × level`. Others: `50 + 12 × level`, enough for the ~280 MP abilities at 50 (#116) |
| TP | Max 3000 |

Gear `paramBonus` is added on top. Secondary stats are then derived
(`apply_player_stat_derivation`, **pmeteor** `Player.CalculateBaseStats`):

| From | To |
|---|---|
| STR × 0.667 | Attack |
| DEX × 0.667 | Accuracy |
| VIT × 0.667 | Defense |
| INT × 0.25 | AttackMagicPotency |
| MND × 0.25 | MagicAccuracy, HealingMagicPotency, EnhancementMagicPotency (the last added in #117 so Protect and Stoneskin have a size) |
| PIE × 0.25 | MagicEvasion, EnfeeblingMagicPotency |

pmeteor's `AddMod(Modifier.Hp, (float)Modifier.Vitality)` adds the enum's
value (a constant 4), not VIT, so it is skipped.

A stat recalc keeps spent HP and MP spent: a full pool stays full at the new
maximum, anything else is clamped (#126). Before #126, every status gain or
loss refilled both.

Auto-attack range is the AttackRange modifier when set. Otherwise it is
20 yalms for archers and 3 for everyone else (**ours**, #123).

## TP and enmity

| What | Formula | Source |
|---|---|---|
| TP per landed swing | `attack delay in seconds × 100` | pmeteor `Character.OnAttack` |
| TP from damage taken | `ceil(5 × e^(−0.0667 × level) × damage)` | pmeteor `Character.OnDamageTaken` |
| TP while sheathed | −90 per 3 s tick, down to 0 | pmeteor's comment on Regain ("−90 out of combat"); wired by us |
| Enmity | damage dealt × the command's `enmityModifier`; hooks can change the modifier (Shroud of Saints halves it) | pmeteor |

## Ticks: regen, poison and onTick

Every 3 s (`COMBAT_TICK_INTERVAL_MS`), `regen_tick` moves the pools:

- HP by `Regen − RegenDown`;
- MP by `Refresh`;
- TP by `Regain`;
- plus the passive regen out of combat (`compute_passive_regen`, **ours**): 2% of max HP a tick with the weapon sheathed, 1% drawn (at least 1 HP). No MP regen, as in 1.x. Nothing while engaged or dead.

Regen, Poison, Aero, Bloodletter, Goring Blade and the songs work by setting
these modifiers in their `onGain`.

An effect with a tick interval (`tickMs` in `server_statuseffects`) also runs
its `onTick` on that interval (#126). Excruciate grows its crit bonus there,
Rampage sheds a stack and Blissful Mind banks MP.

## Command and effect scripts

The Lua side settles the status a command applies; Rust does the rolls.

- **Command setup** (`run_command_setup`) runs a command's `on*Start` and
  `onSkillFinish` and reads back `skill.statusId`, `statusDuration`,
  `statusMagnitude`, `statusTier` and `statusChance`. Examples: Protect's size
  is EnhancementMagicPotency; Regen's is `0.625 × potency − 109` (**pmeteor**, from a
  White Mage guide written for endgame gear), with a floor of
  `1 + level / 5` so low potency still heals (**ours**, #126). The script also sees
  the caster's statuses, so toggles (Rampage, Berserk, Cleric Stance, Power
  Surge) end their buff on reuse instead of reapplying it (#126).
- **Effect scripts** change modifiers in `onGain`; Rust records the net change
  and takes it off on loss (#112).
- **Combat hooks** (#119) run when the effect's flags ask for them
  (`ACTIVATE_ON_*` in [`status/flags.rs`](../map-server/src/status/flags.rs)):
  - `onCommandStart` and `onMagicCast` change the command before it rolls;
  - `onPreAction` changes the rates (as the attacker or the target);
  - `onHit`, `onCrit`, `onMiss`, `onEvade`, `onParry`, `onBlock`, `onDamageTaken` and `onHealed` react to the outcome;
  - `onCommandFinish` runs after the command resolves.
- **PREVENT_*** flags refuse the owner's own commands (text 32535), interrupt
  a cast in progress and stop movement or turning (#126).
- **Speed effects** scale MovementSpeed, and the client is sent the new run
  speed (0x00D0) when it changes (#126).

The audit of all 103 effects, with what each one changes, is the table in
[#126](https://github.com/tagban/xivlegacy-server/pull/126).

## EXP

| What | Formula | Source |
|---|---|---|
| Base EXP | `BASE_EXP[min(player, mob level)] × levelMod × party`; 0 when the mob is 20+ levels below | pmeteor `GetBaseEXP` |
| `levelMod` (`dlvl = mob − player`) | `dlvl ≥ 0: 1 + 0.2 × dlvl`, else `1 + 0.1 × dlvl + 0.0025 × dlvl²` | pmeteor |
| Party | 1.0 solo, 0.667 in a group of 2 or more | pmeteor (its own note says this isn't settled) |
| Link bonus | 0, 25, 50, 75, 100% for 0–4+ links | pmeteor |
| Chain bonus by tier | 0, 20, 25, 30, 40, 50% | pmeteor |
| Chain time limit by tier | 100, 80, 60, 20, 10 s | pmeteor |

## Not modeled yet

- Accuracy, evasion and potency from base stats and gear (see "Status share
  only" above). Monsters have no accuracy, evasion or potency of their own.
- Knockback, so KnockbackImmune (Tempered Will) does nothing.
- Ammo use, so Refill has nothing to refill.
- Party and enmity bindings for hooks: Cover/Covered, Collusion and Divine
  Veil's party Regen are partial.
- Real player growth curves (the stat table above is a placeholder).
- Crit potency and crit resilience (pmeteor has them commented out).
