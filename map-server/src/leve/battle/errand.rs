// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! The Horn and Hand's faction leves (`classType` 4, ids 1201-1214): no
//! enemies to defeat. Players run errands for the merchants instead:
//!
//! * **Crates** (objectives 12003 in the field, 12004 in town): crates sit
//!   at marked spots around the camp; opening each one (talking to it)
//!   counts it. The leve sheet's first count is the number to find.
//! * **Follow** (12005): the leve's beast (`mob1`) walks from spot to spot
//!   while a player keeps within [`FOLLOW_NEAR`] yalms, and waits for them
//!   otherwise. Coming closer than [`FOLLOW_SEEN`] yalms gives you away and
//!   the leve fails. Where the beast's walk ends it vanishes, leaving a
//!   crate to open.
//! * **Go** (12013): reach the marked spot before the time runs out.
//!
//! No 1.0 source describes how these played beyond walkthroughs (the
//! "Search for crates", "Follow without being seen" and "Arrive in time"
//! objectives), so the spots come from the zone's own monster and NPC
//! positions, and the crate is the guildleve treasure chest
//! (`GuildleveBonusTreasureBox`, the model the dungeon chests use).

use super::*;
use crate::runtime::dungeon_chest::{CHEST_CLASS_ID, CHEST_PROPERTY_FLAGS};

/// Search for crates in the field / in town.
const OBJECTIVE_CRATES_FIELD: u32 = 12003;
const OBJECTIVE_CRATES_TOWN: u32 = 12004;
/// Follow a beast without being seen.
const OBJECTIVE_FOLLOW: u32 = 12005;
/// Arrive at a place in time.
const OBJECTIVE_GO: u32 = 12013;

/// Most crates one leve asks for.
const MAX_CRATES: i8 = 12;
/// Crates stand at least this far apart, and from the camp.
const CRATE_GAP: f32 = 8.0;
/// ... and within this of the camp.
const CRATE_RANGE: f32 = 150.0;
/// The crate's name over its head.
const CRATE_NAME: &str = "Crate";
/// Spots on a followed beast's walk, after its first.
const FOLLOW_LEGS: usize = 4;
/// One leg of the walk is this long.
const LEG_MIN: f32 = 15.0;
const LEG_MAX: f32 = 100.0;
/// The beast walks on while a player is this close...
pub(super) const FOLLOW_NEAR: f32 = 30.0;
/// ...and spots anyone closer than this.
pub(super) const FOLLOW_SEEN: f32 = 4.0;
/// The followed beast's health (it is on no one's side and shouldn't fall).
const GUIDE_HP: u32 = 30_000;
/// A Go leve's spot is about this far from the camp...
const GO_DISTANCE: f32 = 150.0;
/// ...and reached within this.
const ARRIVE: f32 = 6.0;
/// The beast reached its spot.
const AT_SPOT: f32 = 1.5;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrandKind {
    Crates,
    Follow,
    Go,
}

/// What kind of errand leve `gd` is, or `None` for any other leve.
pub fn errand_kind(gd: &GuildleveGamedata) -> Option<ErrandKind> {
    if gd.class_type != 4 {
        return None;
    }
    match gd.objective {
        OBJECTIVE_CRATES_FIELD | OBJECTIVE_CRATES_TOWN => Some(ErrandKind::Crates),
        OBJECTIVE_FOLLOW => Some(ErrandKind::Follow),
        OBJECTIVE_GO => Some(ErrandKind::Go),
        _ => None,
    }
}

/// The errand can run: a Follow leve needs its beast to have a monster
/// class.
pub(super) fn supported(gd: &GuildleveGamedata) -> bool {
    match errand_kind(gd) {
        Some(ErrandKind::Follow) => gd.mobs[0] != 0 && !gd.mob_missing[0],
        Some(_) => true,
        None => false,
    }
}

/// The tracker's counts: the crates to find, or one for a Follow or Go.
pub(super) fn aim(gd: &GuildleveGamedata, kind: ErrandKind) -> [i8; 4] {
    match kind {
        ErrandKind::Crates => [gd.aim_num[0].clamp(1, MAX_CRATES), 0, 0, 0],
        _ => [1, 0, 0, 0],
    }
}

/// A running errand.
#[derive(Debug, Clone)]
pub(super) struct ErrandRun {
    pub kind: ErrandKind,
    /// Crates still to open.
    pub crates: Vec<u32>,
    /// A followed beast's walk, and the spot it is heading for.
    pub route: Vec<(f32, f32, f32)>,
    pub leg: usize,
    pub guide: Option<u32>,
}

