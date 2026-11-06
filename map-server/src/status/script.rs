// garlemald-server — Rust port of a FINAL FANTASY XIV v1.23b server emulator (lobby/world/map)
// Copyright (C) 2026  Samuel Stegall
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Runs a status effect's `onGain` (`scripts/lua/effects/<name>.lua`) and
//! records what it does to the owner's modifiers.
//!
//! The scripts use the Meteor shape: `owner.AddMod(modifiersGlobal.X,
//! effect.GetMagnitude())` and a mirror-image `SubtractMod` in `onLose`.
//! Rather than trusting every `onLose` to undo its `onGain` exactly (several
//! re-roll the magnitude with `SetMagnitude`, `MultiplyMod` doesn't invert
//! cleanly from a changed base), the net change `onGain` makes to each
//! modifier is kept on the character and taken back off when the effect
//! goes. See `Character::apply_status_mods`.

use std::collections::HashMap;
use std::path::Path;
use std::sync::{Arc, Mutex};

use anyhow::{Context, Result};
use mlua::{Lua, Table, Value, Variadic};

use crate::actor::modifier::{Modifier, ModifierMap};

/// What the script can read about its owner.
#[derive(Debug, Clone, Default)]
pub struct OwnerView {
    pub mods: ModifierMap,
    pub level: i16,
    pub max_hp: i32,
    pub max_mp: i32,
    /// The statuses the owner holds, by id (command setup reads them).
    pub status_ids: Vec<u32>,
    /// The traits the owner has, by id (`HasTrait`).
    pub traits: Vec<u32>,
}

/// The effect's own numbers, as the container holds them.
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct EffectView {
    pub magnitude: f64,
    pub tier: u8,
    pub extra: f64,
    pub duration: u32,
    /// Who put the effect on (`effect.GetSource()`): the paladin behind
    /// Covered, the warrior behind Collusion. 0 when unknown.
    pub source: u32,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct GainOutcome {
    /// Net change per raw modifier id, non-zero entries only.
    pub mod_deltas: Vec<(u32, f64)>,
    /// HP the script handed out with `owner.AddHP` (negative for `DelHP`).
    pub hp: i32,
}

struct State {
    start: ModifierMap,
    mods: ModifierMap,
    level: i16,
    max_hp: i32,
    max_mp: i32,
    hp: i32,
    effect: EffectView,
    traits: Vec<u32>,
}

/// The arguments of a call made with either `owner.F(a, b)` or
/// `owner:F(a, b)` (the colon form passes the owner table first), by
/// position. Anything that isn't a number — a modifier name the script
/// misspelled reads as nil — is `None`.
fn numbers(args: &Variadic<Value>) -> Vec<Option<f64>> {
    let skip = usize::from(matches!(args.first(), Some(Value::Table(_))));
    args.iter()
        .skip(skip)
        .map(|v| match v {
            Value::Integer(i) => Some(*i as f64),
            Value::Number(n) => Some(*n),
            _ => None,
        })
        .collect()
}

fn method<T, F>(lua: &Lua, t: &Table, name: &str, st: &Arc<Mutex<T>>, f: F) -> mlua::Result<()>
where
    T: Send + 'static,
    F: Fn(&mut T, &[Option<f64>]) -> Value + Send + 'static,
{
    let st = st.clone();
    let func = lua.create_function(move |_, args: Variadic<Value>| {
        let n = numbers(&args);
        let mut s = st
            .lock()
            .map_err(|_| mlua::Error::runtime("status state poisoned"))?;
        Ok(f(&mut s, &n))
    })?;
    t.set(name, func)
}

fn arg(n: &[Option<f64>], i: usize) -> f64 {
    n.get(i).copied().flatten().unwrap_or(0.0)
}

/// The modifier a mod call names, or `None` when the script passed nil.
fn key(n: &[Option<f64>]) -> Option<u32> {
    n.first().copied().flatten().map(|k| k as u32)
}

fn build_owner(lua: &Lua, st: &Arc<Mutex<State>>) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    method(lua, &t, "AddMod", st, |s, n| {
        if let Some(k) = key(n) {
            s.mods.add_raw(k, arg(n, 1));
        }
        Value::Nil
    })?;
    method(lua, &t, "SubtractMod", st, |s, n| {
        if let Some(k) = key(n) {
            s.mods.subtract_raw(k, arg(n, 1));
        }
        Value::Nil
    })?;
    method(lua, &t, "SetMod", st, |s, n| {
        if let Some(k) = key(n) {
            s.mods.set_raw(k, arg(n, 1));
        }
        Value::Nil
    })?;
    method(lua, &t, "MultiplyMod", st, |s, n| {
        if let Some(k) = key(n) {
            let v = s.mods.get_raw(k) * arg(n, 1);
            s.mods.set_raw(k, v);
        }
        Value::Nil
    })?;
    method(lua, &t, "DivideMod", st, |s, n| {
        let d = arg(n, 1);
        if let Some(k) = key(n)
            && d != 0.0
        {
            let v = s.mods.get_raw(k) / d;
            s.mods.set_raw(k, v);
        }
        Value::Nil
    })?;
    method(lua, &t, "GetMod", st, |s, n| {
        Value::Number(key(n).map_or(0.0, |k| s.mods.get_raw(k)))
    })?;
    method(lua, &t, "GetLevel", st, |s, _| {
        Value::Integer(s.level as i64)
    })?;
    method(lua, &t, "GetMaxHP", st, |s, _| {
        Value::Number(s.max_hp as f64 + s.mods.get(Modifier::Hp) - s.start.get(Modifier::Hp))
    })?;
    method(lua, &t, "GetMaxMP", st, |s, _| {
        Value::Number(s.max_mp as f64 + s.mods.get(Modifier::Mp) - s.start.get(Modifier::Mp))
    })?;
    // Max HP is the Hp modifier after the stat recalc, so a new max is a
    // change to it.
    method(lua, &t, "SetMaxHP", st, |s, n| {
        let cur = s.max_hp as f64 + s.mods.get(Modifier::Hp) - s.start.get(Modifier::Hp);
        s.mods.add(Modifier::Hp, arg(n, 0).floor() - cur);
        Value::Nil
    })?;
    method(lua, &t, "AddHP", st, |s, n| {
        s.hp += arg(n, 0) as i32;
        Value::Nil
    })?;
    method(lua, &t, "DelHP", st, |s, n| {
        s.hp -= arg(n, 0) as i32;
        Value::Nil
    })?;
    method(lua, &t, "HasTrait", st, |s, n| {
        Value::Boolean(s.traits.contains(&(arg(n, 0) as u32)))
    })?;
    method(lua, &t, "SetProc", st, |_, _| Value::Nil)?;
    method(lua, &t, "SetCombos", st, |_, _| Value::Nil)?;
    // Gear isn't visible here.
    method(lua, &t, "HasItemEquippedInSlot", st, |_, _| {
        Value::Boolean(false)
    })?;
    t.set_metatable(Some(stub_meta(lua)?))?;
    Ok(t)
}

/// A metatable whose `__index` hands back a do-nothing value for anything
/// not bound, so `caster.statusEffects.HasStatusEffect(x)` or
/// `action.DoAction(...)` run as no-ops instead of aborting the script.
fn stub_meta(lua: &Lua) -> mlua::Result<Table> {
    let stub = lua.create_table()?;
    let stub_mt = lua.create_table()?;
    stub_mt.set(
        "__call",
        lua.create_function(|_, _: Variadic<Value>| Ok(Value::Nil))?,
    )?;
    stub.set_metatable(Some(stub_mt.clone()))?;
    let stub_for_index = stub.clone();
    stub_mt.set(
        "__index",
        lua.create_function(move |_, _: Variadic<Value>| Ok(stub_for_index.clone()))?,
    )?;
    let meta = lua.create_table()?;
    meta.set(
        "__index",
        lua.create_function(move |_, _: Variadic<Value>| Ok(stub.clone()))?,
    )?;
    Ok(meta)
}

fn new_lua(script_root: &Path) -> Result<Lua> {
    let lua = Lua::new();
    let root = script_root.display().to_string();
    let package: Table = lua.globals().get("package")?;
    package.set("path", format!("{root}/?.lua;{root}/?/init.lua"))?;
    // Same `bit32` stand-in the engine installs (`lua/globals.rs`);
    // `battleutils.lua` uses it at load time.
    lua.load(
        "bit32 = {
            band = function(...) local a = -1; for _, v in ipairs({...}) do a = a & v end; return a end,
            bor = function(...) local a = 0; for _, v in ipairs({...}) do a = a | v end; return a end,
            lshift = function(x, n) return x << n end,
            rshift = function(x, n) return x >> n end,
        }
        -- Not every effect script requires it itself.
        pcall(require, \"modifiers\")",
    )
    .exec()?;
    // Every hook gets a fresh state, and Lua seeds from the clock's
    // seconds: within one second every state would draw the same rolls
    // (Paralysis firing on every swing or none).
    static CALLS: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_nanos() as u64);
    let n = CALLS.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    let seed = (nanos ^ n.wrapping_mul(0x9E37_79B9_7F4A_7C15)) as i64;
    let math: Table = lua.globals().get("math")?;
    math.get::<mlua::Function>("randomseed")?
        .call::<()>((seed, n as i64))?;
    Ok(lua)
}

/// Script state that carries the effect's own numbers.
trait HasEffect: Send + 'static {
    fn effect(&mut self) -> &mut EffectView;
}

impl HasEffect for State {
    fn effect(&mut self) -> &mut EffectView {
        &mut self.effect
    }
}

