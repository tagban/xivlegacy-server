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

//! Player parties, after Project Meteor's (`World Server/DataObjects/Group/
//! Party.cs`, `PartyManager.cs`, `WorldMaster.ProcessPartyInvite`). A player
//! outside a party is a party of one, which the zone-in bundle already
//! sends; this table holds the parties of two or more.
//!
//! The map server keeps them itself, as it does linkshells: with one map
//! server it reaches every member. Each member's client gets the party
//! list (the 10001 group) with themselves in the first row, so every
//! composition change re-sends it under a fresh group id
//! (`groups::party_group_index`) and deletes the one it replaces. The
//! leader reaches the client as `partyGroupWork._globalTemp.owner`.

use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

use common::luaparam::LuaParam;

use crate::database::Database;
use crate::linkshells::{
    Invite, delete_relation, name_of, next_relation_id, relation_work, send, send_relation, tell,
};
use crate::packets::send::groups as tx;
use crate::runtime::actor_registry::ActorRegistry;
use crate::world_manager::WorldManager;

/// The invite kind the client's confirm window shows (Meteor
/// `RelationGroupManager.CreatePartyRelationGroup`), and the group type
/// ConfirmGroupCommand hands back with the answer.
pub const INVITE_COMMAND_PARTY: u32 = 10001;
pub const MAX_MEMBERS: usize = 8;

#[derive(Debug, Clone, PartialEq)]
struct Party {
    leader: u32,
    /// Join order, the leader included.
    members: Vec<u32>,
}

#[derive(Default)]
struct Table {
    parties: HashMap<u32, Party>,
    /// Member actor id -> party key.
    of: HashMap<u32, u32>,
    next: u32,
    /// Pending offers, by invitee.
    invites: HashMap<u32, Invite>,
    /// The party group id each player's client last got, so the next one
    /// can replace it.
    sent: HashMap<u32, u64>,
    /// A player back to solo after a party: the id their party of one goes
    /// under instead of the login one, which their client has deleted and
    /// won't take back.
    solo: HashMap<u32, u64>,
    /// Players who dropped out of a party by logging out (or losing the
    /// connection): who was in it with them, the leader first, and when.
    away: HashMap<u32, Away>,
}

#[derive(Debug, Clone)]
struct Away {
    others: Vec<u32>,
    at_secs: u64,
}

/// A player who logs back in within this many seconds of dropping out of
/// a party is put back in it.
pub const REJOIN_WINDOW_SECS: u64 = 10 * 60;

fn table() -> std::sync::MutexGuard<'static, Table> {
    static TABLE: OnceLock<Mutex<Table>> = OnceLock::new();
    TABLE
        .get_or_init(Default::default)
        .lock()
        .unwrap_or_else(|e| e.into_inner())
}

/// Everyone in `actor`'s party, the leader first; just `actor` when solo.
pub fn members_of(actor: u32) -> Vec<u32> {
    let t = table();
    match t.of.get(&actor).and_then(|k| t.parties.get(k)) {
        Some(p) => {
            let mut v = vec![p.leader];
            v.extend(p.members.iter().copied().filter(|&m| m != p.leader));
            v
        }
        None => vec![actor],
    }
}

/// The other members of `actor`'s party.
pub fn others(actor: u32) -> Vec<u32> {
    members_of(actor)
        .into_iter()
        .filter(|&m| m != actor)
        .collect()
}

/// The rows after `actor`'s own in their party list: the party, then
/// any content allies (`Session::transient_party_members`).
pub fn roster(actor: u32, allies: &[u32]) -> Vec<u32> {
    let mut ids = others(actor);
    for &a in allies {
        if a != actor && !ids.contains(&a) {
            ids.push(a);
        }
    }
    ids
}

/// A solo player leads their own party of one, as in Meteor.
pub fn leader_of(actor: u32) -> u32 {
    members_of(actor)[0]
}

pub fn is_leader(actor: u32) -> bool {
    leader_of(actor) == actor
}

/// The `partyGroupWork._globalTemp.owner` value: the leader in the high
/// half, Meteor's marker in the low.
pub fn owner_work(leader: u32) -> u64 {
    crate::group::party::pack_owner(leader)
}

/// The group id for `actor`'s party of one, when it can't be the login
/// one (see `Table::solo`).
pub fn solo_group(actor: u32) -> Option<u64> {
    table().solo.get(&actor).copied()
}

/// Remember the party group id `actor`'s client was just sent.
pub fn note_sent(actor: u32, group_id: u64) {
    table().sent.insert(actor, group_id);
}