fn flat(a: (f32, f32, f32), b: (f32, f32, f32)) -> f32 {
    ((a.0 - b.0).powi(2) + (a.2 - b.2).powi(2)).sqrt()
}

/// `n` spots among `candidates` nearest `camp`, at least [`CRATE_GAP`]
/// from the camp and from each other, within [`CRATE_RANGE`].
pub(super) fn crate_spots(
    candidates: &[(f32, f32, f32)],
    camp: (f32, f32, f32),
    n: usize,
) -> Vec<(f32, f32, f32)> {
    let mut sorted: Vec<(f32, f32, f32)> = candidates
        .iter()
        .copied()
        .filter(|&p| (CRATE_GAP..=CRATE_RANGE).contains(&flat(p, camp)))
        .collect();
    sorted.sort_by(|a, b| flat(*a, camp).total_cmp(&flat(*b, camp)));
    let mut out: Vec<(f32, f32, f32)> = Vec::new();
    for p in sorted {
        if out.len() == n {
            break;
        }
        if out.iter().all(|&q| flat(p, q) >= CRATE_GAP) {
            out.push(p);
        }
    }
    out
}

/// A followed beast's walk: from the point nearest the camp (but
/// [`MIN_CAMP_DISTANCE`] away), [`FOLLOW_LEGS`] legs from point to point,
/// each [`LEG_MIN`]..[`LEG_MAX`] long and leading away from the camp.
pub(super) fn follow_route(
    points: &[(f32, f32, f32)],
    camp: (f32, f32, f32),
) -> Vec<(f32, f32, f32)> {
    let Some(first) = points
        .iter()
        .copied()
        .filter(|&p| flat(p, camp) >= MIN_CAMP_DISTANCE)
        .min_by(|a, b| flat(*a, camp).total_cmp(&flat(*b, camp)))
    else {
        return Vec::new();
    };
    let mut route = vec![first];
    for _ in 0..FOLLOW_LEGS {
        let here = *route.last().unwrap();
        let next = points
            .iter()
            .copied()
            .filter(|&p| {
                (LEG_MIN..=LEG_MAX).contains(&flat(p, here))
                    && flat(p, camp) > flat(here, camp)
                    && route.iter().all(|&q| flat(p, q) >= LEG_MIN)
            })
            .min_by(|a, b| flat(*a, here).total_cmp(&flat(*b, here)));
        match next {
            Some(p) => route.push(p),
            None => break,
        }
    }
    route
}

/// A Go leve's spot: the monster point whose distance from the camp is
/// nearest [`GO_DISTANCE`].
pub(super) fn go_spot(
    points: &[(f32, f32, f32)],
    camp: (f32, f32, f32),
) -> Option<(f32, f32, f32)> {
    points
        .iter()
        .copied()
        .filter(|&p| flat(p, camp) >= MIN_CAMP_DISTANCE)
        .min_by(|a, b| {
            (flat(*a, camp) - GO_DISTANCE)
                .abs()
                .total_cmp(&(flat(*b, camp) - GO_DISTANCE).abs())
        })
}