fn build_effect<T: HasEffect>(lua: &Lua, st: &Arc<Mutex<T>>) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    method(lua, &t, "GetMagnitude", st, |s, _| {
        Value::Number(s.effect().magnitude)
    })?;
    method(lua, &t, "SetMagnitude", st, |s, n| {
        s.effect().magnitude = arg(n, 0);
        Value::Nil
    })?;
    method(lua, &t, "GetExtra", st, |s, _| {
        Value::Number(s.effect().extra)
    })?;
    method(lua, &t, "SetExtra", st, |s, n| {
        s.effect().extra = arg(n, 0);
        Value::Nil
    })?;
    method(lua, &t, "GetTier", st, |s, _| {
        Value::Integer(s.effect().tier as i64)
    })?;
    method(lua, &t, "SetTier", st, |s, n| {
        s.effect().tier = arg(n, 0) as u8;
        Value::Nil
    })?;
    method(lua, &t, "GetDuration", st, |s, _| {
        Value::Integer(s.effect().duration as i64)
    })?;
    // `effect.GetSource()`: an actor table with just `actorId`, enough for
    // `hateContainer.UpdateHate(effect.GetSource(), n)`. Anything else on
    // it is a stub (IsAlive() is nil), so scripts can't act on a stranger.
    let source = st
        .lock()
        .map_err(|_| mlua::Error::runtime("status state poisoned"))?
        .effect()
        .source;
    if source == 0 {
        method(lua, &t, "GetSource", st, |_, _| Value::Nil)?;
    } else {
        let src = lua.create_table()?;
        src.set("actorId", source)?;
        src.set_metatable(Some(stub_meta(lua)?))?;
        t.set(
            "GetSource",
            lua.create_function(move |_, _: Variadic<Value>| Ok(src.clone()))?,
        )?;
    }
    method(lua, &t, "RefreshTime", st, |_, _| Value::Nil)?;
    Ok(t)
}

/// Run `onGain` from `<script_root>/effects/<name>.lua`. A script with no
/// `onGain` (or no file) is a no-op, not an error.
pub fn run_on_gain(
    script_root: &Path,
    name: &str,
    owner: &OwnerView,
    effect: EffectView,
) -> Result<GainOutcome> {
    let path = script_root.join("effects").join(format!("{name}.lua"));
    if !path.exists() {
        return Ok(GainOutcome::default());
    }
    let source =
        std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;

    let lua = new_lua(script_root)?;
    lua.load(&source)
        .set_name(path.display().to_string())
        .exec()
        .map_err(|e| anyhow::anyhow!("loading {name}: {e}"))?;
    let Ok(on_gain) = lua.globals().get::<mlua::Function>("onGain") else {
        return Ok(GainOutcome::default());
    };

    let st = Arc::new(Mutex::new(State {
        start: owner.mods.clone(),
        mods: owner.mods.clone(),
        level: owner.level,
        max_hp: owner.max_hp,
        max_mp: owner.max_mp,
        hp: 0,
        effect,
        traits: owner.traits.clone(),
    }));
    let owner_t = build_owner(&lua, &st)?;
    let effect_t = build_effect(&lua, &st)?;
    on_gain
        .call::<()>((owner_t, effect_t, Value::Nil))
        .map_err(|e| anyhow::anyhow!("{name} onGain: {e}"))?;

    let s = st
        .lock()
        .map_err(|_| anyhow::anyhow!("status state poisoned"))?;
    let mut keys: Vec<u32> = s.mods.iter().map(|(k, _)| k).collect();
    keys.extend(s.start.iter().map(|(k, _)| k));
    keys.sort_unstable();
    keys.dedup();
    let mod_deltas = keys
        .into_iter()
        .filter_map(|k| {
            let d = s.mods.get_raw(k) - s.start.get_raw(k);
            (d.abs() > 1e-9).then_some((k, d))
        })
        .collect::<HashMap<_, _>>();
    let mut mod_deltas: Vec<(u32, f64)> = mod_deltas.into_iter().collect();
    mod_deltas.sort_by_key(|(k, _)| *k);
    Ok(GainOutcome {
        mod_deltas,
        hp: s.hp,
    })
}

/// The status numbers a battle command's script settles on before the
/// action lands (`skill.statusMagnitude = ...` and friends).
#[derive(Debug, Clone, Default, PartialEq)]
pub struct CommandStatus {
    pub status_id: u32,
    pub duration: u32,
    pub magnitude: f64,
    pub tier: u8,
    pub chance: f64,
    /// Statuses the script took off the caster
    /// (`caster.statusEffects.RemoveStatusEffect`), with the loss text it
    /// asked for (0: none given).
    pub removed: Vec<(u32, u16)>,
    /// The script ended a buff instead of calling `action.DoAction`: a
    /// toggle used with its buff up (Rampage, Berserk, Cleric Stance…), so
    /// the command lands no status.
    pub toggled_off: bool,
    /// `aoeType` (0 none, 1 circle, 2 cone, 3 box): traits widen
    /// Rampart and Flash.
    pub aoe_type: f64,
    /// A flat `action.enmity` the script set (Provoke 750, Flash 400).
    pub enmity: Option<f64>,
}

/// The `statusEffects` a command script sees on its caster: what the
/// caster holds, and a record of what the script removes.
#[derive(Default)]
struct SetupStatus {
    held: Vec<u32>,
    removed: Vec<(u32, u16)>,
    did_action: bool,
}

/// The status id a `RemoveStatusEffect` / `GetStatusEffectById` call names:
/// a number, or a buff table from `GetStatusEffectById`. Skips the
/// `statusEffects` table itself (colon form).
fn status_arg(args: &Variadic<Value>) -> Option<u32> {
    args.iter().find_map(|v| match v {
        Value::Integer(i) => Some(*i as u32),
        Value::Number(n) => Some(*n as u32),
        Value::Table(t) => t.get::<Option<u32>>("id").ok().flatten(),
        _ => None,
    })
}

fn build_setup_status(lua: &Lua, st: &Arc<Mutex<SetupStatus>>) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    let s = st.clone();
    t.set(
        "GetStatusEffectById",
        lua.create_function(move |lua, args: Variadic<Value>| {
            let held = status_arg(&args).filter(|id| {
                s.lock()
                    .is_ok_and(|s| s.held.contains(id) && !s.removed.iter().any(|r| r.0 == *id))
            });
            match held {
                Some(id) => {
                    let buff = lua.create_table()?;
                    buff.set("id", id)?;
                    buff.set_metatable(Some(stub_meta(lua)?))?;
                    Ok(Value::Table(buff))
                }
                None => Ok(Value::Nil),
            }
        })?,
    )?;
    let s = st.clone();
    t.set(
        "HasStatusEffect",
        lua.create_function(move |_, args: Variadic<Value>| {
            Ok(status_arg(&args).is_some_and(|id| {
                s.lock()
                    .is_ok_and(|s| s.held.contains(&id) && !s.removed.iter().any(|r| r.0 == id))
            }))
        })?,
    )?;
    let s = st.clone();
    t.set(
        "RemoveStatusEffect",
        lua.create_function(move |_, args: Variadic<Value>| {
            let one = |v: &Value| status_arg(&Variadic::from_iter([v.clone()]));
            let Some(at) = args.iter().position(|v| one(v).is_some()) else {
                return Ok(Value::Nil);
            };
            let id = one(&args[at]).unwrap_or_default();
            // The loss text is the last number after the status.
            let text = args
                .iter()
                .skip(at + 1)
                .rev()
                .find_map(|v| match v {
                    Value::Integer(i) => Some(*i as u16),
                    Value::Number(n) => Some(*n as u16),
                    _ => None,
                })
                .unwrap_or(0);
            let mut s = s
                .lock()
                .map_err(|_| mlua::Error::runtime("status state poisoned"))?;
            if s.held.contains(&id) && !s.removed.iter().any(|r| r.0 == id) {
                s.removed.push((id, text));
            }
            Ok(Value::Nil)
        })?,
    )?;
    t.set_metatable(Some(stub_meta(lua)?))?;
    Ok(t)
}

/// The command fields an `onCombo` script changes (pmeteor
/// `BattleCommand`): Thundara's potency and recast, Fira's cast time,
/// Bloodletter's status...
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct ComboSkill {
    pub base_potency: f64,
    pub cast_time_ms: f64,
    pub recast_time_ms: f64,
    pub aoe_type: f64,
    pub status_id: f64,
    pub status_chance: f64,
    pub status_duration: f64,
    pub status_magnitude: f64,
    pub num_hits: f64,
    pub accuracy_modifier: f64,
    pub bonus_crit_rate: f64,
    pub enmity_modifier: f64,
}

fn command_script(script_root: &Path, command_name: &str) -> Option<std::path::PathBuf> {
    ["ability", "magic", "weaponskill"]
        .iter()
        .map(|dir| {
            script_root
                .join("commands")
                .join(dir)
                .join(format!("{command_name}.lua"))
        })
        .find(|p| p.exists())
}