/// The client created the invitation group of a pending party offer
/// (`/_init`). False when `gid` isn't one.
pub async fn answer_relation_created(
    world: &WorldManager,
    actor_id: u32,
    session_id: u32,
    gid: u64,
) -> bool {
    let inv = table()
        .invites
        .values()
        .find(|i| i.relation == gid)
        .copied();
    let Some(inv) = inv else {
        return false;
    };
    send(
        world,
        session_id,
        vec![relation_work(actor_id, inv, INVITE_COMMAND_PARTY)],
    )
    .await;
    true
}

/// Is `group_id` the party list `actor`'s client holds?
pub fn is_party_group(actor: u32, group_id: u64) -> bool {
    table().sent.get(&actor) == Some(&group_id)
}

fn take_sent(actor: u32) -> Option<u64> {
    table().sent.remove(&actor)
}

/// Join `invitee` to `inviter`'s party, forming one if `inviter` is solo.
/// None when the party is full or `invitee` already has one.
/// Put `invitee` in `inviter`'s party, as accepting an invite does.
#[cfg(test)]
pub(crate) fn join_for_test(inviter: u32, invitee: u32) -> Option<Vec<u32>> {
    join(inviter, invitee)
}

fn join(inviter: u32, invitee: u32) -> Option<Vec<u32>> {
    let mut t = table();
    if t.of.contains_key(&invitee) {
        return None;
    }
    let key = match t.of.get(&inviter) {
        Some(&k) => k,
        None => {
            t.next = t.next.wrapping_add(1);
            let k = t.next;
            t.parties.insert(
                k,
                Party {
                    leader: inviter,
                    members: vec![inviter],
                },
            );
            t.of.insert(inviter, k);
            k
        }
    };
    let party = t.parties.get_mut(&key)?;
    if party.members.len() >= MAX_MEMBERS {
        return None;
    }
    party.members.push(invitee);
    let members = party.members.clone();
    t.of.insert(invitee, key);
    Some(members)
}

/// Take `actor` out of their party. Returns who was in it before. A party
/// left with one member dissolves; a leaderless one passes to the next
/// member in join order.
fn remove(actor: u32) -> Vec<u32> {
    let mut t = table();
    let Some(key) = t.of.remove(&actor) else {
        return Vec::new();
    };
    let Some(party) = t.parties.get_mut(&key) else {
        return Vec::new();
    };
    let before = party.members.clone();
    party.members.retain(|&m| m != actor);
    if party.leader == actor
        && let Some(&next) = party.members.first()
    {
        party.leader = next;
    }
    if party.members.len() <= 1 {
        let rest = party.members.clone();
        t.parties.remove(&key);
        for m in rest {
            t.of.remove(&m);
        }
    }
    before
}

fn dissolve(actor: u32) -> Vec<u32> {
    let mut t = table();
    let Some(key) = t.of.get(&actor).copied() else {
        return Vec::new();
    };
    let Some(party) = t.parties.remove(&key) else {
        return Vec::new();
    };
    for m in &party.members {
        t.of.remove(m);
    }
    party.members
}

fn set_leader(actor: u32, new_leader: u32) {
    let mut t = table();
    if let Some(key) = t.of.get(&actor).copied()
        && let Some(p) = t.parties.get_mut(&key)
    {
        p.leader = new_leader;
    }
}

/// A character name or, from the target menu, an actor id.
async fn resolve(db: &Database, registry: &ActorRegistry, target: &str) -> Option<u32> {
    let target = target.trim();
    if let Ok(id) = target.parse::<u32>() {
        return registry.get(id).await.map(|_| id);
    }
    db.character_id_by_name(target).await.ok().flatten()
}

/// Send `actor` their party list again (fresh group id, the leader, and
/// the old list deleted).
pub async fn refresh(registry: &ActorRegistry, world: &WorldManager, actor: u32) {
    let Some(h) = registry.get(actor).await else {
        return;
    };
    let Some(mut snap) = world.session(h.session_id).await else {
        return;
    };
    snap.party_group_ordinal = snap.party_group_ordinal.wrapping_add(1);
    let ordinal = snap.party_group_ordinal;
    world.upsert_session(snap).await;
    {
        let mut t = table();
        if t.of.contains_key(&actor) {
            t.solo.remove(&actor);
        } else {
            // the multi-member id scheme: fresh per composition
            t.solo
                .insert(actor, tx::party_group_index(actor, 2, ordinal));
        }
    }
    // The old list goes first: the client keeps one party, and deleting
    // a party group after the new one registered leaves it with none
    // (the party command greys out).
    if let Some(old) = take_sent(actor) {
        send(
            world,
            h.session_id,
            vec![tx::build_delete_group(actor, old)],
        )
        .await;
    }
    let Some((group_id, count)) =
        crate::runtime::quest_apply::emit_party_group_trio(actor, registry, world).await
    else {
        return;
    };
    note_sent(actor, group_id);
    if count > 1 {
        send(
            world,
            h.session_id,
            vec![owner_packet(actor, group_id, leader_of(actor))],
        )
        .await;
    }
}