/// Put the errand in place before the tracker goes out: the crates, the
/// beast to follow, or the spot to reach (each sets the marker). `false`
/// when the zone has no place for it.
#[allow(clippy::too_many_arguments)]
pub(super) async fn setup(
    leve: &mut Leve,
    gd: &GuildleveGamedata,
    kind: ErrandKind,
    points: &[(f32, f32, f32)],
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    lua: Option<&Arc<LuaEngine>>,
) -> bool {
    let camp = leve.camp;
    let mut run = ErrandRun {
        kind,
        crates: Vec::new(),
        route: Vec::new(),
        leg: 0,
        guide: None,
    };
    match kind {
        ErrandKind::Crates => {
            // monster points in the field; in town, beside the townsfolk
            let mut candidates = points.to_vec();
            if gd.objective == OBJECTIVE_CRATES_TOWN || candidates.is_empty() {
                let npcs = db.npc_spawn_points(leve.zone_id).await.unwrap_or_default();
                candidates.extend(npcs.into_iter().map(|(x, y, z)| (x + 1.5, y, z)));
            }
            let spots = crate_spots(&candidates, camp, leve.aim[0] as usize);
            if spots.is_empty() {
                return false;
            }
            // as many as there are places for
            leve.aim[0] = leve.aim[0].min(spots.len() as i8);
            for &p in &spots {
                if let Some(id) = spawn_crate(leve.zone_id, p, registry, world, db).await {
                    run.crates.push(id);
                    leve.spawned.insert(id, None);
                }
            }
            if run.crates.is_empty() {
                return false;
            }
            leve.marker = spots[0];
        }
        ErrandKind::Follow => {
            run.route = follow_route(points, camp);
            if run.route.len() < 2 {
                return false;
            }
            let Some(class_id) = db.monster_class_for_name(gd.mobs[0]).await.ok().flatten() else {
                return false;
            };
            let Some(id) = spawn_one(
                leve,
                class_id,
                Some(run.route[0]),
                Some(GUIDE_HP),
                registry,
                world,
                db,
                lua,
            )
            .await
            else {
                return false;
            };
            leve.spawned.insert(id, None);
            run.guide = Some(id);
            leve.marker = run.route[0];
        }
        ErrandKind::Go => {
            let Some(p) = go_spot(points, camp) else {
                return false;
            };
            leve.marker = p;
        }
    }
    leve.errand = Some(run);
    true
}

/// A crate (the guildleve chest) at `p`, talkable.
async fn spawn_crate(
    zone_id: u32,
    p: (f32, f32, f32),
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
) -> Option<u32> {
    let mut class = db.load_actor_class(CHEST_CLASS_ID).await.ok().flatten()?;
    class.property_flags = CHEST_PROPERTY_FLAGS;
    let number = crate::processor::gm_spawn::next_number();
    let actor_id = (4u32 << 28) | (zone_id << 19) | (number & 0x7FFFF);
    let (x, y, z) = p;
    let mut npc = crate::npc::npc::Npc::new(
        number,
        &class,
        format!("leve_crate_{number}"),
        zone_id,
        x,
        y,
        z,
        0.0,
        0,
        0,
        Some(CRATE_NAME.to_string()),
    );
    if let Ok(Some(app)) = db.load_npc_appearance(CHEST_CLASS_ID).await {
        let (model_id, slots) = app.pack();
        npc.character.chara.model_id = model_id;
        npc.character.chara.appearance_ids = slots;
    }
    npc.generate_actor_name(number & 0x7FFFF);
    let zone_arc = world.zone(zone_id).await?;
    {
        let mut zone = zone_arc.write().await;
        let mut ob = crate::zone::outbox::AreaOutbox::new();
        let pos = common::Vector3::new(x, y, z);
        zone.core.add_actor(
            crate::zone::area::StoredActor {
                actor_id,
                kind: crate::zone::area::ActorKind::Npc,
                position: pos,
                grid: (0, 0),
                is_alive: true,
            },
            &mut ob,
        );
        zone.core.update_actor_position(actor_id, pos, &mut ob);
    }
    registry
        .insert(crate::runtime::actor_registry::ActorHandle::new(
            actor_id,
            crate::runtime::actor_registry::ActorKindTag::Npc,
            zone_id,
            0,
            npc.character.clone(),
        ))
        .await;
    Some(actor_id)
}

/// `actor_id` is a crate of `player_id`'s running leve.
pub fn is_crate(player_id: u32, actor_id: u32) -> bool {
    with_active(|a| {
        a.iter().any(|l| {
            matches!(l.phase, Phase::Running { .. })
                && l.has(player_id)
                && l.errand
                    .as_ref()
                    .is_some_and(|e| e.crates.contains(&actor_id))
        })
    })
}