/// Run `hook(caster, target, skill)` from the command's script (pmeteor
/// `WeaponSkillState` / `MagicState`: `onCombo`, `onPositional`) and read
/// back what it changed on the skill. `None` when the command has no
/// script or no such hook.
pub fn run_command_skill_hook(
    script_root: &Path,
    command_name: &str,
    hook: &str,
    caster: &OwnerView,
    start: ComboSkill,
) -> Result<Option<ComboSkill>> {
    let Some(path) = command_script(script_root, command_name) else {
        return Ok(None);
    };
    let source =
        std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    if !source.contains(hook) {
        return Ok(None);
    }
    let lua = new_lua(script_root)?;
    lua.load(&source)
        .set_name(path.display().to_string())
        .exec()
        .map_err(|e| anyhow::anyhow!("loading {command_name}: {e}"))?;
    let Ok(f) = lua.globals().get::<mlua::Function>(hook) else {
        return Ok(None);
    };
    let st = Arc::new(Mutex::new(State {
        start: caster.mods.clone(),
        mods: caster.mods.clone(),
        level: caster.level,
        max_hp: caster.max_hp,
        max_mp: caster.max_mp,
        hp: 0,
        effect: EffectView::default(),
        traits: caster.traits.clone(),
    }));
    let caster_t = build_owner(&lua, &st)?;
    let setup = Arc::new(Mutex::new(SetupStatus {
        held: caster.status_ids.clone(),
        ..Default::default()
    }));
    caster_t.set("statusEffects", build_setup_status(&lua, &setup)?)?;
    let target_t = lua.create_table()?;
    target_t.set_metatable(Some(stub_meta(&lua)?))?;
    let fields: [(&str, f64); 12] = [
        ("basePotency", start.base_potency),
        ("castTimeMs", start.cast_time_ms),
        ("recastTimeMs", start.recast_time_ms),
        ("aoeType", start.aoe_type),
        ("statusId", start.status_id),
        ("statusChance", start.status_chance),
        ("statusDuration", start.status_duration),
        ("statusMagnitude", start.status_magnitude),
        ("numHits", start.num_hits),
        ("accuracyModifier", start.accuracy_modifier),
        ("bonusCritRate", start.bonus_crit_rate),
        ("enmityModifier", start.enmity_modifier),
    ];
    let skill = lua.create_table()?;
    for (k, v) in fields {
        skill.set(k, v)?;
    }
    skill.set_metatable(Some(stub_meta(&lua)?))?;
    if let Err(e) = f.call::<Value>((caster_t, target_t, skill.clone())) {
        tracing::debug!(command = command_name, hook, error = %e, "skill hook stopped early");
    }
    let num = |k: &str, d: f64| skill.raw_get::<Option<f64>>(k).ok().flatten().unwrap_or(d);
    Ok(Some(ComboSkill {
        base_potency: num("basePotency", start.base_potency),
        cast_time_ms: num("castTimeMs", start.cast_time_ms),
        recast_time_ms: num("recastTimeMs", start.recast_time_ms),
        aoe_type: num("aoeType", start.aoe_type),
        status_id: num("statusId", start.status_id),
        status_chance: num("statusChance", start.status_chance),
        status_duration: num("statusDuration", start.status_duration),
        status_magnitude: num("statusMagnitude", start.status_magnitude),
        num_hits: num("numHits", start.num_hits),
        accuracy_modifier: num("accuracyModifier", start.accuracy_modifier),
        // Godsbane spells it `critRateBonus`.
        bonus_crit_rate: num("critRateBonus", num("bonusCritRate", start.bonus_crit_rate)),
        enmity_modifier: num("enmityModifier", start.enmity_modifier),
    }))
}

/// Run the setup half of `commands/{ability,magic,weaponskill}/<name>.lua`
/// — `on*Start` then `onSkillFinish` with `action.DoAction` / `TryStatus`
/// as no-ops — and read back the status fields the script set on the
/// skill. Damage, healing and the status itself are still resolved by the
/// server. A script that errors part way keeps what it set before the
/// error. `None` when the command has no script.
pub fn run_command_setup(
    script_root: &Path,
    command_name: &str,
    caster: &OwnerView,
    start: CommandStatus,
) -> Result<Option<CommandStatus>> {
    let Some(path) = command_script(script_root, command_name) else {
        return Ok(None);
    };
    let source =
        std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    let lua = new_lua(script_root)?;
    lua.load(&source)
        .set_name(path.display().to_string())
        .exec()
        .map_err(|e| anyhow::anyhow!("loading {command_name}: {e}"))?;

    let st = Arc::new(Mutex::new(State {
        start: caster.mods.clone(),
        mods: caster.mods.clone(),
        level: caster.level,
        max_hp: caster.max_hp,
        max_mp: caster.max_mp,
        hp: 0,
        effect: EffectView::default(),
        traits: caster.traits.clone(),
    }));
    let caster_t = build_owner(&lua, &st)?;
    let setup = Arc::new(Mutex::new(SetupStatus {
        held: caster.status_ids.clone(),
        ..Default::default()
    }));
    caster_t.set("statusEffects", build_setup_status(&lua, &setup)?)?;
    let skill = lua.create_table()?;
    skill.set("statusId", start.status_id)?;
    skill.set("statusDuration", start.duration)?;
    skill.set("statusMagnitude", start.magnitude)?;
    skill.set("statusTier", start.tier)?;
    skill.set("statusChance", start.chance)?;
    skill.set("aoeType", start.aoe_type)?;
    let action = lua.create_table()?;
    let action_t = action.clone();
    let s = setup.clone();
    action.set(
        "DoAction",
        lua.create_function(move |_, _: Variadic<Value>| {
            if let Ok(mut s) = s.lock() {
                s.did_action = true;
            }
            Ok(Value::Nil)
        })?,
    )?;
    action.set_metatable(Some(stub_meta(&lua)?))?;
    let container = lua.create_table()?;
    container.set_metatable(Some(stub_meta(&lua)?))?;

    let g = lua.globals();
    let mut failed = None;
    let has_finish = g.get::<mlua::Function>("onSkillFinish").is_ok();
    for hook in ["onAbilityStart", "onMagicStart", "onSkillStart"] {
        if let Ok(f) = g.get::<mlua::Function>(hook) {
            if let Err(e) = f.call::<Value>((caster_t.clone(), caster_t.clone(), skill.clone())) {
                failed = Some(format!("{hook}: {e}"));
            }
            break;
        }
    }
    if failed.is_none()
        && let Ok(f) = g.get::<mlua::Function>("onSkillFinish")
        && let Err(e) = f.call::<Value>((
            caster_t.clone(),
            caster_t.clone(),
            skill.clone(),
            action,
            container,
        ))
    {
        failed = Some(format!("onSkillFinish: {e}"));
    }
    if let Some(e) = &failed {
        tracing::debug!(command = command_name, error = %e, "command setup stopped early");
    }
    let num = |k: &str, d: f64| skill.get::<Option<f64>>(k).ok().flatten().unwrap_or(d);
    let (removed, did_action) = setup
        .lock()
        .map(|s| (s.removed.clone(), s.did_action))
        .unwrap_or_default();
    Ok(Some(CommandStatus {
        toggled_off: has_finish && failed.is_none() && !did_action && !removed.is_empty(),
        removed,
        status_id: num("statusId", start.status_id as f64) as u32,
        duration: num("statusDuration", start.duration as f64) as u32,
        magnitude: num("statusMagnitude", start.magnitude),
        tier: num("statusTier", start.tier as f64) as u8,
        chance: num("statusChance", start.chance),
        aoe_type: num("aoeType", start.aoe_type),
        enmity: action_t.raw_get::<Option<f64>>("enmity").ok().flatten(),
    }))
}

// ---------------------------------------------------------------------------
// Combat hooks: onPreAction, onHit, onDamageTaken, onCommandStart...
// ---------------------------------------------------------------------------

/// One actor a combat hook can see: the effect's owner or the other side
/// of the action.
#[derive(Debug, Clone, Default)]
pub struct HookActor {
    pub actor_id: u32,
    pub mods: ModifierMap,
    pub level: i16,
    pub hp: i32,
    pub max_hp: i32,
    pub mp: i32,
    pub max_mp: i32,
    pub tp: i32,
    pub status_ids: Vec<u32>,
    pub traits: Vec<u32>,
    /// Which side it fights on: 1 players and their allies, 2 monsters
    /// (pmeteor `Character.allegiance`; Decoy only dodges a foe's attack).
    pub allegiance: u32,
}

/// What a hook did to one actor.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct HookActorChange {
    /// Net change per raw modifier id, non-zero entries only.
    pub mod_deltas: Vec<(u32, f64)>,
    pub hp: i32,
    pub mp: i32,
    pub tp: i32,
    /// Other statuses the hook took off this actor, by id.
    pub removed: Vec<u32>,
    /// Enmity to add to this actor's hate list, by the actor it is toward
    /// (`defender.hateContainer.UpdateHate(who, n)`, Collusion).
    pub hate: Vec<(u32, i32)>,
    /// Statuses for this actor's party (`AddPartyStatusEffect`, Divine
    /// Veil's Divine Regen). They need other actors, so the caller hands
    /// them out once no actor is locked.
    pub party_status: Vec<HookPartyStatus>,
}

/// `owner.AddPartyStatusEffect(range, statusId, tier, magnitude, duration)`:
/// a status for every party member of `owner` within `range` yalms of
/// them, `owner` included.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HookPartyStatus {
    pub owner: u32,
    pub range: f32,
    pub status_id: u32,
    pub tier: u8,
    pub magnitude: f64,
    pub duration: u32,
}

impl HookActorChange {
    pub fn is_empty(&self) -> bool {
        *self == Self::default()
    }
}

