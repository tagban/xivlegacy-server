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

//! Activity log writers (`log_*` tables, migration 002).
//!
//! Each runs inside the same `call_db` closure as the change it records, on
//! the same connection, so the log row lands right after the change. A log
//! write that fails is warned about and otherwise ignored: losing a log row
//! must never lose the player's change.

use std::time::{SystemTime, UNIX_EPOCH};

use crate::sql::{Conn, Params, named_params};

/// Unix seconds now.
pub fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

fn write<P: Params>(c: &Conn, table: &str, sql: &str, params: P) {
    if let Err(e) = c.execute(sql, params) {
        tracing::warn!(table, error = %e, "activity log write failed");
    }
}

pub fn session(c: &Conn, account_id: u32, chara_id: u32, event: &str, zone_id: u32, detail: &str) {
    write(
        c,
        "log_sessions",
        "INSERT INTO log_sessions (at, accountId, characterId, event, zoneId, detail) \
         VALUES (:at, :a, :c, :e, :z, :d)",
        named_params! {
            ":at": now(), ":a": account_id, ":c": chara_id, ":e": event,
            ":z": zone_id, ":d": truncate(detail, 255),
        },
    );
}

#[allow(clippy::too_many_arguments)]
pub fn item(
    c: &Conn,
    chara_id: u32,
    item_id: u32,
    server_item_id: u64,
    quantity: i64,
    item_package: u16,
    reason: &str,
) {
    if quantity == 0 {
        return;
    }
    write(
        c,
        "log_items",
        "INSERT INTO log_items (at, characterId, itemId, serverItemId, quantity, itemPackage, reason) \
         VALUES (:at, :c, :i, :s, :q, :p, :r)",
        named_params! {
            ":at": now(), ":c": chara_id, ":i": item_id, ":s": server_item_id as i64,
            ":q": quantity, ":p": item_package, ":r": truncate(reason, 32),
        },
    );
}

/// Owner, item id, bag and quantity of a `server_items` row that sits in an
/// inventory, for logging around an insert, delete or quantity change.
pub fn item_row(c: &Conn, server_item_id: u64) -> Option<(u32, u32, u16, i64)> {
    c.query_row(
        "SELECT ci.characterId, si.itemId, ci.itemPackage, si.quantity FROM server_items si \
         INNER JOIN characters_inventory ci ON ci.serverItemId = si.id WHERE si.id = :s LIMIT 1",
        named_params! { ":s": server_item_id as i64 },
        |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?, r.get(3)?)),
    )
    .ok()
}

pub fn gil(c: &Conn, chara_id: u32, delta: i64, balance: i64, reason: &str) {
    if delta == 0 {
        return;
    }
    write(
        c,
        "log_gil",
        "INSERT INTO log_gil (at, characterId, delta, balance, reason) VALUES (:at, :c, :d, :b, :r)",
        named_params! { ":at": now(), ":c": chara_id, ":d": delta, ":b": balance, ":r": truncate(reason, 32) },
    );
}

/// `kind` is `exp`, `level`, `class` or `job`.
pub fn progress(c: &Conn, chara_id: u32, kind: &str, class_id: u8, value: i64) {
    write(
        c,
        "log_progress",
        "INSERT INTO log_progress (at, characterId, kind, classId, value) VALUES (:at, :c, :k, :cl, :v)",
        named_params! { ":at": now(), ":c": chara_id, ":k": kind, ":cl": class_id, ":v": value },
    );
}

/// `kind` is `quest` or `leve`.
pub fn quest(c: &Conn, chara_id: u32, kind: &str, quest_id: u32, event: &str, sequence: u32) {
    write(
        c,
        "log_quests",
        "INSERT INTO log_quests (at, characterId, kind, questId, event, sequence) \
         VALUES (:at, :c, :k, :q, :e, :s)",
        named_params! { ":at": now(), ":c": chara_id, ":k": kind, ":q": quest_id, ":e": event, ":s": sequence },
    );
}

/// `kind` is `kill` (target: the monster's class id, amount: its level)
/// or `death` (target: what killed them, a monster class or a player).
pub fn combat(
    c: &Conn,
    chara_id: u32,
    kind: &str,
    target_id: u32,
    action_id: u32,
    amount: i64,
    zone_id: u32,
) {
    write(
        c,
        "log_combat",
        "INSERT INTO log_combat (at, characterId, targetId, actionId, kind, amount, zoneId) \
         VALUES (:at, :c, :t, :a, :k, :n, :z)",
        named_params! {
            ":at": now(), ":c": chara_id, ":t": target_id, ":a": action_id,
            ":k": truncate(kind, 16), ":n": amount, ":z": zone_id,
        },
    );
}

pub fn gm(c: &Conn, chara_id: u32, command: &str, args: &str) {
    write(
        c,
        "log_gm",
        "INSERT INTO log_gm (at, characterId, command, args) VALUES (:at, :c, :cmd, :a)",
        named_params! { ":at": now(), ":c": chara_id, ":cmd": truncate(command, 64), ":a": truncate(args, 1024) },
    );
}

fn truncate(s: &str, max: usize) -> String {
    s.chars().take(max).collect()
}
