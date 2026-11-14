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

//! Bulk check of every recipe in `common/sql/data/gamedata_recipes.sql`:
//!
//!   * the result item, every material and every crystal exist in `gamedata_items`;
//!   * the result quantity is at least 1 and fits one stack of the result item;
//!   * crystals are shards, crystals or clusters (1000003-1000020), each with a
//!     quantity, and there is at least one, except on kind `CC` rows: 1063 of
//!     those take no crystal (an item plus a dye, or the Pavis / Decoy / Rations
//!     assemblies), which passes with a note;
//!   * the craft class (29-36) and recipe level (1-50) are set;
//!   * the resolver finds the recipe from its materials in any slot order, with
//!     gaps, for its own class;
//!   * `synthesis.lua` can finish it: a crafter at the recipe's level using Standard
//!     reaches 100% within a few tries, and the result quality and EXP are sane.
//!
//! Set `RECIPE_CHECK_REPORT=/path/file.csv` to write the per-recipe list
//! (`id,craft,level,tier,result,status,reason`).

use std::collections::HashMap;
use std::path::PathBuf;

use mlua::Lua;

use super::recipe::{RECIPE_MATERIAL_SLOTS, Recipe};
use super::resolver::RecipeResolver;

const CRAFTS: [&str; 8] = [
    "Carpenter",
    "Blacksmith",
    "Armorer",
    "Goldsmith",
    "Leatherworker",
    "Weaver",
    "Alchemist",
    "Culinarian",
];

fn data_file(name: &str) -> String {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../common/sql/data")
        .join(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("read {}: {e}", path.display()))
}

/// The value tuples of a data file's INSERTs, as raw field strings (quotes removed).
fn rows(sql: &str) -> Vec<Vec<String>> {
    let mut out = Vec::new();
    for line in sql.lines() {
        let line = line.trim_end();
        if !line.starts_with('(') {
            continue;
        }
        let body = line
            .trim_end_matches(';')
            .trim_end_matches(',')
            .trim_start_matches('(')
            .trim_end_matches(')');
        let mut fields = Vec::new();
        let mut cur = String::new();
        let mut quoted = false;
        let mut chars = body.chars().peekable();
        while let Some(c) = chars.next() {
            match c {
                '\\' if quoted => {
                    if let Some(n) = chars.next() {
                        cur.push(n);
                    }
                }
                '\'' if quoted && chars.peek() == Some(&'\'') => {
                    chars.next();
                    cur.push('\'');
                }
                '\'' => quoted = !quoted,
                ',' if !quoted => {
                    fields.push(cur.trim().to_string());
                    cur.clear();
                }
                _ => cur.push(c),
            }
        }
        fields.push(cur.trim().to_string());
        out.push(fields);
    }
    out
}

struct Item {
    name: String,
    max_stack: u32,
    level: u32,
}

fn items() -> HashMap<u32, Item> {
    let mut out = HashMap::new();
    for f in rows(&data_file("gamedata_items.sql")) {
        let id: u32 = f[0].parse().unwrap();
        out.insert(
            id,
            Item {
                name: f[1].clone(),
                max_stack: f[5].parse().unwrap_or(1),
                level: f[20].parse().unwrap_or(1),
            },
        );
    }
    out
}

fn num(s: &str) -> u32 {
    s.parse().unwrap_or(0)
}

/// Recipes built the way `Database::load_recipes` builds them.
fn recipes(items: &HashMap<u32, Item>) -> Vec<(Recipe, String)> {
    rows(&data_file("gamedata_recipes.sql"))
        .into_iter()
        .map(|f| {
            let kind = f[6].clone();
            let job = f[3].chars().next().unwrap_or(' ');
            let mut mats = [0u32; RECIPE_MATERIAL_SLOTS];
            for (i, m) in mats.iter_mut().enumerate() {
                *m = num(&f[12 + i]);
            }
            let tier = num(&f[4]).min(255) as u8;
            let result = num(&f[1]);
            let item_level = items.get(&result).map_or(1, |i| i.level);
            let recipe = Recipe::new(
                num(&f[0]),
                result,
                num(&f[2]),
                mats,
                num(&f[7]),
                num(&f[8]),
                num(&f[9]),
                num(&f[10]),
                Recipe::job_code_to_class(job)
                    .map(|c| vec![c.to_string()])
                    .unwrap_or_default(),
                tier,
            )
            .with_craft_info(
                Recipe::job_code_to_class_id(job).unwrap_or(0),
                Recipe::level_from_tier(tier, item_level),
                num(&f[11]),
            );
            (recipe, kind)
        })
        .collect()
}