/// A player opened crate `actor_id`: it goes, and counts.
pub async fn on_crate(
    player_id: u32,
    actor_id: u32,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    now_ms: u64,
) {
    let found = with_active(|a| {
        let l = a.iter_mut().find(|l| {
            matches!(l.phase, Phase::Running { .. })
                && l.has(player_id)
                && l.errand
                    .as_ref()
                    .is_some_and(|e| e.crates.contains(&actor_id))
        })?;
        let e = l.errand.as_mut()?;
        e.crates.retain(|&c| c != actor_id);
        l.spawned.remove(&actor_id);
        if l.now[0] < l.aim[0] {
            l.now[0] += 1;
        }
        let done = l.now[0] >= l.aim[0];
        Some((l.clone(), done))
    });
    let Some((leve, done)) = found else {
        return;
    };
    crate::runtime::quest_apply::apply_despawn_actor(leve.zone_id, actor_id, registry, world).await;
    tracing::info!(
        player = player_id,
        gl_id = leve.guildleve_id,
        crate_actor = format!("0x{actor_id:08X}"),
        now = ?leve.now,
        aim = ?leve.aim,
        "errand leve crate opened"
    );
    if done {
        complete(leve.owner, registry, world, db, now_ms).await;
        return;
    }
    // the marker moves to the nearest crate left
    let next = {
        let e = leve.errand.as_ref();
        let mut best: Option<(f32, (f32, f32, f32))> = None;
        for &c in e.map(|e| e.crates.as_slice()).unwrap_or_default() {
            if let Some(p) = position(registry, c).await {
                let d = flat(p, leve.marker);
                if best.is_none_or(|(bd, _)| d < bd) {
                    best = Some((d, p));
                }
            }
        }
        best.map(|(_, p)| p)
    };
    let leve = match next {
        Some(p) => with_active(|a| {
            a.iter_mut()
                .find(|l| l.director_id == leve.director_id)
                .map(|l| {
                    l.marker = p;
                    l.clone()
                })
        })
        .unwrap_or(leve),
        None => leve,
    };
    send_all(registry, world, &leve.participants(), tracker_state(&leve)).await;
}

/// Once a second while the leve runs: the followed beast walks on (or
/// spots someone), and a Go leve checks for arrival.
#[allow(clippy::too_many_arguments)]
pub(super) async fn tick(
    leve: &Leve,
    here: &[u32],
    now_ms: u64,
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
) {
    let Some(e) = leve.errand.as_ref() else {
        return;
    };
    let mut nearest = f32::MAX;
    let anchor = match (e.kind, e.guide) {
        (ErrandKind::Follow, Some(g)) => position(registry, g).await,
        (ErrandKind::Go, _) => Some(leve.marker),
        _ => None,
    };
    let Some(anchor) = anchor else {
        return;
    };
    for &p in here {
        if let Some(pos) = position(registry, p).await {
            nearest = nearest.min(flat(pos, anchor));
        }
    }
    match e.kind {
        ErrandKind::Go => {
            if nearest <= ARRIVE {
                let done = with_active(|a| {
                    a.iter_mut()
                        .find(|l| l.director_id == leve.director_id)
                        .map(|l| l.now[0] = l.aim[0])
                        .is_some()
                });
                if done {
                    tracing::info!(gl_id = leve.guildleve_id, "errand leve spot reached");
                    complete(leve.owner, registry, world, db, now_ms).await;
                }
            }
        }
        ErrandKind::Follow => {
            let Some(guide) = e.guide else {
                return;
            };
            if nearest < FOLLOW_SEEN {
                if let Some(ended) = finish(leve.owner, now_ms) {
                    wrap_up(&ended, registry, world, db).await;
                    for &p in here {
                        say(
                            registry,
                            world,
                            p,
                            "You have been spotted. The levequest has failed.",
                        )
                        .await;
                    }
                    tracing::info!(gl_id = leve.guildleve_id, "battle leve failed: spotted");
                }
                return;
            }
            let target = e.route[e.leg];
            if flat(anchor, target) > AT_SPOT {
                // on its way: keep it walking (a fight or an arrival
                // clears its goal)
                set_goal(registry, guide, target).await;
                return;
            }
            if e.leg + 1 < e.route.len() {
                if nearest <= FOLLOW_NEAR {
                    let next = e.route[e.leg + 1];
                    let leve = with_active(|a| {
                        a.iter_mut()
                            .find(|l| l.director_id == leve.director_id)
                            .and_then(|l| {
                                let e = l.errand.as_mut()?;
                                e.leg += 1;
                                l.marker = next;
                                Some(l.clone())
                            })
                    });
                    set_goal(registry, guide, next).await;
                    if let Some(leve) = leve {
                        send_all(registry, world, &leve.participants(), tracker_state(&leve)).await;
                    }
                }
                return;
            }
            // the walk's end: the beast vanishes, leaving a crate
            crate::runtime::quest_apply::apply_despawn_actor(leve.zone_id, guide, registry, world)
                .await;
            let found = spawn_crate(leve.zone_id, target, registry, world, db).await;
            let leve = with_active(|a| {
                a.iter_mut()
                    .find(|l| l.director_id == leve.director_id)
                    .and_then(|l| {
                        l.spawned.remove(&guide);
                        let e = l.errand.as_mut()?;
                        e.guide = None;
                        if let Some(c) = found {
                            e.crates.push(c);
                            l.spawned.insert(c, None);
                        }
                        l.marker = target;
                        Some(l.clone())
                    })
            });
            if let Some(leve) = leve {
                for &p in here {
                    say(
                        registry,
                        world,
                        p,
                        "Your quarry has vanished. Search where it was last seen.",
                    )
                    .await;
                }
                tracing::info!(gl_id = leve.guildleve_id, "errand leve quarry vanished");
                send_all(registry, world, &leve.participants(), tracker_state(&leve)).await;
            }
        }
        ErrandKind::Crates => {}
    }
}

