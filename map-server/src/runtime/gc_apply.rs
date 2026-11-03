// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Grand Company commands (`JoinGC`, `SetGCRank`, `AddSeals`,
//! `PromoteGC`). Shared by the packet processor's command drain and the
//! runtime drain NPC scripts go through (the company officers enlist and
//! promote from their own `onEventStarted`).

use crate::database::Database;
use crate::runtime::actor_registry::{ActorHandle, ActorRegistry};
use crate::world_manager::WorldManager;

/// Shared helper: emit the current `SetGrandCompanyPacket` for
/// a player whose CharaState has freshly updated GC fields. The
/// packet is self-only (the client uses it for its own menu /
/// nameplate rendering — other players see the GC via the
/// propertyFlags path). Assumes the caller already mutated
/// CharaState; just reads + emits.
pub async fn emit_grand_company_packet(handle: &ActorHandle, world: &WorldManager) {
    let (gc, l, g, u) = {
        let c = handle.character.read().await;
        (
            c.chara.gc_current,
            c.chara.gc_rank_limsa,
            c.chara.gc_rank_gridania,
            c.chara.gc_rank_uldah,
        )
    };
    if let Some(client) = world.client(handle.session_id).await {
        let mut pkt =
            crate::packets::send::player::build_set_grand_company(handle.actor_id, gc, l, g, u);
        pkt.set_target_id(handle.session_id);
        client.send_bytes(pkt.to_bytes()).await;
    }
}

pub async fn apply_join_gc(
    registry: &ActorRegistry,
    db: &Database,
    world: &WorldManager,
    player_id: u32,
    gc: u8,
) {
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    if !crate::actor::gc::is_valid_gc(gc) {
        tracing::debug!(player = player_id, gc, "JoinGC: invalid gc id");
        return;
    }
    // Flip CharaState and, if the per-GC rank is still the
    // "never-promoted" sentinel, leave it at `RANK_RECRUIT`
    // (127) — matches retail, which shows a newly-joined
    // character as Recruit until their first promotion.
    {
        let mut c = handle.character.write().await;
        c.chara.gc_current = gc;
        let rank_ref = match gc {
            crate::actor::gc::GC_MAELSTROM => &mut c.chara.gc_rank_limsa,
            crate::actor::gc::GC_TWIN_ADDER => &mut c.chara.gc_rank_gridania,
            crate::actor::gc::GC_IMMORTAL_FLAMES => &mut c.chara.gc_rank_uldah,
            _ => return,
        };
        if *rank_ref == 0 {
            *rank_ref = crate::actor::gc::RANK_RECRUIT;
        }
    }
    if let Err(e) = db.set_gc_current(player_id, gc).await {
        tracing::warn!(player = player_id, gc, err = %e, "JoinGC: DB set_gc_current failed");
    }
    // Persist the rank too — if we bumped it from 0 to 127 the
    // DB currently has 0; if it was already set we're writing
    // back the same value.
    let rank = {
        let c = handle.character.read().await;
        match gc {
            crate::actor::gc::GC_MAELSTROM => c.chara.gc_rank_limsa,
            crate::actor::gc::GC_TWIN_ADDER => c.chara.gc_rank_gridania,
            crate::actor::gc::GC_IMMORTAL_FLAMES => c.chara.gc_rank_uldah,
            _ => 0,
        }
    };
    if let Err(e) = db.set_gc_rank(player_id, gc, rank).await {
        tracing::warn!(player = player_id, gc, err = %e, "JoinGC: DB set_gc_rank failed");
    }
    emit_grand_company_packet(&handle, world).await;
    tracing::info!(player = player_id, gc, rank, "JoinGC applied");
}

pub async fn apply_set_gc_rank(
    registry: &ActorRegistry,
    db: &Database,
    world: &WorldManager,
    player_id: u32,
    gc: u8,
    rank: u8,
) {
    let Some(handle) = registry.get(player_id).await else {
        return;
    };
    if !crate::actor::gc::is_valid_gc(gc) {
        tracing::debug!(player = player_id, gc, "SetGCRank: invalid gc id");
        return;
    }
    {
        let mut c = handle.character.write().await;
        match gc {
            crate::actor::gc::GC_MAELSTROM => c.chara.gc_rank_limsa = rank,
            crate::actor::gc::GC_TWIN_ADDER => c.chara.gc_rank_gridania = rank,
            crate::actor::gc::GC_IMMORTAL_FLAMES => c.chara.gc_rank_uldah = rank,
            _ => return,
        }
    }
    if let Err(e) = db.set_gc_rank(player_id, gc, rank).await {
        tracing::warn!(player = player_id, gc, rank, err = %e, "SetGCRank: DB persist failed");
    }
    emit_grand_company_packet(&handle, world).await;
    tracing::info!(player = player_id, gc, rank, "SetGCRank applied");
}