/// `partyGroupWork._globalTemp.owner` for the party list `group_id`
/// (Meteor `Party.SendInitWorkValues`).
pub fn owner_packet(actor: u32, group_id: u64, leader: u32) -> common::subpacket::SubPacket {
    tx::build_synch_group_work_values_entries(
        actor,
        group_id,
        &[tx::WorkValue {
            kind: 8,
            name: "partyGroupWork._globalTemp.owner".into(),
            value: owner_work(leader).to_le_bytes().to_vec(),
        }],
        "/_init",
    )
}

async fn tell_all(
    world: &WorldManager,
    registry: &ActorRegistry,
    members: &[u32],
    text_id: u16,
    params: Vec<LuaParam>,
) {
    for &m in members {
        tell(world, registry, m, text_id, params.clone()).await;
    }
}

/// Offer `target` a place in the inviter's party (Meteor
/// `WorldMaster.ProcessPartyInvite`).
pub async fn invite(
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    inviter: u32,
    target: &str,
) {
    let invitee = match resolve(db, registry, target).await {
        Some(id) if registry.get(id).await.is_some() => id,
        _ => {
            tell(world, registry, inviter, 30544, vec![]).await;
            return;
        }
    };
    if invitee == inviter {
        return;
    }
    {
        let t = table();
        if t.invites.contains_key(&invitee) {
            tracing::info!(
                inviter,
                invitee,
                "party invite refused: an offer is pending"
            );
            return;
        }
    }
    if members_of(inviter).len() >= MAX_MEMBERS || members_of(invitee).len() > 1 {
        tracing::info!(
            inviter,
            invitee,
            "party invite refused: full, or already in a party"
        );
        tell(world, registry, inviter, 30544, vec![]).await;
        return;
    }
    let inv = Invite {
        inviter,
        linkshell: 0,
        relation: next_relation_id(),
    };
    table().invites.insert(invitee, inv);
    send_relation(world, registry, db, inv, invitee, INVITE_COMMAND_PARTY).await;
    tell(
        world,
        registry,
        invitee,
        30430,
        vec![LuaParam::String(name_of(db, inviter).await)],
    )
    .await;
    tell(
        world,
        registry,
        inviter,
        30433,
        vec![LuaParam::String(name_of(db, invitee).await)],
    )
    .await;
    tracing::info!(inviter, invitee, "party invite offered");
}

/// The invitee answers (ConfirmGroupCommand): 1 accept, 2 decline.
pub async fn invite_result(
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    invitee: u32,
    result: u32,
) {
    let Some(inv) = table().invites.remove(&invitee) else {
        return;
    };
    delete_relation(world, registry, inv, invitee).await;
    let name = name_of(db, invitee).await;
    if result != 1 {
        tell(
            world,
            registry,
            inv.inviter,
            30573,
            vec![LuaParam::String(name)],
        )
        .await;
        return;
    }
    let Some(members) = join(inv.inviter, invitee) else {
        tracing::info!(
            invitee,
            inviter = inv.inviter,
            "party join refused: full or already in one"
        );
        return;
    };
    tracing::info!(invitee, party = ?members, "joined a party");
    for &m in &members {
        refresh(registry, world, m).await;
    }
    tell_all(
        world,
        registry,
        &members,
        30427,
        vec![LuaParam::String(name)],
    )
    .await;
}

/// `player:PartyLeave()` (Meteor `Party.LeavePlayerRequest`).
pub async fn leave(registry: &ActorRegistry, world: &WorldManager, db: &Database, actor: u32) {
    let before = remove(actor);
    if before.is_empty() {
        return;
    }
    tell_all(
        world,
        registry,
        &before,
        30431,
        vec![LuaParam::String(name_of(db, actor).await)],
    )
    .await;
    for m in before {
        refresh(registry, world, m).await;
    }
}

/// `player:PartyDisband()` — the leader breaks the party up.
pub async fn disband(registry: &ActorRegistry, world: &WorldManager, actor: u32) {
    if !is_leader(actor) {
        tell(world, registry, actor, 30540, vec![]).await;
        return;
    }
    let members = dissolve(actor);
    tell_all(world, registry, &members, 30401, vec![]).await;
    for m in members {
        refresh(registry, world, m).await;
    }
}