fn synthesis_lua() -> Lua {
    let lua = Lua::new();
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../scripts/lua/synthesis.lua");
    lua.load(std::fs::read_to_string(&path).expect("read synthesis.lua"))
        .set_name("synthesis.lua")
        .exec()
        .expect("load synthesis.lua");
    lua.load(
        r"
        function makeRng(seed)
            local state = seed
            return function(lo, hi)
                state = (state * 1103515245 + 12345) % 2147483648
                return lo + (state % (hi - lo + 1))
            end
        end
        -- Up to `tries` Standard-only syntheses by a crafter at the recipe's level.
        -- Returns an empty string when one finished cleanly, else why not.
        function checkRecipe(level, facility, seed, tries)
            local why = 'never finished in ' .. tries .. ' tries'
            for t = 1, tries do
                local s = Synthesis.new({level = level, facility = facility}, level, makeRng(seed + t), true)
                local steps = 0
                while not s.finished and not s.failed do
                    s:step(SYNTH_ACTION_STANDARD)
                    steps = steps + 1
                    if steps > 60 then return 'synthesis did not end in 60 steps' end
                end
                if s.finished then
                    if s.progress ~= 100 then return 'finished at ' .. s.progress .. '%' end
                    local q = s:rollQuality()
                    if q < 1 or q > 4 then return 'result quality ' .. q end
                    local exp = s:experience(true)
                    if exp <= 0 then return 'no EXP on success' end
                    return ''
                end
            end
            return why
        end
        ",
    )
    .exec()
    .unwrap();
    lua
}

/// Shuffle the filled slots and spread them out with gaps, as a player might place them.
fn scramble(mats: [u32; RECIPE_MATERIAL_SLOTS], seed: u32) -> [u32; RECIPE_MATERIAL_SLOTS] {
    let mut filled: Vec<u32> = mats.iter().copied().filter(|&m| m != 0).collect();
    filled.reverse();
    if !filled.is_empty() {
        let n = filled.len();
        filled.rotate_left(seed as usize % n);
    }
    let mut out = [0u32; RECIPE_MATERIAL_SLOTS];
    let gaps = RECIPE_MATERIAL_SLOTS - filled.len();
    let skip = if gaps > 0 {
        1 + seed as usize % gaps
    } else {
        0
    };
    for (i, m) in filled.into_iter().enumerate() {
        out[(i + skip) % RECIPE_MATERIAL_SLOTS] = m;
    }
    out
}