pub async fn apply_add_seals(db: &Database, player_id: u32, gc: u8, amount: i32) {
    if !crate::actor::gc::is_valid_gc(gc) {
        tracing::debug!(player = player_id, gc, "AddSeals: invalid gc id");
        return;
    }
    match db.add_seals(player_id, gc, amount).await {
        Ok(total) => tracing::info!(
            player = player_id,
            gc,
            delta = amount,
            total,
            "AddSeals applied",
        ),
        Err(e) => tracing::warn!(
            player = player_id,
            gc,
            err = %e,
            "AddSeals: DB persist failed",
        ),
    }
}

/// `player:PromoteGC(gc)` — atomic seal-spend + rank-bump.
/// Mirrors the post-`eventDoRankUp` tail of Meteor's
/// `PopulaceCompanyOfficer.lua` flow. Refuses (logs at `info` and
/// returns without any DB write) when:
/// * `gc` isn't a valid GC id (1/2/3),
/// * the player isn't in the registry (offline / NPC),
/// * the player isn't enlisted in `gc` (`chara.gc_current != gc`),
/// * current rank has no `next_rank` (already at/past 1.23b cap of 31),
/// * seal balance is below `gc_promotion_cost(current)`.
///   On success: spends `cost` seals via `db.add_seals(-cost)`,
///   bumps the per-GC rank field on `CharaState` to `next_rank`,
///   persists the rank via `db.set_gc_rank`, and emits
///   `SetGrandCompanyPacket` so the client sees the new rank.
pub async fn apply_promote_gc(
    registry: &ActorRegistry,
    db: &Database,
    world: &WorldManager,
    player_id: u32,
    gc: u8,
) {
    if !crate::actor::gc::is_valid_gc(gc) {
        tracing::debug!(player = player_id, gc, "PromoteGC: invalid gc id");
        return;
    }
    let Some(handle) = registry.get(player_id).await else {
        tracing::debug!(player = player_id, "PromoteGC: player not in registry");
        return;
    };
    // Read current enrollment + rank + (for tier-shift gates) the
    // completed-quest set under a single read lock.
    let (enrolled_gc, current_rank, completed_quests) = {
        let c = handle.character.read().await;
        let rank = match gc {
            crate::actor::gc::GC_MAELSTROM => c.chara.gc_rank_limsa,
            crate::actor::gc::GC_TWIN_ADDER => c.chara.gc_rank_gridania,
            crate::actor::gc::GC_IMMORTAL_FLAMES => c.chara.gc_rank_uldah,
            _ => 0,
        };
        let completed: std::collections::HashSet<u32> = c.quest_journal.iter_completed().collect();
        (c.chara.gc_current, rank, completed)
    };
    if enrolled_gc != gc {
        tracing::info!(
            player = player_id,
            gc,
            enrolled = enrolled_gc,
            "PromoteGC refused: player not enlisted in target GC",
        );
        return;
    }
    let Some(next_rank) = crate::actor::gc::next_rank(current_rank) else {
        tracing::info!(
            player = player_id,
            gc,
            current_rank,
            "PromoteGC refused: already at or past STORY_RANK_CAP",
        );
        return;
    };
    // Tier-shift gate — Corporal → Sergeant Third Class (17 → 21)
    // and Chief Sergeant → Second Lieutenant (27 → 31) require
    // their respective per-GC story quest to be completed before
    // the dialog branch even offers the promotion. Refuse here
    // even if seal balance + cap checks would otherwise pass — the
    // script's `eventTalkQuestUncomplete()` dialog the comment
    // header at `PopulaceCompanyOfficer.lua:20` describes is the
    // client-visible counterpart.
    if let Some(gate_quest) = crate::actor::gc::tier_shift_quest(current_rank, gc)
        && !completed_quests.contains(&gate_quest)
    {
        tracing::info!(
            player = player_id,
            gc,
            current_rank,
            gate_quest,
            "PromoteGC refused: tier-shift story quest not completed",
        );
        return;
    }
    let cost = crate::actor::gc::gc_promotion_cost(current_rank);
    if cost <= 0 {
        tracing::info!(
            player = player_id,
            gc,
            current_rank,
            "PromoteGC refused: no promotion cost defined for current rank",
        );
        return;
    }
    let balance = match db.get_seals(player_id, gc).await {
        Ok(b) => b,
        Err(e) => {
            tracing::warn!(
                player = player_id,
                gc,
                err = %e,
                "PromoteGC: DB get_seals failed",
            );
            return;
        }
    };
    if balance < cost {
        tracing::info!(
            player = player_id,
            gc,
            current_rank,
            cost,
            balance,
            "PromoteGC refused: insufficient seal balance",
        );
        return;
    }
    // Spend seals first — `add_seals` clamps the post-deposit
    // total at 0 so even if we later fail to bump the rank the
    // player isn't double-charged on retry. The rank-bump path
    // sticks with our existing AddSeals semantics.
    if let Err(e) = db.add_seals(player_id, gc, -cost).await {
        tracing::warn!(
            player = player_id,
            gc,
            cost,
            err = %e,
            "PromoteGC: DB seal deduction failed",
        );
        return;
    }
    // Bump CharaState first so the SetGrandCompanyPacket emit
    // (which reads CharaState) reflects the new rank without
    // racing the DB write.
    {
        let mut c = handle.character.write().await;
        match gc {
            crate::actor::gc::GC_MAELSTROM => c.chara.gc_rank_limsa = next_rank,
            crate::actor::gc::GC_TWIN_ADDER => c.chara.gc_rank_gridania = next_rank,
            crate::actor::gc::GC_IMMORTAL_FLAMES => c.chara.gc_rank_uldah = next_rank,
            _ => {}
        }
    }
    if let Err(e) = db.set_gc_rank(player_id, gc, next_rank).await {
        tracing::warn!(
            player = player_id,
            gc,
            next_rank,
            err = %e,
            "PromoteGC: DB set_gc_rank failed (CharaState already updated; will reconcile on next login)",
        );
    }
    emit_grand_company_packet(&handle, world).await;
    // Rank-up animation broadcast — `eventDoRankUp` plays the
    // promotion fanfare on the promoting client itself, but
    // nearby players never hear / see it because `callClientFunction`
    // only targets the issuing player. Emit a server-side
    // `PlayAnimationOnActor` (0x00DA) carrying the canonical
    // teleport-fanfare animation id (`0x4000FFB`, used by
    // `TeleportCommand.lua` for the teleport-in flourish — the
    // closest documented "scene transition" effect we have, and a
    // plausible salute placeholder until a dedicated GC-salute id
    // is sourced) so neighbours witness the rank-up moment too.
    // Wraps both the self-send and the nearby-player fan-out
    // through the shared `broadcast_around_actor` helper, matching
    // the chocobo `SendMountAppearance` pattern at
    // `apply_send_mount_appearance:1719-1745`.
    const RANKUP_ANIMATION_ID: u32 = 0x0400_0FFB;
    let sub = crate::packets::send::actor::build_play_animation_on_actor(
        handle.actor_id,
        RANKUP_ANIMATION_ID,
    );
    // Raw subpacket bytes — the writer task owns BasePacket framing;
    // pre-framing double-wrapped AND hid the zero `target_id` from the
    // stamp helper, so the packet died at the world-server proxy.
    {
        let mut self_bytes = sub.to_bytes();
        // Self-emit so the promoting player sees the salute
        // regardless of how far from any neighbour they are.
        if let Some(client) = world.client(handle.session_id).await {
            common::subpacket::SubPacket::stamp_target_id_if_zero(
                &mut self_bytes,
                handle.session_id,
            );
            client.send_bytes(self_bytes).await;
        }
        if let Some(zone) = world.zone(handle.zone_id).await {
            let sent = crate::runtime::broadcast::broadcast_around_actor(
                world,
                registry,
                &zone,
                handle.actor_id,
                sub.to_bytes(),
            )
            .await;
            tracing::debug!(
                player = player_id,
                nearby = sent,
                "PromoteGC: rank-up animation broadcast fan-out",
            );
        }
    }
    tracing::info!(
        player = player_id,
        gc,
        current_rank,
        next_rank,
        cost,
        "PromoteGC applied",
    );
}