/// `player:PartyOustPlayer(name | actorId)` — the leader removes a member.
pub async fn kick(
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    actor: u32,
    target: &str,
) {
    if !is_leader(actor) {
        tell(world, registry, actor, 30540, vec![]).await;
        return;
    }
    let members = members_of(actor);
    let kicked = match resolve(db, registry, target).await {
        Some(id) if id != actor && members.contains(&id) => id,
        _ => {
            tell(world, registry, actor, 30575, vec![]).await;
            return;
        }
    };
    let name = name_of(db, kicked).await;
    for &m in &members {
        if m == kicked {
            tell(world, registry, m, 30410, vec![]).await;
        } else {
            tell(
                world,
                registry,
                m,
                30428,
                vec![LuaParam::String(name.clone())],
            )
            .await;
        }
    }
    remove(kicked);
    for m in members {
        refresh(registry, world, m).await;
    }
}

/// `player:PartyPromote(name | actorId)` — hand the lead to a member.
pub async fn promote(
    registry: &ActorRegistry,
    world: &WorldManager,
    db: &Database,
    actor: u32,
    target: &str,
) {
    if !is_leader(actor) {
        tell(world, registry, actor, 30540, vec![]).await;
        return;
    }
    let members = members_of(actor);
    let new_leader = match resolve(db, registry, target).await {
        Some(id) if members.contains(&id) => id,
        _ => {
            tell(world, registry, actor, 30567, vec![]).await;
            return;
        }
    };
    let name = name_of(db, new_leader).await;
    if new_leader == actor {
        tell(world, registry, actor, 30559, vec![LuaParam::String(name)]).await;
        return;
    }
    set_leader(actor, new_leader);
    tell_all(
        world,
        registry,
        &members,
        30429,
        vec![LuaParam::String(name)],
    )
    .await;
    for m in members {
        refresh(registry, world, m).await;
    }
}

/// Party chat (`/p`): every other member hears it.
pub async fn chat(
    registry: &ActorRegistry,
    world: &WorldManager,
    actor: u32,
    sender_name: &str,
    message: &str,
) {
    let Some(h) = registry.get(actor).await else {
        return;
    };
    tracing::debug!(actor, to = ?others(actor), "party chat");
    for m in others(actor) {
        let Some(r) = registry.get(m).await else {
            continue;
        };
        let sub = crate::packets::send::misc::build_send_message(
            h.session_id,
            r.session_id,
            crate::social::chat::CHAT_PARTY,
            sender_name,
            message,
        );
        if let Some(client) = world.client(r.session_id).await {
            client.send_bytes(sub.to_bytes()).await;
        }
    }
}

/// The player logged off: they leave their party, and any offer to or
/// from them lapses.
pub async fn on_logout(registry: &ActorRegistry, world: &WorldManager, db: &Database, actor: u32) {
    let lapsed: Vec<(u32, Invite)> = {
        let mut t = table();
        t.sent.remove(&actor);
        t.solo.remove(&actor);
        let keys: Vec<u32> = t
            .invites
            .iter()
            .filter(|(k, i)| **k == actor || i.inviter == actor)
            .map(|(k, _)| *k)
            .collect();
        keys.into_iter()
            .filter_map(|k| t.invites.remove(&k).map(|i| (k, i)))
            .collect()
    };
    for (invitee, inv) in lapsed {
        delete_relation(world, registry, inv, invitee).await;
    }
    let others_before = others(actor);
    let before = remove(actor);
    if before.is_empty() {
        return;
    }
    note_away(actor, others_before, common::utils::unix_timestamp() as u64);
    let name = name_of(db, actor).await;
    let rest: Vec<u32> = before.into_iter().filter(|&m| m != actor).collect();
    tell_all(world, registry, &rest, 30431, vec![LuaParam::String(name)]).await;
    for m in rest {
        refresh(registry, world, m).await;
    }
}

fn note_away(actor: u32, others: Vec<u32>, now_secs: u64) {
    table().away.insert(
        actor,
        Away {
            others,
            at_secs: now_secs,
        },
    );
}

