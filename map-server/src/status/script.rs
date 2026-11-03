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
}

/// The effect's own numbers, as the container holds them.
#[derive(Debug, Clone, Copy, Default)]
pub struct EffectView {
    pub magnitude: f64,
    pub tier: u8,
    pub extra: f64,
    pub duration: u32,
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

fn method<F>(lua: &Lua, t: &Table, name: &str, st: &Arc<Mutex<State>>, f: F) -> mlua::Result<()>
where
    F: Fn(&mut State, &[Option<f64>]) -> Value + Send + 'static,
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
    // Traits aren't tracked yet.
    method(lua, &t, "HasTrait", st, |_, _| Value::Boolean(false))?;
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
    Ok(lua)
}

fn build_effect(lua: &Lua, st: &Arc<Mutex<State>>) -> mlua::Result<Table> {
    let t = lua.create_table()?;
    method(lua, &t, "GetMagnitude", st, |s, _| {
        Value::Number(s.effect.magnitude)
    })?;
    method(lua, &t, "SetMagnitude", st, |s, n| {
        s.effect.magnitude = arg(n, 0);
        Value::Nil
    })?;
    method(lua, &t, "GetExtra", st, |s, _| {
        Value::Number(s.effect.extra)
    })?;
    method(lua, &t, "SetExtra", st, |s, n| {
        s.effect.extra = arg(n, 0);
        Value::Nil
    })?;
    method(lua, &t, "GetTier", st, |s, _| {
        Value::Integer(s.effect.tier as i64)
    })?;
    method(lua, &t, "SetTier", st, |s, n| {
        s.effect.tier = arg(n, 0) as u8;
        Value::Nil
    })?;
    method(lua, &t, "GetDuration", st, |s, _| {
        Value::Integer(s.effect.duration as i64)
    })?;
    method(lua, &t, "GetSource", st, |_, _| Value::Nil)?;
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
#[derive(Debug, Clone, Copy, Default, PartialEq)]
pub struct CommandStatus {
    pub status_id: u32,
    pub duration: u32,
    pub magnitude: f64,
    pub tier: u8,
    pub chance: f64,
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
    let Some(path) = ["ability", "magic", "weaponskill"]
        .iter()
        .map(|dir| {
            script_root
                .join("commands")
                .join(dir)
                .join(format!("{command_name}.lua"))
        })
        .find(|p| p.exists())
    else {
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
    }));
    let caster_t = build_owner(&lua, &st)?;
    let skill = lua.create_table()?;
    skill.set("statusId", start.status_id)?;
    skill.set("statusDuration", start.duration)?;
    skill.set("statusMagnitude", start.magnitude)?;
    skill.set("statusTier", start.tier)?;
    skill.set("statusChance", start.chance)?;
    let action = lua.create_table()?;
    action.set_metatable(Some(stub_meta(&lua)?))?;
    let container = lua.create_table()?;
    container.set_metatable(Some(stub_meta(&lua)?))?;

    let g = lua.globals();
    let mut failed = None;
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
    if let Some(e) = failed {
        tracing::debug!(command = command_name, error = %e, "command setup stopped early");
    }
    let num = |k: &str, d: f64| skill.get::<Option<f64>>(k).ok().flatten().unwrap_or(d);
    Ok(Some(CommandStatus {
        status_id: num("statusId", start.status_id as f64) as u32,
        duration: num("statusDuration", start.duration as f64) as u32,
        magnitude: num("statusMagnitude", start.magnitude),
        tier: num("statusTier", start.tier as f64) as u8,
        chance: num("statusChance", start.chance),
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
        }
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
}
