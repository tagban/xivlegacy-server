// garlemald-server — Rust port of a FINAL FANTASY XIV v1.23b server emulator (lobby/world/map)
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

//! Tests for `scripts/lua/synthesis.lua`, the synthesis rules
//! `CraftCommand.lua` runs: bars stay in the widget's range, durability 0
//! fails, 100% progress finishes, and the rough odds hold (an on-level
//! Standard-only synthesis usually succeeds; a recipe far above the
//! crafter's level usually fails).

use std::path::PathBuf;

use mlua::Lua;

fn synthesis_lua() -> Lua {
    let lua = Lua::new();
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../scripts/lua/synthesis.lua");
    let src = std::fs::read_to_string(&path).expect("read synthesis.lua");
    lua.load(&src)
        .set_name("synthesis.lua")
        .exec()
        .expect("load synthesis.lua");
    // Deterministic rng: a small LCG so test runs are repeatable.
    lua.load(
        r"
        function makeRng(seed)
            local state = seed
            return function(lo, hi)
                state = (state * 1103515245 + 12345) % 2147483648
                return lo + (state % (hi - lo + 1))
            end
        end
        ",
    )
    .exec()
    .unwrap();
    lua
}

/// Run `n` syntheses of a `level` recipe by a `class_level` crafter using one
/// action throughout; returns (successes, total steps).
fn run(lua: &Lua, level: u8, class_level: u8, action: &str, n: u32) -> (u32, u32) {
    lua.load(format!(
        r"
        local ok, steps = 0, 0
        local rng = makeRng(7)
        for i = 1, {n} do
            local s = Synthesis.new({{level = {level}, facility = 0}}, {class_level}, rng, false)
            while not s.finished and not s.failed do
                local r = s:step({action})
                assert(s.progress >= 0 and s.progress <= 100, 'progress out of range')
                assert(s.durability >= 0 and s.durability <= s.maxDurability, 'durability out of range')
                assert(s.quality >= 0 and s.quality <= 1000, 'quality out of range')
                assert(r.durability >= 0, 'durability loss is negative')
            end
            assert(s.finished ~= s.failed, 'ended neither finished nor failed')
            if s.failed then assert(s.durability == 0) else assert(s.progress == 100) end
            if s.finished then ok = ok + 1 end
            steps = steps + s.steps
        end
        return ok, steps
        "
    ))
    .eval::<(u32, u32)>()
    .unwrap()
}

#[test]
fn on_level_standard_synthesis_usually_succeeds() {
    let lua = synthesis_lua();
    let (ok, steps) = run(&lua, 10, 10, "SYNTH_ACTION_STANDARD", 500);
    assert!(ok > 430, "on-level Standard succeeded {ok}/500");
    let avg = steps as f64 / 500.0;
    assert!((5.0..=10.0).contains(&avg), "average steps {avg}");
}

#[test]
fn recipe_far_above_level_usually_fails() {
    let lua = synthesis_lua();
    let (ok, _) = run(&lua, 10, 1, "SYNTH_ACTION_STANDARD", 300);
    assert!(ok < 30, "level 10 recipe at level 1 succeeded {ok}/300");
}

#[test]
fn rapid_takes_fewer_steps_than_standard() {
    let lua = synthesis_lua();
    let (_, standard) = run(&lua, 5, 5, "SYNTH_ACTION_STANDARD", 300);
    let (_, rapid) = run(&lua, 5, 5, "SYNTH_ACTION_RAPID", 300);
    assert!(
        rapid < standard,
        "rapid {rapid} steps vs standard {standard}"
    );
}

#[test]
fn waits_cost_more_durability_in_a_row_and_never_progress() {
    let lua = synthesis_lua();
    let (first, second, progress): (i32, i32, i32) = lua
        .load(
            r"
            local s = Synthesis.new({level = 1}, 1, makeRng(1), false)
            local a = s:step(SYNTH_ACTION_WAIT)
            local b = s:step(SYNTH_ACTION_WAIT)
            return a.durability, b.durability, s.progress
            ",
        )
        .eval()
        .unwrap();
    assert_eq!((first, second, progress), (1, 2, 0));
}

#[test]
fn quality_drives_hq_chance_result_quality_and_exp_bonus() {
    let lua = synthesis_lua();
    let (hq0, hq, q_low, exp_fail, exp_ok, bonus): (i32, i32, i32, i32, i32, i32) = lua
        .load(
            r"
            local s = Synthesis.new({level = 10}, 10, makeRng(3), false)
            local hq0 = s:hqChance()
            local qLow = s:rollQuality()
            s.quality = 600
            local fail = s:experience(false)
            local ok, bonus = s:experience(true)
            return hq0, s:hqChance(), qLow, fail, ok, bonus
            ",
        )
        .eval()
        .unwrap();
    assert_eq!(hq0, 0);
    assert_eq!(hq, 50);
    assert_eq!(q_low, 1, "no quality means a normal item");
    assert_eq!(exp_ok, 150 + 30 * 10);
    assert_eq!(exp_fail, exp_ok / 4);
    assert_eq!(bonus, 50);
}

#[test]
fn time_up_and_double_down_failure() {
    let lua = synthesis_lua();
    let (loss, progress, failed): (i32, i32, bool) = lua
        .load(
            r"
            local s = Synthesis.new({level = 1}, 1, makeRng(5), false)
            local r = s:timeUp()
            -- Force a Double Down failure: rng always rolls 100.
            s.rng = function(lo, hi) return hi end
            s.progress = 100; s.finished = true
            s:doubleDown()
            return r.durability, r.progress, s.failed and not s.finished
            ",
        )
        .eval()
        .unwrap();
    assert_eq!(loss, 15, "time up costs 14% of 105 durability, rounded up");
    assert_eq!(progress, 0);
    assert!(failed);
}