/// The command fields hooks read and change (`skill.numHits`,
/// `skill.mpCost`, `skill.bonusCritRate`...).
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct HookSkill {
    pub id: u32,
    pub command_type: u16,
    pub action_type: u8,
    pub num_hits: u8,
    pub enmity_modifier: f64,
    pub accuracy_modifier: f64,
    pub bonus_crit_rate: f64,
    pub mp_cost: f64,
    pub tp_cost: f64,
    pub cast_time_ms: f64,
    pub recast_time_ms: f64,
    pub range: f64,
    pub is_ranged: bool,
}

/// The rolled action fields hooks read and change (`action.amount`,
/// `action.critRate`...). `param` is the hit direction (`HitDirection`).
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct HookAction {
    pub amount: f64,
    pub amount_mitigated: f64,
    pub enmity: f64,
    pub hit_rate: f64,
    pub crit_rate: f64,
    pub block_rate: f64,
    pub parry_rate: f64,
    pub resist_rate: f64,
    pub param: u8,
    pub world_master_text_id: u16,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HookRowKind {
    /// `AddHPAction`: HP restored to the target.
    Hp,
    /// `AddHPAbsorbAction`: HP drained back to the attacker.
    HpAbsorb,
    /// `AddMPAction`.
    Mp,
    /// `AddMPAbsorbAction`.
    MpAbsorb,
    /// `AddHitAction`: damage dealt back (Vengeance).
    Hit,
}

/// An extra battle-log row a hook added to the action.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HookRow {
    pub kind: HookRowKind,
    pub target_actor_id: u32,
    pub text_id: u16,
    pub amount: u16,
}

/// `owner.statusEffects.ReplaceEffect(effect, id, tier, magnitude, duration)`.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HookReplace {
    pub status_id: u32,
    pub tier: u8,
    pub magnitude: f64,
    pub duration: u32,
}

#[derive(Debug, Clone, Default, PartialEq)]
pub struct HookOutcome {
    pub owner: HookActorChange,
    pub other: HookActorChange,
    /// The effect's numbers after the hook (`SetExtra`, `SetTier`...).
    pub effect: EffectView,
    /// The hook removed its own effect.
    pub remove_self: bool,
    pub replace: Option<HookReplace>,
    pub skill: HookSkill,
    pub action: Option<HookAction>,
    pub rows: Vec<HookRow>,
}

/// One hook call on one effect.
pub struct HookCall<'a> {
    pub hook: &'a str,
    pub effect_name: &'a str,
    pub effect: EffectView,
    pub owner: &'a HookActor,
    pub other: Option<&'a HookActor>,
    /// The owner is the one acting (attacker / caster); otherwise it is
    /// on the receiving end. Picks the argument order for
    /// `(effect, attacker, defender, ...)` hooks.
    pub owner_acts: bool,
    pub skill: HookSkill,
    pub action: Option<HookAction>,
}

struct Side {
    start: ModifierMap,
    mods: ModifierMap,
    actor: HookActor,
    hp: i32,
    mp: i32,
    tp: i32,
    removed: Vec<u32>,
    hate: Vec<(u32, i32)>,
    party_status: Vec<HookPartyStatus>,
}

impl Side {
    fn new(actor: &HookActor) -> Self {
        Self {
            start: actor.mods.clone(),
            mods: actor.mods.clone(),
            actor: actor.clone(),
            hp: 0,
            mp: 0,
            tp: 0,
            removed: Vec::new(),
            hate: Vec::new(),
            party_status: Vec::new(),
        }
    }

    fn change(&self) -> HookActorChange {
        let mut keys: Vec<u32> = self.mods.iter().map(|(k, _)| k).collect();
        keys.extend(self.start.iter().map(|(k, _)| k));
        keys.sort_unstable();
        keys.dedup();
        HookActorChange {
            mod_deltas: keys
                .into_iter()
                .filter_map(|k| {
                    let d = self.mods.get_raw(k) - self.start.get_raw(k);
                    (d.abs() > 1e-9).then_some((k, d))
                })
                .collect(),
            hp: self.hp,
            mp: self.mp,
            tp: self.tp,
            removed: self.removed.clone(),
            hate: self.hate.clone(),
            party_status: self.party_status.clone(),
        }
    }
}

struct Fx {
    effect: EffectView,
    remove_self: bool,
    replace: Option<HookReplace>,
    rows: Vec<HookRow>,
}

impl HasEffect for Fx {
    fn effect(&mut self) -> &mut EffectView {
        &mut self.effect
    }
}

fn clamp_u16(v: f64) -> u16 {
    v.floor().clamp(0.0, f64::from(u16::MAX)) as u16
}

fn build_side(lua: &Lua, st: &Arc<Mutex<Side>>, fx: &Arc<Mutex<Fx>>) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    let actor_id = st
        .lock()
        .map_err(|_| mlua::Error::runtime("status state poisoned"))?
        .actor
        .actor_id;
    t.set("actorId", actor_id)?;
    t.set(
        "allegiance",
        st.lock()
            .map_err(|_| mlua::Error::runtime("status state poisoned"))?
            .actor
            .allegiance,
    )?;
    method(lua, &t, "AddMod", st, |s, n| {
        if let Some(k) = key(n) {
            s.mods.add_raw(k, arg(n, 1));
        }
        Value::Nil
    })?;
    method(lua, &t, "SubtractMod", st, |s, n| {
        if let Some(k) = key(n) {
            s.mods.subtract_raw(k, arg(n, 1));
        }
        Value::Nil
    })?;
    method(lua, &t, "SetMod", st, |s, n| {
        if let Some(k) = key(n) {
            s.mods.set_raw(k, arg(n, 1));
        }
        Value::Nil
    })?;
    method(lua, &t, "GetMod", st, |s, n| {
        Value::Number(key(n).map_or(0.0, |k| s.mods.get_raw(k)))
    })?;
    method(lua, &t, "GetLevel", st, |s, _| {
        Value::Integer(i64::from(s.actor.level))
    })?;
    method(lua, &t, "GetHP", st, |s, _| {
        Value::Integer(i64::from((s.actor.hp + s.hp).clamp(0, s.actor.max_hp)))
    })?;
    method(lua, &t, "GetMaxHP", st, |s, _| {
        Value::Integer(i64::from(s.actor.max_hp))
    })?;
    method(lua, &t, "GetMP", st, |s, _| {
        Value::Integer(i64::from((s.actor.mp + s.mp).clamp(0, s.actor.max_mp)))
    })?;
    method(lua, &t, "GetMaxMP", st, |s, _| {
        Value::Integer(i64::from(s.actor.max_mp))
    })?;
    method(lua, &t, "GetTP", st, |s, _| {
        Value::Integer(i64::from(s.actor.tp + s.tp))
    })?;
    for (name, sign) in [("AddHP", 1), ("DelHP", -1)] {
        method(lua, &t, name, st, move |s, n| {
            s.hp += sign * arg(n, 0).floor() as i32;
            Value::Nil
        })?;
    }
    for (name, sign) in [("AddMP", 1), ("DelMP", -1)] {
        method(lua, &t, name, st, move |s, n| {
            s.mp += sign * arg(n, 0).floor() as i32;
            Value::Nil
        })?;
    }
    for (name, sign) in [("AddTP", 1), ("DelTP", -1)] {
        method(lua, &t, name, st, move |s, n| {
            s.tp += sign * arg(n, 0).floor() as i32;
            Value::Nil
        })?;
    }
    method(lua, &t, "HasTrait", st, |s, n| {
        Value::Boolean(s.actor.traits.contains(&(arg(n, 0) as u32)))
    })?;
    method(lua, &t, "AddPartyStatusEffect", st, move |s, n| {
        s.party_status.push(HookPartyStatus {
            owner: actor_id,
            range: arg(n, 0) as f32,
            status_id: arg(n, 1) as u32,
            tier: arg(n, 2) as u8,
            magnitude: arg(n, 3),
            duration: arg(n, 4).clamp(0.0, f64::from(u32::MAX)) as u32,
        });
        Value::Nil
    })?;

    // `hateContainer.UpdateHate(who, amount)`: `who` is an actor table
    // (`effect.GetSource()`, an attacker) or an actor id.
    let hate = lua.create_table()?;
    {
        let st = st.clone();
        hate.set(
            "UpdateHate",
            lua.create_function(move |_, args: Variadic<Value>| {
                let mut who: Option<u32> = None;
                let mut amount: Option<f64> = None;
                for v in args.iter() {
                    let n = match v {
                        Value::Table(t) => {
                            if who.is_none()
                                && let Ok(Some(id)) = t.raw_get::<Option<u32>>("actorId")
                            {
                                who = Some(id);
                            }
                            continue;
                        }
                        Value::Integer(i) => *i as f64,
                        Value::Number(n) => *n,
                        _ => continue,
                    };
                    if who.is_none() {
                        who = Some(n as u32);
                    } else if amount.is_none() {
                        amount = Some(n);
                    }
                }
                if let (Some(who), Some(amount)) = (who, amount)
                    && who != 0
                {
                    st.lock()
                        .map_err(|_| mlua::Error::runtime("status state poisoned"))?
                        .hate
                        .push((who, amount.floor() as i32));
                }
                Ok(Value::Nil)
            })?,
        )?;
    }
    hate.set_metatable(Some(stub_meta(lua)?))?;
    t.set("hateContainer", hate)?;

    let effects = lua.create_table()?;
    {
        let st = st.clone();
        let fx = fx.clone();
        // `RemoveStatusEffect(effect, actionContainer, textId, playEffect)`
        // or `RemoveStatusEffect(statusId)`. The hook's own effect lives
        // on its owner whichever side the script calls it through.
        effects.set(
            "RemoveStatusEffect",
            lua.create_function(move |_, args: Variadic<Value>| {
                let mut it = args.iter();
                let mut first = it.next();
                if let Some(Value::Table(t)) = first
                    && !t.contains_key("__hookEffect")?
                {
                    first = it.next();
                }
                match first {
                    Some(Value::Table(_)) => {
                        fx.lock()
                            .map_err(|_| mlua::Error::runtime("status state poisoned"))?
                            .remove_self = true;
                    }
                    Some(Value::Integer(i)) => st
                        .lock()
                        .map_err(|_| mlua::Error::runtime("status state poisoned"))?
                        .removed
                        .push(*i as u32),
                    Some(Value::Number(n)) => st
                        .lock()
                        .map_err(|_| mlua::Error::runtime("status state poisoned"))?
                        .removed
                        .push(*n as u32),
                    _ => {}
                }
                Ok(Value::Nil)
            })?,
        )?;
    }
    method(lua, &effects, "ReplaceEffect", fx, |s, n| {
        s.replace = Some(HookReplace {
            status_id: arg(n, 0) as u32,
            tier: arg(n, 1) as u8,
            magnitude: arg(n, 2),
            duration: arg(n, 3).clamp(0.0, f64::from(u32::MAX)) as u32,
        });
        Value::Nil
    })?;
    method(lua, &effects, "HasStatusEffect", st, |s, n| {
        Value::Boolean(
            n.first()
                .copied()
                .flatten()
                .is_some_and(|id| s.actor.status_ids.contains(&(id as u32))),
        )
    })?;
    effects.set_metatable(Some(stub_meta(lua)?))?;
    t.set("statusEffects", effects)?;
    t.set_metatable(Some(stub_meta(lua)?))?;
    Ok(t)
}