/// (failures, notes) for one recipe.
fn check(
    r: &Recipe,
    kind: &str,
    items: &HashMap<u32, Item>,
    resolver: &RecipeResolver,
    lua: &Lua,
) -> (Vec<String>, Vec<String>) {
    let mut why = Vec::new();
    let mut notes = Vec::new();
    let real = |id: u32| id != 0 && items.get(&id).is_some_and(|i| i.name != "[en]");
    match items.get(&r.result_item_id) {
        Some(item) if real(r.result_item_id) => {
            if r.result_quantity == 0 {
                why.push("result quantity 0".to_string());
            } else if r.result_quantity > item.max_stack.max(1) {
                why.push(format!(
                    "makes {} but {} stacks to {}",
                    r.result_quantity, item.name, item.max_stack
                ));
            }
        }
        _ => why.push(format!("result item {} missing", r.result_item_id)),
    }
    if r.materials.iter().all(|&m| m == 0) {
        why.push("no materials".to_string());
    }
    for &m in r.materials.iter().filter(|&&m| m != 0) {
        if !real(m) {
            why.push(format!("material {m} missing"));
        }
    }
    let crystals = [
        (r.crystal_id_1, r.crystal_quantity_1),
        (r.crystal_id_2, r.crystal_quantity_2),
    ];
    if crystals.iter().all(|&(id, _)| id == 0) {
        if kind == "CC" {
            notes.push("no crystal (dye or assembly)".to_string());
        } else {
            why.push("no crystal".to_string());
        }
    }
    for (id, qty) in crystals {
        if id == 0 {
            if qty != 0 {
                why.push(format!("crystal quantity {qty} with no crystal"));
            }
            continue;
        }
        if !(1_000_003..=1_000_020).contains(&id) || !real(id) {
            why.push(format!("crystal {id} is not a shard, crystal or cluster"));
        }
        if qty == 0 {
            why.push(format!("crystal {id} quantity 0"));
        }
    }
    if !(29..=36).contains(&r.class_id) {
        why.push("no craft class".to_string());
    }
    if !(1..=50).contains(&r.level) {
        why.push(format!("level {}", r.level));
    }
    for seed in [1, 4] {
        let placed = scramble(r.materials, r.id + seed);
        if !resolver
            .by_mats(placed)
            .iter()
            .any(|x| x.id == r.id && x.class_id == r.class_id)
        {
            why.push(format!("not found from materials placed as {placed:?}"));
            break;
        }
    }
    let f: mlua::Function = lua.globals().get("checkRecipe").unwrap();
    let res: String = f.call((r.level, r.facility, r.id, 10)).unwrap();
    if !res.is_empty() {
        why.push(format!("synthesis: {res}"));
    }
    (why, notes)
}

#[test]
fn every_recipe_resolves_and_can_be_synthesized() {
    let items = items();
    let all = recipes(&items);
    assert!(all.len() > 5000, "only {} recipes parsed", all.len());
    let resolver = RecipeResolver::from_recipes(all.iter().map(|(r, _)| r.clone()));
    assert_eq!(resolver.num_recipes(), all.len(), "duplicate recipe ids");
    let lua = synthesis_lua();

    let mut report = String::from("id,craft,level,tier,result,status,reason\n");
    let mut failed = Vec::new();
    for (r, kind) in &all {
        let (why, notes) = check(r, kind, &items, &resolver, &lua);
        let craft = r
            .class_id
            .checked_sub(29)
            .and_then(|i| CRAFTS.get(i as usize))
            .copied()
            .unwrap_or("?");
        let result = items
            .get(&r.result_item_id)
            .map_or("?".to_string(), |i| i.name.replace('"', "\"\""));
        report.push_str(&format!(
            "{},{},{},{},\"{}\",{},\"{}\"\n",
            r.id,
            craft,
            r.level,
            r.tier,
            result,
            if why.is_empty() { "pass" } else { "fail" },
            why.iter()
                .chain(&notes)
                .cloned()
                .collect::<Vec<_>>()
                .join("; ")
                .replace('"', "\"\"")
        ));
        if !why.is_empty() {
            failed.push(format!("{} {}: {}", r.id, result, why.join("; ")));
        }
    }
    if let Ok(path) = std::env::var("RECIPE_CHECK_REPORT") {
        std::fs::write(&path, &report).unwrap_or_else(|e| panic!("write {path}: {e}"));
    }
    assert!(
        failed.is_empty(),
        "{} of {} recipes fail:\n{}",
        failed.len(),
        all.len(),
        failed
            .iter()
            .take(40)
            .cloned()
            .collect::<Vec<_>>()
            .join("\n")
    );
}

#[test]
fn scramble_keeps_the_materials() {
    let mats = [5, 5, 7, 9, 0, 0, 0, 0];
    for seed in 0..6 {
        let mut a: Vec<u32> = scramble(mats, seed)
            .into_iter()
            .filter(|&m| m != 0)
            .collect();
        a.sort_unstable();
        assert_eq!(a, vec![5, 5, 7, 9]);
    }
}