/// Whose party `actor` goes back into on login: a former party member
/// who is online (`online`) and whose party is still made up of the old
/// party only, the old leader first. The leader of that party, or the
/// member themself if they are on their own now. None when the window
/// has passed, nobody is left, or the party has moved on.
fn rejoin_host(actor: u32, now_secs: u64, online: &[u32]) -> Option<u32> {
    let away = table().away.remove(&actor)?;
    if now_secs.saturating_sub(away.at_secs) > REJOIN_WINDOW_SECS || table().of.contains_key(&actor)
    {
        return None;
    }
    away.others.iter().copied().find_map(|m| {
        if !online.contains(&m) {
            return None;
        }
        let theirs = members_of(m);
        let same = theirs.iter().all(|x| away.others.contains(x));
        (same && theirs.len() < MAX_MEMBERS).then(|| theirs[0])
    })
}

/// A player logged in: back into the party they dropped out of, if it is
/// still there (see [`REJOIN_WINDOW_SECS`]).
pub async fn on_login(registry: &ActorRegistry, world: &WorldManager, db: &Database, actor: u32) {
    let candidates: Vec<u32> = match table().away.get(&actor) {
        Some(a) => a.others.clone(),
        None => return,
    };
    let mut online = Vec::new();
    for m in candidates {
        if let Some(h) = registry.get(m).await
            && h.is_player()
            && world.client(h.session_id).await.is_some()
        {
            online.push(m);
        }
    }
    let Some(host) = rejoin_host(actor, common::utils::unix_timestamp() as u64, &online) else {
        return;
    };
    let Some(members) = join(host, actor) else {
        return;
    };
    tracing::info!(actor, party = ?members, "back in the party after logging in again");
    for &m in &members {
        refresh(registry, world, m).await;
    }
    tell_all(
        world,
        registry,
        &members,
        30427,
        vec![LuaParam::String(name_of(db, actor).await)],
    )
    .await;
}

#[cfg(test)]
mod tests {
    use super::*;

    // The table is process-wide; each test uses its own actor ids.

    #[test]
    fn join_leave_and_leader_hand_off() {
        assert_eq!(members_of(9001), vec![9001]);
        assert!(is_leader(9001));
        assert_eq!(join(9001, 9002), Some(vec![9001, 9002]));
        assert_eq!(join(9001, 9003), Some(vec![9001, 9002, 9003]));
        assert_eq!(members_of(9003), vec![9001, 9002, 9003]);
        assert_eq!(others(9002), vec![9001, 9003]);
        assert!(!is_leader(9002));
        // already in a party
        assert_eq!(join(9002, 9003), None);
        // the leader leaves: the next to join leads
        assert_eq!(remove(9001), vec![9001, 9002, 9003]);
        assert_eq!(leader_of(9003), 9002);
        // down to one: the party dissolves
        remove(9003);
        assert_eq!(members_of(9002), vec![9002]);
    }

    #[test]
    fn full_party_refuses() {
        for i in 1..MAX_MEMBERS as u32 {
            assert!(join(9100, 9100 + i).is_some());
        }
        assert_eq!(join(9100, 9199), None);
        assert_eq!(dissolve(9100).len(), MAX_MEMBERS);
        assert_eq!(members_of(9105), vec![9105]);
    }

    #[test]
    fn promote_moves_the_lead_to_the_front() {
        join(9201, 9202);
        set_leader(9201, 9202);
        assert_eq!(members_of(9201), vec![9202, 9201]);
        assert!(is_leader(9202));
        dissolve(9202);
    }

    #[test]
    fn rejoin_after_a_relog() {
        // a party of two: the member drops, the party dissolves
        join(9301, 9302);
        let others_before = others(9302);
        remove(9302);
        note_away(9302, others_before, 1000);
        // back in time, the old leader online: rejoins under them
        assert_eq!(rejoin_host(9302, 1000 + 60, &[9301]), Some(9301));
        assert_eq!(join(9301, 9302), Some(vec![9301, 9302]));
        dissolve(9301);
    }

    #[test]
    fn no_rejoin_late_or_into_a_new_party() {
        join(9401, 9402);
        join(9401, 9403);
        let others_before = others(9403);
        remove(9403);
        // too late
        note_away(9403, others_before.clone(), 1000);
        assert_eq!(
            rejoin_host(9403, 1000 + REJOIN_WINDOW_SECS + 1, &[9401, 9402]),
            None
        );
        // nobody from the old party online
        note_away(9403, others_before.clone(), 1000);
        assert_eq!(rejoin_host(9403, 1001, &[]), None);
        // the old party took someone else in: not theirs any more
        join(9401, 9404);
        note_away(9403, others_before, 1000);
        assert_eq!(rejoin_host(9403, 1001, &[9401, 9402]), None);
        dissolve(9401);
    }

    #[test]
    fn owner_work_packs_the_leader() {
        assert_eq!(owner_work(7), (7u64 << 32) | 0x00B3_6F92);
    }
}