fn build_container(lua: &Lua, fx: &Arc<Mutex<Fx>>) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    for (name, kind) in [
        ("AddHPAction", HookRowKind::Hp),
        ("AddHPAbsorbAction", HookRowKind::HpAbsorb),
        ("AddMPAction", HookRowKind::Mp),
        ("AddMPAbsorbAction", HookRowKind::MpAbsorb),
        ("AddHitAction", HookRowKind::Hit),
    ] {
        method(lua, &t, name, fx, move |s, n| {
            s.rows.push(HookRow {
                kind,
                target_actor_id: arg(n, 0) as u32,
                text_id: arg(n, 1) as u16,
                amount: clamp_u16(arg(n, 2)),
            });
            Value::Nil
        })?;
    }
    t.set_metatable(Some(stub_meta(lua)?))?;
    Ok(t)
}

fn build_skill(lua: &Lua, s: &HookSkill) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    t.set("id", s.id)?;
    t.set("commandType", s.command_type)?;
    t.set("actionType", s.action_type)?;
    t.set("numHits", s.num_hits)?;
    t.set("enmityModifier", s.enmity_modifier)?;
    t.set("accuracyModifier", s.accuracy_modifier)?;
    t.set("bonusCritRate", s.bonus_crit_rate)?;
    t.set("mpCost", s.mp_cost)?;
    t.set("tpCost", s.tp_cost)?;
    t.set("castTimeMs", s.cast_time_ms)?;
    t.set("recastTimeMs", s.recast_time_ms)?;
    t.set("range", s.range)?;
    t.set("isRanged", s.is_ranged)?;
    for (getter, field) in [
        ("GetCommandType", "commandType"),
        ("GetActionType", "actionType"),
    ] {
        let me = t.clone();
        t.set(
            getter,
            lua.create_function(move |_, _: Variadic<Value>| me.get::<Value>(field))?,
        )?;
    }
    t.set_metatable(Some(stub_meta(lua)?))?;
    Ok(t)
}

fn read_skill(t: &Table, start: HookSkill) -> HookSkill {
    let num = |k: &str, d: f64| t.get::<Option<f64>>(k).ok().flatten().unwrap_or(d);
    HookSkill {
        num_hits: num("numHits", f64::from(start.num_hits)).clamp(0.0, 255.0) as u8,
        enmity_modifier: num("enmityModifier", start.enmity_modifier),
        accuracy_modifier: num("accuracyModifier", start.accuracy_modifier),
        bonus_crit_rate: num("bonusCritRate", start.bonus_crit_rate),
        mp_cost: num("mpCost", start.mp_cost),
        tp_cost: num("tpCost", start.tp_cost),
        cast_time_ms: num("castTimeMs", start.cast_time_ms),
        recast_time_ms: num("recastTimeMs", start.recast_time_ms),
        range: num("range", start.range),
        ..start
    }
}

fn build_action(lua: &Lua, a: &HookAction) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    t.set("amount", a.amount)?;
    t.set("amountMitigated", a.amount_mitigated)?;
    t.set("enmity", a.enmity)?;
    t.set("hitRate", a.hit_rate)?;
    t.set("critRate", a.crit_rate)?;
    t.set("blockRate", a.block_rate)?;
    t.set("parryRate", a.parry_rate)?;
    t.set("resistRate", a.resist_rate)?;
    t.set("param", a.param)?;
    t.set("worldMasterTextId", a.world_master_text_id)?;
    t.set_metatable(Some(stub_meta(lua)?))?;
    Ok(t)
}

fn read_action(t: &Table, start: HookAction) -> HookAction {
    let num = |k: &str, d: f64| t.get::<Option<f64>>(k).ok().flatten().unwrap_or(d);
    HookAction {
        amount: num("amount", start.amount).max(0.0),
        amount_mitigated: num("amountMitigated", start.amount_mitigated),
        enmity: num("enmity", start.enmity).max(0.0),
        hit_rate: num("hitRate", start.hit_rate),
        crit_rate: num("critRate", start.crit_rate),
        block_rate: num("blockRate", start.block_rate),
        parry_rate: num("parryRate", start.parry_rate),
        resist_rate: num("resistRate", start.resist_rate),
        world_master_text_id: num("worldMasterTextId", f64::from(start.world_master_text_id))
            as u16,
        ..start
    }
}