/// Walk `actor_id` toward `p` (its AI's walk-home step).
async fn set_goal(registry: &ActorRegistry, actor_id: u32, p: (f32, f32, f32)) {
    if let Some(h) = registry.get(actor_id).await {
        let mut c = h.character.write().await;
        c.ai_container.home = Some(common::Vector3::new(p.0, p.1, p.2));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn gd(objective: u32, aim: [i8; 4]) -> GuildleveGamedata {
        GuildleveGamedata {
            id: 1201,
            class_type: 4,
            objective,
            aim_num: aim,
            ..Default::default()
        }
    }

    #[test]
    fn horn_and_hand_objectives_pick_the_errand() {
        assert_eq!(
            errand_kind(&gd(12003, [18, 7, 5, 6])),
            Some(ErrandKind::Crates)
        );
        assert_eq!(
            errand_kind(&gd(12004, [2, 2, 2, 9])),
            Some(ErrandKind::Crates)
        );
        assert_eq!(
            errand_kind(&gd(12005, [1, 0, 0, 0])),
            Some(ErrandKind::Follow)
        );
        assert_eq!(errand_kind(&gd(12013, [0; 4])), Some(ErrandKind::Go));
        let mut battle = gd(12004, [2, 0, 0, 0]);
        battle.class_type = 1;
        assert_eq!(errand_kind(&battle), None);
        assert_eq!(
            aim(&gd(12003, [18, 7, 5, 6]), ErrandKind::Crates),
            [12, 0, 0, 0]
        );
        assert_eq!(
            aim(&gd(12004, [2, 2, 2, 9]), ErrandKind::Crates),
            [2, 0, 0, 0]
        );
        assert_eq!(aim(&gd(12013, [0; 4]), ErrandKind::Go), [1, 0, 0, 0]);
    }

    #[test]
    fn a_follow_leve_needs_its_beast() {
        let mut g = gd(12005, [1, 0, 0, 0]);
        assert!(!supported(&g));
        g.mobs[0] = 3_200_707;
        assert!(supported(&g));
        g.mob_missing[0] = true;
        assert!(!supported(&g));
    }

    #[test]
    fn crates_stand_apart_and_near_the_camp() {
        let camp = (0.0, 0.0, 0.0);
        let cands = [
            (2.0, 0.0, 0.0),   // on the camp
            (10.0, 0.0, 0.0),  // ok
            (12.0, 0.0, 0.0),  // too close to the one before
            (20.0, 0.0, 0.0),  // ok
            (0.0, 0.0, 30.0),  // ok
            (400.0, 0.0, 0.0), // too far
        ];
        assert_eq!(
            crate_spots(&cands, camp, 5),
            vec![(10.0, 0.0, 0.0), (20.0, 0.0, 0.0), (0.0, 0.0, 30.0)]
        );
        assert_eq!(crate_spots(&cands, camp, 1), vec![(10.0, 0.0, 0.0)]);
    }

    #[test]
    fn a_followed_beast_walks_away_from_the_camp() {
        let camp = (0.0, 0.0, 0.0);
        let points: Vec<(f32, f32, f32)> = (1..12).map(|k| (k as f32 * 25.0, 0.0, 0.0)).collect();
        let route = follow_route(&points, camp);
        assert_eq!(route[0], (50.0, 0.0, 0.0));
        assert_eq!(route.len(), FOLLOW_LEGS + 1);
        assert!(route.windows(2).all(|w| w[1].0 > w[0].0));
        assert_eq!(go_spot(&points, camp), Some((150.0, 0.0, 0.0)));
        assert!(follow_route(&[], camp).is_empty());
    }
}