/// Run one combat hook of `<script_root>/effects/<effect_name>.lua`.
/// `None` when the script or the hook isn't there. A hook that errors part
/// way keeps what it did before the error.
pub fn run_hook(script_root: &Path, call: &HookCall<'_>) -> Result<Option<HookOutcome>> {
    let path = script_root
        .join("effects")
        .join(format!("{}.lua", call.effect_name));
    if !path.exists() {
        return Ok(None);
    }
    let source =
        std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
    // Most effects tick every 3 s and have no onTick; skip the Lua state.
    if !source.contains(call.hook) {
        return Ok(None);
    }
    let lua = new_lua(script_root)?;
    // The effect scripts use these without requiring them; Sentinel spells
    // the weaponskill command type `WeaponSkill`.
    lua.load(
        "pcall(require, \"battleutils\")
        pcall(require, \"utils\")
        if CommandType then CommandType.WeaponSkill = CommandType.Weaponskill end",
    )
    .exec()?;
    lua.load(&source)
        .set_name(path.display().to_string())
        .exec()
        .map_err(|e| anyhow::anyhow!("loading {}: {e}", call.effect_name))?;
    let Ok(f) = lua.globals().get::<mlua::Function>(call.hook) else {
        return Ok(None);
    };

    let fx = Arc::new(Mutex::new(Fx {
        effect: call.effect,
        remove_self: false,
        replace: None,
        rows: Vec::new(),
    }));
    let owner_st = Arc::new(Mutex::new(Side::new(call.owner)));
    let other_actor = call.other.cloned().unwrap_or_default();
    let other_st = Arc::new(Mutex::new(Side::new(&other_actor)));
    let effect_t = build_effect(&lua, &fx)?;
    effect_t.set("__hookEffect", true)?;
    effect_t.set_metatable(Some(stub_meta(&lua)?))?;
    let owner_t = build_side(&lua, &owner_st, &fx)?;
    let other_t = build_side(&lua, &other_st, &fx)?;
    let skill_t = build_skill(&lua, &call.skill)?;
    let action_t = match &call.action {
        Some(a) => Some(build_action(&lua, a)?),
        None => None,
    };
    let container_t = build_container(&lua, &fx)?;
    let action_v = action_t.clone().map_or(Value::Nil, Value::Table);

    let r = match call.hook {
        "onCommandStart" | "onCommandFinish" => {
            f.call::<Value>((effect_t, owner_t, skill_t.clone(), container_t))
        }
        "onMagicCast" => f.call::<Value>((effect_t, owner_t, skill_t.clone())),
        "onTick" => f.call::<Value>((owner_t, effect_t, container_t)),
        _ => {
            let (a, d) = if call.owner_acts {
                (owner_t, other_t)
            } else {
                (other_t, owner_t)
            };
            f.call::<Value>((effect_t, a, d, skill_t.clone(), action_v, container_t))
        }
    };
    if let Err(e) = r {
        tracing::debug!(effect = call.effect_name, hook = call.hook, error = %e, "status hook stopped early");
    }

    let lock = |m: &Arc<Mutex<Side>>| -> Result<HookActorChange> {
        Ok(m.lock()
            .map_err(|_| anyhow::anyhow!("status state poisoned"))?
            .change())
    };
    let owner = lock(&owner_st)?;
    let other = lock(&other_st)?;
    let fx = fx
        .lock()
        .map_err(|_| anyhow::anyhow!("status state poisoned"))?;
    Ok(Some(HookOutcome {
        owner,
        other,
        effect: fx.effect,
        remove_self: fx.remove_self,
        replace: fx.replace,
        skill: read_skill(&skill_t, call.skill),
        action: match (&action_t, call.action) {
            (Some(t), Some(a)) => Some(read_action(t, a)),
            _ => None,
        },
        rows: fx.rows.clone(),
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn root() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../scripts/lua")
    }

    fn owner() -> OwnerView {
        let mut mods = ModifierMap::new();
        mods.set(Modifier::Defense, 200.0);
        mods.set(Modifier::Accuracy, 160.0);
        mods.set(Modifier::Delay, 3.0);
        mods.set(Modifier::Hp, 400.0);
        OwnerView {
            mods,
            level: 20,
            max_hp: 400,
            max_mp: 100,
            status_ids: Vec::new(),
            traits: Vec::new(),
        }
    }

    fn fx(magnitude: f64) -> EffectView {
        EffectView {
            magnitude,
            ..Default::default()
        }
    }

    #[test]
    fn protect_adds_defense_from_magnitude() {
        let out = run_on_gain(&root(), "protect", &owner(), fx(10.0)).unwrap();
        let (k, d) = out.mod_deltas[0];
        assert_eq!((k, out.mod_deltas.len()), (Modifier::Defense.as_u32(), 1));
        assert!((d - 45.6).abs() < 1e-9, "{d}");
    }

    #[test]
    fn blind_takes_accuracy() {
        let out = run_on_gain(&root(), "blind", &owner(), fx(30.0)).unwrap();
        assert_eq!(out.mod_deltas, vec![(Modifier::Accuracy.as_u32(), -30.0)]);
    }

    #[test]
    fn blind_and_glare_without_a_size_take_the_owner_level() {
        // Flash and Gloom Arrow leave the magnitude at 0.
        for name in ["blind", "glare"] {
            let out = run_on_gain(&root(), name, &owner(), fx(0.0)).unwrap();
            assert_eq!(
                out.mod_deltas,
                vec![(Modifier::Accuracy.as_u32(), -20.0)],
                "{name}"
            );
        }
    }

    #[test]
    fn monster_poison_and_slow_without_a_size_get_one() {
        // Digestive Ooze and Sticky Web leave the magnitude at 0.
        let out = run_on_gain(&root(), "poison", &owner(), fx(0.0)).unwrap();
        assert_eq!(out.mod_deltas, vec![(Modifier::RegenDown.as_u32(), 10.0)]);
        let out = run_on_gain(&root(), "slow", &owner(), fx(0.0)).unwrap();
        let (k, d) = out.mod_deltas[0];
        assert_eq!(k, Modifier::Delay.as_u32());
        assert!((d - 0.75).abs() < 1e-9, "3.0 delay x1.25: {d}");
    }

    #[test]
    fn cleric_stance_records_potency_deltas() {
        let mut o = owner();
        o.mods.set(Modifier::AttackMagicPotency, 25.0);
        o.mods.set(Modifier::HealingMagicPotency, 25.0);
        let out = run_on_gain(&root(), "cleric_stance", &o, fx(0.0)).unwrap();
        let get = |m: Modifier| {
            out.mod_deltas
                .iter()
                .find(|(k, _)| *k == m.as_u32())
                .map(|d| d.1)
                .unwrap()
        };
        assert!((get(Modifier::AttackMagicPotency) - 5.0).abs() < 1e-9);
        assert!((get(Modifier::HealingMagicPotency) + 5.0).abs() < 1e-9);
    }

    #[test]
    fn haste_multiplies_attack_delay() {
        let out = run_on_gain(&root(), "haste", &owner(), fx(0.8)).unwrap();
        let (k, d) = out.mod_deltas[0];
        assert_eq!(k, Modifier::Delay.as_u32());
        assert!((d + 0.6).abs() < 1e-9, "{d}");
    }

    #[test]
    fn rampart_scales_with_level_through_set_magnitude() {
        let out = run_on_gain(&root(), "rampart", &owner(), fx(0.0)).unwrap();
        assert_eq!(out.mod_deltas, vec![(Modifier::Defense.as_u32(), 45.0)]);
    }

    #[test]
    fn hp_boost_raises_max_hp_and_heals_the_difference() {
        let out = run_on_gain(&root(), "hp_boost", &owner(), fx(0.0)).unwrap();
        assert_eq!(out.mod_deltas, vec![(Modifier::Hp.as_u32(), 100.0)]);
        assert_eq!(out.hp, 100);
    }

    #[test]
    fn a_nil_modifier_changes_nothing() {
        let lua_root = std::env::temp_dir().join(format!("status-script-{}", std::process::id()));
        std::fs::create_dir_all(lua_root.join("effects")).unwrap();
        std::fs::write(
            lua_root.join("effects/typo.lua"),
            "function onGain(owner, effect) owner.MultiplyMod(nil, 0.5); owner:AddMod(15, 2) end",
        )
        .unwrap();
        let out = run_on_gain(&lua_root, "typo", &owner(), fx(0.0)).unwrap();
        assert_eq!(out.mod_deltas, vec![(Modifier::Accuracy.as_u32(), 2.0)]);
        std::fs::remove_dir_all(lua_root).ok();
    }

    fn start(status_id: u32) -> CommandStatus {
        CommandStatus {
            status_id,
            duration: 30,
            magnitude: 0.0,
            tier: 1,
            chance: 1.0,
            ..Default::default()
        }
    }

    #[test]
    fn toggles_end_their_buff_instead_of_reapplying() {
        // Rampage with Rampage up: it ends, and Berserk goes too.
        let mut caster = owner();
        caster.status_ids = vec![223207, 223208];
        let out = run_command_setup(&root(), "rampage", &caster, start(223208))
            .unwrap()
            .unwrap();
        assert!(out.toggled_off);
        assert_eq!(out.removed, vec![(223207, 0), (223208, 30329)]);
        // Without it: Berserk would still go, and Rampage lands.
        caster.status_ids = vec![];
        let out = run_command_setup(&root(), "rampage", &caster, start(223208))
            .unwrap()
            .unwrap();
        assert!(!out.toggled_off);
        assert!(out.removed.is_empty());
        // Cleric Stance only ends itself.
        caster.status_ids = vec![223227];
        let out = run_command_setup(&root(), "cleric_stance", &caster, start(223227))
            .unwrap()
            .unwrap();
        assert!(out.toggled_off);
        assert_eq!(out.removed, vec![(223227, 30329)]);
        // Dread Spike eats a Power Surge for tier 2 and still lands.
        caster.status_ids = vec![223213];
        let out = run_command_setup(&root(), "dread_spike", &caster, start(223218))
            .unwrap()
            .unwrap();
        assert!(!out.toggled_off);
        assert_eq!((out.removed.clone(), out.tier), (vec![(223213, 30329)], 2));
    }

    #[test]
    fn flash_blinds_only_with_enhanced_flash() {
        let mut no_trait = start(223137);
        no_trait.chance = 0.0;
        let caster = owner();
        let out = run_command_setup(&root(), "flash", &caster, no_trait.clone())
            .unwrap()
            .unwrap();
        assert_eq!(out.chance, 0.0);
        let mut gla = owner();
        gla.traits = vec![27161];
        let out = run_command_setup(&root(), "flash", &gla, no_trait.clone())
            .unwrap()
            .unwrap();
        assert_eq!(out.chance, 1.0);
        assert_eq!(out.aoe_type, 0.0);
        gla.traits.push(27162);
        let out = run_command_setup(&root(), "flash", &gla, no_trait)
            .unwrap()
            .unwrap();
        assert_eq!(out.aoe_type, 1.0, "Enhanced Flash II makes it a circle");
    }

    #[test]
    fn protect_takes_its_magnitude_from_enhancing_potency() {
        let mut caster = owner();
        caster.mods.set(Modifier::EnhancementMagicPotency, 120.0);
        let out = run_command_setup(&root(), "protect", &caster, start(223128))
            .unwrap()
            .unwrap();
        assert_eq!(out.magnitude, 120.0);
        assert_eq!(out.status_id, 223128);
    }

    #[test]
    fn regen_keeps_a_floor_below_endgame_potency() {
        let mut caster = owner();
        caster.level = 50;
        caster.mods.set(Modifier::EnhancementMagicPotency, 40.0);
        let out = run_command_setup(&root(), "regen", &caster, start(223180))
            .unwrap()
            .unwrap();
        assert_eq!(out.magnitude, 11.0);
        // With the potency the formula was written for, the formula wins.
        caster.mods.set(Modifier::EnhancementMagicPotency, 400.0);
        let out = run_command_setup(&root(), "regen", &caster, start(223180))
            .unwrap()
            .unwrap();
        assert_eq!(out.magnitude, 141.0);
    }

    #[test]
    fn ability_start_hooks_set_magnitude() {
        let out = run_command_setup(&root(), "invigorate", &owner(), start(223094))
            .unwrap()
            .unwrap();
        assert_eq!(out.magnitude, 100.0);
        assert_eq!(out.duration, 30);
    }

    #[test]
    fn commands_without_a_script_are_none() {
        assert!(
            run_command_setup(&root(), "no_such_command", &owner(), start(1))
                .unwrap()
                .is_none()
        );
    }

    #[test]
    fn every_effect_and_command_script_runs() {
        let mut failed = Vec::new();
        for dir in [
            "effects",
            "commands/ability",
            "commands/magic",
            "commands/weaponskill",
        ] {
            for entry in std::fs::read_dir(root().join(dir)).unwrap() {
                let path = entry.unwrap().path();
                let name = path.file_stem().unwrap().to_string_lossy().to_string();
                let r = if dir == "effects" {
                    run_on_gain(&root(), &name, &owner(), fx(10.0)).map(|_| ())
                } else {
                    run_command_setup(&root(), &name, &owner(), start(1)).map(|_| ())
                };
                if let Err(e) = r {
                    failed.push(format!("{dir}/{name}: {e}"));
                }
            }
        }
        assert!(failed.is_empty(), "{}", failed.join("\n"));
    }

    #[test]
    fn fists_of_earth_adds_defense_and_drains_mp() {
        let out = run_on_gain(&root(), "fists_of_earth", &owner(), fx(0.0)).unwrap();
        assert_eq!(
            out.mod_deltas,
            vec![
                (Modifier::Defense.as_u32(), 20.0),
                (Modifier::Refresh.as_u32(), -3.0)
            ]
        );
        let mut tier2 = fx(0.0);
        tier2.tier = 2;
        let mut o = owner();
        o.mods.set(Modifier::Attack, 300.0);
        let out = run_on_gain(&root(), "fists_of_fire", &o, tier2).unwrap();
        assert_eq!(out.mod_deltas[0], (Modifier::Attack.as_u32(), 45.0));
    }

    #[test]
    fn effects_without_on_gain_or_a_script_do_nothing() {
        assert_eq!(
            run_on_gain(&root(), "sleep", &owner(), fx(1.0)).unwrap(),
            GainOutcome::default()
        );
        assert_eq!(
            run_on_gain(&root(), "no_such_effect", &owner(), fx(1.0)).unwrap(),
            GainOutcome::default()
        );
    }

    fn actor(id: u32) -> HookActor {
        HookActor {
            actor_id: id,
            mods: owner().mods,
            level: 50,
            hp: 1000,
            max_hp: 1500,
            mp: 200,
            max_mp: 400,
            tp: 0,
            status_ids: Vec::new(),
            traits: Vec::new(),
            allegiance: 1,
        }
    }

    fn skill(command_type: u16) -> HookSkill {
        HookSkill {
            id: 27150,
            command_type,
            action_type: 1,
            num_hits: 1,
            enmity_modifier: 1.0,
            mp_cost: 40.0,
            ..Default::default()
        }
    }

    fn hit(amount: f64) -> HookAction {
        HookAction {
            amount,
            enmity: amount,
            crit_rate: 5.0,
            ..Default::default()
        }
    }

    fn call<'a>(
        hook: &'a str,
        name: &'a str,
        owner: &'a HookActor,
        other: &'a HookActor,
        owner_acts: bool,
        skill: HookSkill,
        action: Option<HookAction>,
    ) -> HookCall<'a> {
        HookCall {
            hook,
            effect_name: name,
            effect: fx(0.0),
            owner,
            other: Some(other),
            owner_acts,
            skill,
            action,
        }
    }

    #[test]
    fn sentinel_adds_enmity_to_weaponskills() {
        let (me, foe) = (actor(1), actor(2));
        let out = run_hook(
            &root(),
            &call(
                "onHit",
                "sentinel",
                &me,
                &foe,
                true,
                skill(2),
                Some(hit(300.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.action.unwrap().enmity, 400.0);
        let out = run_hook(
            &root(),
            &call(
                "onHit",
                "sentinel",
                &me,
                &foe,
                true,
                skill(3),
                Some(hit(300.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.action.unwrap().enmity, 300.0);
    }

    #[test]
    fn life_surge_heals_the_attacker_on_auto_attacks() {
        let (me, foe) = (actor(1), actor(2));
        let out = run_hook(
            &root(),
            &call(
                "onHit",
                "life_surge_I",
                &me,
                &foe,
                true,
                skill(1),
                Some(hit(200.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.owner.hp, 21);
        assert_eq!(
            out.rows,
            vec![HookRow {
                kind: HookRowKind::HpAbsorb,
                target_actor_id: 2,
                text_id: 30332,
                amount: 21
            }]
        );
        assert!(out.other.is_empty());
    }

    #[test]
    fn dread_spike_soaks_a_physical_hit_and_goes() {
        let (me, foe) = (actor(1), actor(2));
        let out = run_hook(
            &root(),
            &call(
                "onDamageTaken",
                "dread_spike",
                &me,
                &foe,
                false,
                skill(2),
                Some(hit(300.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.action.unwrap().amount, 0.0);
        assert_eq!(out.owner.hp, 150);
        assert!(out.remove_self);
    }

    #[test]
    fn stoneskin_stays_until_its_absorb_is_spent() {
        let (mut me, foe) = (actor(1), actor(2));
        me.mods.set(Modifier::Stoneskin, 10.0);
        let out = run_hook(
            &root(),
            &call(
                "onDamageTaken",
                "stoneskin",
                &me,
                &foe,
                false,
                skill(1),
                Some(hit(30.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert!(!out.remove_self);
        me.mods.set(Modifier::Stoneskin, 0.0);
        let out = run_hook(
            &root(),
            &call(
                "onDamageTaken",
                "stoneskin",
                &me,
                &foe,
                false,
                skill(1),
                Some(hit(30.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert!(out.remove_self);
    }

    #[test]
    fn berserk_stacks_attack_on_hits() {
        let (me, foe) = (actor(1), actor(2));
        let out = run_hook(
            &root(),
            &call(
                "onHit",
                "berserk2",
                &me,
                &foe,
                true,
                skill(1),
                Some(hit(100.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.effect.extra, 1.0);
        assert!(
            out.owner
                .mod_deltas
                .contains(&(Modifier::Attack.as_u32(), 20.0))
        );
        assert!(
            out.owner
                .mod_deltas
                .contains(&(Modifier::Defense.as_u32(), -20.0))
        );
    }

    #[test]
    fn berserk_gives_its_stacks_back_when_hit() {
        let (me, foe) = (actor(1), actor(2));
        let mut c = call(
            "onDamageTaken",
            "berserk2",
            &me,
            &foe,
            false,
            skill(1),
            Some(hit(50.0)),
        );
        c.effect.extra = 3.0;
        let out = run_hook(&root(), &c).unwrap().unwrap();
        assert_eq!(out.effect.extra, 0.0);
        assert!(
            out.owner
                .mod_deltas
                .contains(&(Modifier::Attack.as_u32(), -60.0))
        );
        assert!(
            out.owner
                .mod_deltas
                .contains(&(Modifier::Defense.as_u32(), 60.0))
        );
    }

    #[test]
    fn blindside_crits_from_behind_and_is_spent() {
        let (me, foe) = (actor(1), actor(2));
        let mut a = hit(100.0);
        a.param = 4;
        let out = run_hook(
            &root(),
            &call(
                "onPreAction",
                "blindside2",
                &me,
                &foe,
                true,
                skill(2),
                Some(a),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.action.unwrap().crit_rate, 100.0);
        assert!(out.remove_self);
        a.param = 1;
        let out = run_hook(
            &root(),
            &call(
                "onPreAction",
                "blindside2",
                &me,
                &foe,
                true,
                skill(2),
                Some(a),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(out.action.unwrap().crit_rate, 5.0);
    }

    #[test]
    fn parsimony_halves_spell_mp() {
        let me = actor(1);
        let c = HookCall {
            hook: "onMagicCast",
            effect_name: "parsimony",
            effect: fx(0.0),
            owner: &me,
            other: None,
            owner_acts: true,
            skill: skill(4),
            action: None,
        };
        let out = run_hook(&root(), &c).unwrap().unwrap();
        assert_eq!(out.skill.mp_cost, 20.0);
    }

    #[test]
    fn power_surge_steps_up_on_a_weaponskill() {
        let me = actor(1);
        let mut c = HookCall {
            hook: "onCommandStart",
            effect_name: "power_surge_I",
            effect: fx(0.0),
            owner: &me,
            other: None,
            owner_acts: true,
            skill: skill(2),
            action: None,
        };
        c.effect.tier = 1;
        let out = run_hook(&root(), &c).unwrap().unwrap();
        assert_eq!(out.replace.map(|r| r.status_id), Some(223213));
    }

    #[test]
    fn hooks_a_script_lacks_are_none() {
        let (me, foe) = (actor(1), actor(2));
        assert!(
            run_hook(
                &root(),
                &call(
                    "onHit",
                    "protect",
                    &me,
                    &foe,
                    true,
                    skill(1),
                    Some(hit(1.0))
                )
            )
            .unwrap()
            .is_none()
        );
    }

    #[test]
    fn every_combat_hook_runs() {
        let (me, foe) = (actor(1), actor(2));
        let hooks = [
            "onPreAction",
            "onHit",
            "onCrit",
            "onMiss",
            "onBlock",
            "onParry",
            "onEvade",
            "onDamageTaken",
            "onHealed",
            "onCommandStart",
            "onCommandFinish",
            "onMagicCast",
            "onTick",
        ];
        let mut ran = 0;
        for entry in std::fs::read_dir(root().join("effects")).unwrap() {
            let path = entry.unwrap().path();
            let name = path.file_stem().unwrap().to_string_lossy().to_string();
            for hook in hooks {
                for ct in [1, 2, 3, 4] {
                    let r = run_hook(
                        &root(),
                        &call(hook, &name, &me, &foe, true, skill(ct), Some(hit(100.0))),
                    );
                    ran += usize::from(matches!(r, Ok(Some(_))));
                    assert!(r.is_ok(), "{name} {hook}: {:?}", r.err());
                }
            }
        }
        assert!(ran > 100, "{ran}");
    }

    fn tick<'a>(name: &'a str, me: &'a HookActor, effect: EffectView) -> HookCall<'a> {
        HookCall {
            hook: "onTick",
            effect_name: name,
            effect,
            owner: me,
            other: None,
            owner_acts: true,
            skill: HookSkill::default(),
            action: None,
        }
    }

    #[test]
    fn excruciate_climbs_each_tick() {
        let me = actor(1);
        let mut e = fx(0.0);
        e.tier = 1;
        let out = run_hook(&root(), &tick("excruciate", &me, e))
            .unwrap()
            .unwrap();
        assert_eq!(out.effect.magnitude, 25.0);
        e.tier = 2;
        let out = run_hook(&root(), &tick("excruciate", &me, e))
            .unwrap()
            .unwrap();
        assert_eq!(out.effect.magnitude, 50.0);
    }

    #[test]
    fn blissful_mind_banks_mp_then_becomes_fully_blissful() {
        let me = actor(1);
        let mut e = fx(10.0);
        e.tier = 1;
        let out = run_hook(&root(), &tick("blissful_mind", &me, e))
            .unwrap()
            .unwrap();
        // 0.3% of 400 max MP + 0.25 a tick.
        assert!(
            (out.effect.extra - 1.45).abs() < 1e-9,
            "{}",
            out.effect.extra
        );
        assert!(out.replace.is_none());
        e.extra = 9.0;
        let out = run_hook(&root(), &tick("blissful_mind", &me, e))
            .unwrap()
            .unwrap();
        assert_eq!(out.replace.map(|r| r.status_id), Some(223242));
    }

    #[test]
    fn rampage_sheds_a_stack_a_tick() {
        let me = actor(1);
        let mut e = fx(0.0);
        e.extra = 3.0;
        let out = run_hook(&root(), &tick("rampage2", &me, e))
            .unwrap()
            .unwrap();
        assert_eq!(out.effect.extra, 2.0);
        assert!(
            out.owner
                .mod_deltas
                .contains(&(Modifier::Parry.as_u32(), -20.0))
        );
        // Enduring March holds the stacks.
        let mut marching = actor(1);
        marching.status_ids.push(223078);
        let out = run_hook(&root(), &tick("rampage2", &marching, e))
            .unwrap()
            .unwrap();
        assert_eq!(out.effect.extra, 3.0);
    }

    #[test]
    fn effects_without_on_tick_are_none() {
        let me = actor(1);
        assert!(
            run_hook(&root(), &tick("protect", &me, fx(1.0)))
                .unwrap()
                .is_none()
        );
        assert!(
            run_hook(&root(), &tick("no_such_effect", &me, fx(1.0)))
                .unwrap()
                .is_none()
        );
    }

    #[test]
    fn paralysis_sometimes_fouls_the_attack() {
        let (me, foe) = (actor(1), actor(2));
        let mut fouled = 0;
        for _ in 0..200 {
            let mut a = hit(100.0);
            a.hit_rate = 80.0;
            let out = run_hook(
                &root(),
                &call(
                    "onPreAction",
                    "paralysis",
                    &me,
                    &foe,
                    true,
                    skill(1),
                    Some(a),
                ),
            )
            .unwrap()
            .unwrap();
            let rate = out.action.unwrap().hit_rate;
            assert!(rate == 0.0 || rate == 80.0, "{rate}");
            fouled += usize::from(rate == 0.0);
        }
        assert!((10..120).contains(&fouled), "{fouled}");
    }

    #[test]
    fn presence_of_mind_dodges_attacks_from_behind() {
        let (me, foe) = (actor(1), actor(2));
        for (param, want) in [(1, 80.0), (4, 60.0), (2, 60.0)] {
            let mut a = hit(100.0);
            a.hit_rate = 80.0;
            a.param = param;
            let out = run_hook(
                &root(),
                &call(
                    "onPreAction",
                    "presence_of_mind",
                    &me,
                    &foe,
                    false,
                    skill(1),
                    Some(a),
                ),
            )
            .unwrap()
            .unwrap();
            assert_eq!(out.action.unwrap().hit_rate, want, "direction {param}");
        }
    }

    #[test]
    fn shroud_of_saints_halves_enmity_and_refreshes() {
        let me = actor(1);
        let c = HookCall {
            hook: "onCommandStart",
            effect_name: "shroud_of_saints",
            effect: fx(0.0),
            owner: &me,
            other: None,
            owner_acts: true,
            skill: skill(4),
            action: None,
        };
        let out = run_hook(&root(), &c).unwrap().unwrap();
        assert_eq!(out.skill.enmity_modifier, 0.5);
        let gain = run_on_gain(&root(), "shroud_of_saints", &owner(), fx(0.0)).unwrap();
        assert_eq!(gain.mod_deltas, vec![(Modifier::Refresh.as_u32(), 2.0)]);
    }

    #[test]
    fn speed_effects_scale_the_run_speed() {
        let mut o = owner();
        o.mods.set(Modifier::MovementSpeed, 5.0);
        for (name, delta) in [("heavy", -1.0), ("quick", 1.25), ("swiftsong", 1.25)] {
            let out = run_on_gain(&root(), name, &o, fx(0.0)).unwrap();
            let d = out
                .mod_deltas
                .iter()
                .find(|(k, _)| *k == Modifier::MovementSpeed.as_u32())
                .map(|(_, d)| *d);
            assert!(d.is_some_and(|d| (d - delta).abs() < 1e-9), "{name}: {d:?}");
        }
    }

    #[test]
    fn collusion_hands_the_hits_enmity_to_its_source() {
        // The warrior (77) put Collusion on the attacker (1); the
        // attacker's hit on the monster (2) puts its enmity on the warrior.
        let attacker = actor(1);
        let mob = actor(2);
        let mut c = call(
            "onHit",
            "collusion",
            &attacker,
            &mob,
            true,
            skill(1),
            Some(hit(300.0)),
        );
        c.effect.source = 77;
        let out = run_hook(&root(), &c).unwrap().unwrap();
        assert_eq!(out.action.unwrap().enmity, 0.0);
        assert_eq!(out.other.hate, vec![(77, 300)]);
        assert!(out.owner.hate.is_empty());
        assert!(out.remove_self, "Collusion is used up by the hit");
    }

    #[test]
    fn divine_veil_regens_the_party_when_someone_else_cures() {
        let paladin = actor(1);
        let healer = actor(2);
        let mut cure = skill(1);
        cure.id = 27346;
        let out = run_hook(
            &root(),
            &call(
                "onHealed",
                "divine_veil",
                &paladin,
                &healer,
                false,
                cure,
                Some(hit(200.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert_eq!(
            out.owner.party_status,
            vec![HookPartyStatus {
                owner: 1,
                range: 8.0,
                status_id: 223264,
                tier: 0,
                magnitude: 85.0,
                duration: 30,
            }]
        );
        // Curing yourself doesn't count, nor does another spell.
        let own = run_hook(
            &root(),
            &call(
                "onHealed",
                "divine_veil",
                &paladin,
                &paladin,
                false,
                cure,
                Some(hit(200.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert!(own.owner.party_status.is_empty());
        let other = run_hook(
            &root(),
            &call(
                "onHealed",
                "divine_veil",
                &paladin,
                &healer,
                false,
                skill(1),
                Some(hit(200.0)),
            ),
        )
        .unwrap()
        .unwrap();
        assert!(other.owner.party_status.is_empty());
    }

    fn combo_start(potency: f64) -> ComboSkill {
        ComboSkill {
            base_potency: potency,
            cast_time_ms: 5000.0,
            recast_time_ms: 10000.0,
            aoe_type: 1.0,
            status_chance: 1.0,
            status_duration: 20.0,
            num_hits: 1.0,
            enmity_modifier: 1.0,
            ..Default::default()
        }
    }

    #[test]
    fn on_combo_reads_back_what_the_script_changed() {
        let c = owner();
        let thundara =
            run_command_skill_hook(&root(), "thundara", "onCombo", &c, combo_start(100.0))
                .unwrap()
                .unwrap();
        assert_eq!(thundara.base_potency, 150.0);
        assert_eq!(thundara.recast_time_ms, 5000.0);
        assert_eq!(thundara.status_chance, 0.0);
        let fira = run_command_skill_hook(&root(), "fira", "onCombo", &c, combo_start(100.0))
            .unwrap()
            .unwrap();
        assert_eq!(fira.cast_time_ms, 2500.0);
        let stonera = run_command_skill_hook(&root(), "stonera", "onCombo", &c, combo_start(100.0))
            .unwrap()
            .unwrap();
        assert_eq!(
            stonera.aoe_type, 0.0,
            "the combo makes Stonera single-target"
        );
        let godsbane =
            run_command_skill_hook(&root(), "godsbane", "onCombo", &c, combo_start(100.0))
                .unwrap()
                .unwrap();
        assert_eq!(godsbane.bonus_crit_rate, 200.0);
        let bloodletter =
            run_command_skill_hook(&root(), "bloodletter", "onCombo", &c, combo_start(100.0))
                .unwrap()
                .unwrap();
        assert_eq!(bloodletter.status_id, 223127.0);
        // Whirlwind's bonus needs a Berserk the caster doesn't have.
        let whirlwind =
            run_command_skill_hook(&root(), "whirlwind", "onCombo", &c, combo_start(100.0))
                .unwrap()
                .unwrap();
        assert_eq!(whirlwind.base_potency, 100.0);
        assert!(
            run_command_skill_hook(&root(), "fast_blade", "onCombo", &c, combo_start(100.0))
                .unwrap()
                .is_none(),
            "no onCombo"
        );
    }
}
