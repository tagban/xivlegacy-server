// XIVLegacy Server — FINAL FANTASY XIV v1.23b server (lobby/world/map)
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

//! Gear stat bonuses end to end on the server: 100 pieces from the real
//! item tables (mostly crafted, every slot, levels 1-50, all kinds of
//! classes, some HQ), each equipped and taken off again through the stat
//! rebuild. The character window's numbers (`generalParameter`, max HP/MP)
//! must move by exactly the piece's bonuses (plus what STR, VIT ... derive)
//! and come back when it's off, and the client must be sent the change.

use std::collections::HashMap;
use std::sync::Arc;

use common::db::ConnCallExt;
use common::sql::named_params;

use crate::actor::Character;
use crate::actor::player::{
    SLOT_BODY, SLOT_EARS, SLOT_FEET, SLOT_FINGER_RIGHT, SLOT_HANDS, SLOT_HEAD, SLOT_LEGS,
    SLOT_MAINHAND, SLOT_NECK, SLOT_OFFHAND, SLOT_UNDERGARMENT, SLOT_UNDERSHIRT, SLOT_WAIST,
    SLOT_WRISTS,
};
use crate::data::ClientHandle;
use crate::packets::opcodes::OP_SET_ACTOR_PROPERTY;
use crate::runtime::actor_registry::{ActorHandle, ActorKindTag, ActorRegistry};
use crate::runtime::dispatcher::dispatch_status_event;
use crate::status::outbox::StatusEvent;
use crate::world_manager::WorldManager;
use crate::zone::area::{ActorKind, StoredActor};
use crate::zone::navmesh::StubNavmeshLoader;
use crate::zone::outbox::AreaOutbox;

/// One test piece: catalog id, the class and level it's worn on, its gear
/// slot, quality (2 = HQ), and its bonuses as `(stat id, value)`: `nq`
/// always, `hq` only on an HQ piece.
struct Piece {
    id: u32,
    class: u8,
    level: i16,
    slot: u16,
    quality: u8,
    nq: &'static [(u32, i32)],
    hq: &'static [(u32, i32)],
}

#[rustfmt::skip]
const PIECES: &[Piece] = &[
    Piece { id: 8032816, class: 22, level: 49, slot: SLOT_BODY, quality: 2, nq: &[(1, 40), (28, 9), (23, 10), (6, 5), (7, 5), (27, 5)], hq: &[(23, 2)] }, // Vanya Robe (Yellow)
    Piece { id: 8081907, class: 22, level: 49, slot: SLOT_FEET, quality: 2, nq: &[(17, 4), (16, 10), (8, 2), (6, 2), (5, 2)], hq: &[(16, 2)] }, // Gryphonskin Thighboots (Red)
    Piece { id: 8011602, class: 30, level: 25, slot: SLOT_HEAD, quality: 2, nq: &[(0, 17), (4, 1), (28, 1), (31, 6), (34, 12)], hq: &[] }, // Dated Assault Sallet
    Piece { id: 8051116, class: 36, level: 1, slot: SLOT_LEGS, quality: 2, nq: &[(29, 2), (30, 1), (33, 2)], hq: &[(33, 1)] }, // Hempen Shepherd's Slops (Brown)
    Piece { id: 8070719, class: 22, level: 35, slot: SLOT_HANDS, quality: 1, nq: &[(3, -2), (5, 3), (15, 3), (16, 3), (28, 8), (11, 3)], hq: &[] }, // Venerer's Bracers
    Piece { id: 8031917, class: 29, level: 17, slot: SLOT_BODY, quality: 2, nq: &[(29, 9), (32, 9), (34, 5)], hq: &[(32, 1)] }, // Cotton Shepherd's Tunic (Yellow)
    Piece { id: 5030402, class: 23, level: 50, slot: SLOT_MAINHAND, quality: 1, nq: &[(27, 10), (24, 30), (25, 10), (7, 60), (49, 1)], hq: &[] }, // Thyrus
    Piece { id: 4080302, class: 8, level: 35, slot: SLOT_MAINHAND, quality: 1, nq: &[(3, 3), (4, -1), (17, 12), (18, -5), (15, 5)], hq: &[] }, // Shellsplitter
    Piece { id: 9030026, class: 23, level: 29, slot: SLOT_EARS, quality: 2, nq: &[(28, 10), (9, 4)], hq: &[(9, 1)] }, // Sunstone Earrings
    Piece { id: 8051502, class: 22, level: 50, slot: SLOT_LEGS, quality: 1, nq: &[(1, 100), (8, 10), (26, 5), (25, 5), (16, -10)], hq: &[] }, // Darklight Breeches
    Piece { id: 8032001, class: 29, level: 36, slot: SLOT_BODY, quality: 2, nq: &[(14, 3), (28, 1), (29, 6), (31, 11)], hq: &[(29, 3)] }, // Vintage Chef's Apron
    Piece { id: 8081909, class: 22, level: 49, slot: SLOT_FEET, quality: 2, nq: &[(0, 30), (24, 3), (23, 3), (27, 1)], hq: &[(0, 6)] }, // Vanya Crakows
    Piece { id: 9030028, class: 22, level: 29, slot: SLOT_EARS, quality: 2, nq: &[(28, 10), (12, 4)], hq: &[(12, 1)] }, // Sphene Earrings
    Piece { id: 9030037, class: 23, level: 39, slot: SLOT_EARS, quality: 2, nq: &[(28, 15), (10, 7)], hq: &[(10, 1)] }, // Goshenite Earrings
    Piece { id: 8091204, class: 35, level: 46, slot: SLOT_WAIST, quality: 2, nq: &[(30, 14), (7, 2), (8, 2)], hq: &[(30, 2)] }, // Raptorskin Artisan's Belt
    Piece { id: 9030030, class: 23, level: 29, slot: SLOT_EARS, quality: 2, nq: &[(28, 10), (13, 4)], hq: &[(13, 1)] }, // Fluorite Earrings
    Piece { id: 8071510, class: 22, level: 49, slot: SLOT_HANDS, quality: 2, nq: &[(17, 5), (16, 5), (5, 5), (8, 5), (6, 5)], hq: &[(17, 1)] }, // Gryphonskin Gloves
    Piece { id: 8032817, class: 22, level: 49, slot: SLOT_BODY, quality: 2, nq: &[(1, 40), (28, 9), (23, 10), (6, 5), (7, 5), (27, 5)], hq: &[(23, 2)] }, // Vanya Robe (Black)
    Piece { id: 8011601, class: 34, level: 15, slot: SLOT_HEAD, quality: 2, nq: &[(0, 14), (4, 1), (28, 1), (31, 4), (34, 8)], hq: &[] }, // Dated Bronze Sallet
    Piece { id: 9010031, class: 23, level: 28, slot: SLOT_WRISTS, quality: 1, nq: &[(1, 9), (3, 1)], hq: &[(3, 1)] }, // Sunstone Bracelets
    Piece { id: 8011519, class: 22, level: 43, slot: SLOT_HEAD, quality: 1, nq: &[(15, 4), (6, 2), (14, 8)], hq: &[(15, 1)] }, // Boarskin Pot Helm
    Piece { id: 8051117, class: 29, level: 1, slot: SLOT_LEGS, quality: 1, nq: &[(29, 2), (30, 1), (33, 2)], hq: &[(33, 1)] }, // Hempen Shepherd's Slops (Red)
    Piece { id: 8031906, class: 41, level: 17, slot: SLOT_BODY, quality: 1, nq: &[(16, 2), (11, 1), (32, 3), (34, 6)], hq: &[] }, // Dated Cotton Shepherd's Tunic (Red)
    Piece { id: 8071511, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(17, 5), (16, 5), (5, 5), (8, 5), (6, 5)], hq: &[(17, 1)] }, // Gryphonskin Gloves (White)
    Piece { id: 9040044, class: 23, level: 38, slot: SLOT_NECK, quality: 1, nq: &[(24, 10)], hq: &[(24, 2)] }, // Pearl Choker
    Piece { id: 8032815, class: 22, level: 49, slot: SLOT_BODY, quality: 1, nq: &[(1, 40), (28, 9), (23, 10), (6, 5), (7, 5), (27, 5)], hq: &[(23, 2)] }, // Vanya Robe
    Piece { id: 8090105, class: 23, level: 39, slot: SLOT_WAIST, quality: 1, nq: &[(5, 1), (4, 1), (7, 1)], hq: &[(4, 1)] }, // Steel Plate Belt
    Piece { id: 9050027, class: 2, level: 7, slot: SLOT_FINGER_RIGHT, quality: 1, nq: &[(15, 3)], hq: &[(15, 1)] }, // Copper Ring
    Piece { id: 8010546, class: 34, level: 48, slot: SLOT_HEAD, quality: 1, nq: &[(0, 27), (1, 27), (28, 1), (31, 13)], hq: &[(31, 4)] }, // Vintage Coif
    Piece { id: 8031002, class: 35, level: 17, slot: SLOT_BODY, quality: 1, nq: &[(5, 2), (4, 2), (16, 1), (30, 3), (32, 10)], hq: &[] }, // Dated Taupe Sheepskin Jerkin (Grey)
    Piece { id: 4100604, class: 23, level: 5, slot: SLOT_OFFHAND, quality: 1, nq: &[(27, 3)], hq: &[(27, 1)] }, // Square Maple Shield
    Piece { id: 8081905, class: 22, level: 49, slot: SLOT_FEET, quality: 1, nq: &[(17, 4), (16, 10), (8, 2), (6, 2), (5, 2)], hq: &[(16, 2)] }, // Gryphonskin Thighboots (White)
    Piece { id: 4030603, class: 3, level: 50, slot: SLOT_MAINHAND, quality: 1, nq: &[(3, 7), (7, 7), (4, 7)], hq: &[(0, 40)] }, // Mailbreaker
    Piece { id: 8091201, class: 36, level: 36, slot: SLOT_WAIST, quality: 1, nq: &[(28, 1), (9, 3), (30, 12)], hq: &[(30, 4)] }, // Vintage Chef's Belt
    Piece { id: 8031905, class: 40, level: 17, slot: SLOT_BODY, quality: 1, nq: &[(16, 2), (11, 1), (32, 3), (34, 6)], hq: &[] }, // Dated Cotton Shepherd's Tunic
    Piece { id: 8051115, class: 32, level: 1, slot: SLOT_LEGS, quality: 1, nq: &[(29, 2), (30, 1), (33, 2)], hq: &[(33, 1)] }, // Hempen Shepherd's Slops
    Piece { id: 9030031, class: 22, level: 29, slot: SLOT_EARS, quality: 1, nq: &[(28, 10), (10, 4)], hq: &[(10, 1)] }, // Danburite Earrings
    Piece { id: 8081913, class: 22, level: 49, slot: SLOT_FEET, quality: 1, nq: &[(0, 30), (24, 3), (23, 3), (27, 1)], hq: &[(0, 6)] }, // Vanya Crakows (Red)
    Piece { id: 8071512, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(17, 5), (16, 5), (5, 5), (8, 5), (6, 5)], hq: &[(17, 1)] }, // Gryphonskin Gloves (Black)
    Piece { id: 9030027, class: 22, level: 29, slot: SLOT_EARS, quality: 1, nq: &[(28, 10), (14, 4)], hq: &[(14, 1)] }, // Lapis Lazuli Earrings
    Piece { id: 9030034, class: 23, level: 39, slot: SLOT_EARS, quality: 1, nq: &[(28, 15), (12, 7)], hq: &[(12, 1)] }, // Heliodor Earrings
    Piece { id: 8032819, class: 22, level: 49, slot: SLOT_BODY, quality: 1, nq: &[(1, 40), (28, 9), (23, 10), (6, 5), (7, 5), (27, 5)], hq: &[(23, 2)] }, // Vanya Robe (Red)
    Piece { id: 9030036, class: 22, level: 39, slot: SLOT_EARS, quality: 1, nq: &[(28, 15), (13, 7)], hq: &[(13, 1)] }, // Amethyst Earrings
    Piece { id: 9010037, class: 22, level: 38, slot: SLOT_WRISTS, quality: 1, nq: &[(1, 12), (3, 2)], hq: &[(3, 1)] }, // Garnet Bracelets
    Piece { id: 8031222, class: 35, level: 30, slot: SLOT_BODY, quality: 1, nq: &[(4, 4), (8, 3), (29, 14), (32, 14)], hq: &[(29, 2)] }, // Vintage Doublet Vest
    Piece { id: 8011520, class: 22, level: 48, slot: SLOT_HEAD, quality: 1, nq: &[(15, 5), (6, 2), (9, 10)], hq: &[(15, 1)] }, // Raptorskin Pot Helm
    Piece { id: 8031908, class: 41, level: 17, slot: SLOT_BODY, quality: 1, nq: &[(16, 2), (11, 1), (32, 3), (34, 6)], hq: &[] }, // Dated Cotton Shepherd's Tunic (Green)
    Piece { id: 8081911, class: 22, level: 49, slot: SLOT_FEET, quality: 1, nq: &[(0, 30), (24, 3), (23, 3), (27, 1)], hq: &[(0, 6)] }, // Vanya Crakows (Black)
    Piece { id: 8051508, class: 22, level: 49, slot: SLOT_LEGS, quality: 1, nq: &[(17, 2), (16, 6), (8, 4), (5, 4), (6, 4)], hq: &[(17, 1)] }, // Gryphonskin Trousers
    Piece { id: 8091401, class: 30, level: 1, slot: SLOT_WAIST, quality: 1, nq: &[(31, 1), (33, 1)], hq: &[(31, 1)] }, // Merchant's Purse
    Piece { id: 4030303, class: 3, level: 50, slot: SLOT_MAINHAND, quality: 1, nq: &[(3, 2), (4, 3), (17, 7), (18, 5)], hq: &[] }, // Templar's Falchion
    Piece { id: 8032818, class: 22, level: 49, slot: SLOT_BODY, quality: 1, nq: &[(1, 40), (28, 9), (23, 10), (6, 5), (7, 5), (27, 5)], hq: &[(23, 2)] }, // Vanya Robe (Purple)
    Piece { id: 9040006, class: 3, level: 32, slot: SLOT_NECK, quality: 1, nq: &[(3, 2), (9, 5)], hq: &[] }, // Dated Sunstone Choker
    Piece { id: 8011603, class: 32, level: 35, slot: SLOT_HEAD, quality: 1, nq: &[(0, 21), (4, 2), (28, 1), (31, 8), (34, 16)], hq: &[] }, // Dated Iron Sallet
    Piece { id: 8051118, class: 35, level: 17, slot: SLOT_LEGS, quality: 1, nq: &[(29, 4), (30, 2), (33, 4)], hq: &[(33, 1)] }, // Cotton Shepherd's Slops
    Piece { id: 8071513, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(17, 5), (16, 5), (5, 5), (8, 5), (6, 5)], hq: &[(17, 1)] }, // Gryphonskin Gloves (Red)
    Piece { id: 8031913, class: 40, level: 27, slot: SLOT_BODY, quality: 1, nq: &[(16, 2), (11, 1), (32, 5), (34, 9)], hq: &[] }, // Dated Canvas Shepherd's Tunic (Brown)
    Piece { id: 8030246, class: 30, level: 48, slot: SLOT_BODY, quality: 1, nq: &[(1, 57), (7, 4), (28, 5), (29, 20), (30, 12)], hq: &[(1, 13)] }, // Vintage Robe
    Piece { id: 9050028, class: 2, level: 17, slot: SLOT_FINGER_RIGHT, quality: 1, nq: &[(15, 6)], hq: &[(15, 1)] }, // Brass Ring
    Piece { id: 8091005, class: 23, level: 50, slot: SLOT_WAIST, quality: 1, nq: &[(1, 20), (24, 3)], hq: &[(24, 1)] }, // Vanya Sash
    Piece { id: 8051103, class: 41, level: 7, slot: SLOT_LEGS, quality: 1, nq: &[(16, 1), (28, 1), (12, 1), (34, 1)], hq: &[] }, // Dated Hempen Shepherd's Slops (Grey)
    Piece { id: 8071514, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(17, 5), (16, 5), (5, 5), (8, 5), (6, 5)], hq: &[(17, 1)] }, // Gryphonskin Gloves (Yellow)
    Piece { id: 5030407, class: 23, level: 50, slot: SLOT_MAINHAND, quality: 1, nq: &[(11, 15), (44, 40), (27, 25), (26, 15)], hq: &[] }, // Garuda's Wile
    Piece { id: 8081912, class: 22, level: 49, slot: SLOT_FEET, quality: 1, nq: &[(0, 30), (24, 3), (23, 3), (27, 1)], hq: &[(0, 6)] }, // Vanya Crakows (Purple)
    Piece { id: 9030033, class: 23, level: 39, slot: SLOT_EARS, quality: 1, nq: &[(28, 15), (14, 7)], hq: &[(14, 1)] }, // Aquamarine Earrings
    Piece { id: 8012904, class: 35, level: 47, slot: SLOT_HEAD, quality: 1, nq: &[(29, 7), (31, 20), (32, 20)], hq: &[(31, 4)] }, // Cobalt Mesail (Blue)
    Piece { id: 9040010, class: 2, level: 32, slot: SLOT_NECK, quality: 1, nq: &[(5, 2), (13, 5)], hq: &[] }, // Dated Fluorite Choker
    Piece { id: 9010033, class: 22, level: 28, slot: SLOT_WRISTS, quality: 1, nq: &[(1, 9), (4, 1)], hq: &[(4, 1)] }, // Sphene Bracelets
    Piece { id: 4100605, class: 23, level: 17, slot: SLOT_OFFHAND, quality: 1, nq: &[(27, 4)], hq: &[(27, 1)] }, // Square Ash Shield
    Piece { id: 9030044, class: 23, level: 49, slot: SLOT_EARS, quality: 1, nq: &[(28, 20), (10, 10)], hq: &[(10, 2)] }, // Zircon Earrings
    Piece { id: 8032216, class: 31, level: 25, slot: SLOT_BODY, quality: 1, nq: &[(7, 1), (16, 2), (30, 9), (33, 10)], hq: &[(7, 2)] }, // Vintage Coatee
    Piece { id: 8050708, class: 32, level: 38, slot: SLOT_LEGS, quality: 1, nq: &[(5, 1), (8, 1), (16, 9), (29, 8), (32, 10)], hq: &[] }, // Dated Velveteen Sarouel (Black)
    Piece { id: 8011817, class: 31, level: 13, slot: SLOT_HEAD, quality: 1, nq: &[(3, 1), (30, 8), (34, 8)], hq: &[(30, 1)] }, // Cotton Scarf (Blue)
    Piece { id: 8081910, class: 22, level: 49, slot: SLOT_FEET, quality: 1, nq: &[(0, 30), (24, 3), (23, 3), (27, 1)], hq: &[(0, 6)] }, // Vanya Crakows (Yellow)
    Piece { id: 8051104, class: 41, level: 7, slot: SLOT_LEGS, quality: 1, nq: &[(16, 1), (28, 1), (12, 1), (34, 1)], hq: &[] }, // Dated Hempen Shepherd's Slops (Beige)
    Piece { id: 8011405, class: 22, level: 22, slot: SLOT_HEAD, quality: 1, nq: &[(15, 2), (3, 1), (8, 1)], hq: &[(15, 1)] }, // Iron Elmo (Brown)
    Piece { id: 9030032, class: 22, level: 39, slot: SLOT_EARS, quality: 1, nq: &[(28, 15), (9, 7)], hq: &[(9, 1)] }, // Garnet Earrings
    Piece { id: 8081908, class: 22, level: 49, slot: SLOT_FEET, quality: 1, nq: &[(17, 4), (16, 10), (8, 2), (6, 2), (5, 2)], hq: &[(16, 2)] }, // Gryphonskin Thighboots (Yellow)
    Piece { id: 8071515, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(0, 30), (24, 3), (23, 5), (27, 7)], hq: &[(23, 1)] }, // Vanya Gloves
    Piece { id: 8031909, class: 40, level: 17, slot: SLOT_BODY, quality: 1, nq: &[(16, 2), (11, 1), (32, 3), (34, 6)], hq: &[] }, // Dated Cotton Shepherd's Tunic (Blue)
    Piece { id: 9030043, class: 22, level: 49, slot: SLOT_EARS, quality: 1, nq: &[(28, 20), (13, 10)], hq: &[(13, 2)] }, // Spinel Earrings
    Piece { id: 8051120, class: 31, level: 17, slot: SLOT_LEGS, quality: 1, nq: &[(29, 4), (30, 2), (33, 4)], hq: &[(33, 1)] }, // Cotton Shepherd's Slops (Yellow)
    Piece { id: 9010032, class: 23, level: 28, slot: SLOT_WRISTS, quality: 1, nq: &[(1, 9), (7, 1)], hq: &[(7, 1)] }, // Lapis Lazuli Bracelets
    Piece { id: 9050032, class: 4, level: 29, slot: SLOT_FINGER_RIGHT, quality: 1, nq: &[(3, 5)], hq: &[(3, 1)] }, // Sunstone Ring
    Piece { id: 8011604, class: 29, level: 45, slot: SLOT_HEAD, quality: 1, nq: &[(0, 25), (4, 3), (28, 1), (31, 10), (34, 21)], hq: &[] }, // Dated Iron Assault Sallet
    Piece { id: 8051510, class: 22, level: 49, slot: SLOT_LEGS, quality: 1, nq: &[(17, 2), (16, 6), (8, 4), (5, 4), (6, 4)], hq: &[(17, 1)] }, // Gryphonskin Trousers (Black)
    Piece { id: 9040008, class: 2, level: 32, slot: SLOT_NECK, quality: 1, nq: &[(4, 2), (12, 5)], hq: &[] }, // Dated Sphene Choker
    Piece { id: 8071517, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(0, 30), (24, 3), (23, 5), (27, 7)], hq: &[(23, 1)] }, // Vanya Gloves (Black)
    Piece { id: 8010109, class: 34, level: 26, slot: SLOT_HEAD, quality: 1, nq: &[(1, 28), (6, 1), (28, 5), (30, 9), (31, 5)], hq: &[] }, // Dated Canvas Hat (Blue)
    Piece { id: 8080234, class: 34, level: 1, slot: SLOT_FEET, quality: 1, nq: &[(0, 9), (29, 2), (33, 2)], hq: &[(29, 1)] }, // Sheepskin Duckbills of Toiling
    Piece { id: 8031907, class: 41, level: 17, slot: SLOT_BODY, quality: 1, nq: &[(16, 2), (11, 1), (32, 3), (34, 6)], hq: &[] }, // Dated Cotton Shepherd's Tunic (Yellow)
    Piece { id: 8090107, class: 23, level: 49, slot: SLOT_WAIST, quality: 1, nq: &[(5, 1), (4, 2), (7, 2)], hq: &[(4, 1)] }, // Cobalt Plate Belt
    Piece { id: 9030040, class: 22, level: 49, slot: SLOT_EARS, quality: 1, nq: &[(28, 20), (14, 10)], hq: &[(14, 2)] }, // Turquoise Earrings
    Piece { id: 8051512, class: 22, level: 49, slot: SLOT_LEGS, quality: 1, nq: &[(17, 2), (16, 6), (8, 4), (5, 4), (6, 4)], hq: &[(17, 1)] }, // Gryphonskin Trousers (Yellow)
    Piece { id: 8011020, class: 36, level: 26, slot: SLOT_HEAD, quality: 1, nq: &[(15, 2), (30, 12), (33, 12)], hq: &[(15, 1)] }, // Velveteen Bandana (Red)
    Piece { id: 8071518, class: 22, level: 49, slot: SLOT_HANDS, quality: 1, nq: &[(0, 30), (24, 3), (23, 5), (27, 7)], hq: &[(23, 1)] }, // Vanya Gloves (Purple)
    Piece { id: 8050710, class: 35, level: 38, slot: SLOT_LEGS, quality: 1, nq: &[(5, 1), (8, 1), (16, 9), (29, 8), (32, 10)], hq: &[] }, // Dated Velveteen Sarouel (Yellow)
    Piece { id: 8081920, class: 22, level: 50, slot: SLOT_FEET, quality: 1, nq: &[(1, 20), (6, 3), (7, 3)], hq: &[(27, 1)] }, // Spruce Pattens
    Piece { id: 8030034, class: 29, level: 48, slot: SLOT_BODY, quality: 1, nq: &[(3, 2), (4, 2), (29, 26), (30, 9)], hq: &[(30, 3)] }, // Dodore Doublet
    Piece { id: 8051102, class: 39, level: 7, slot: SLOT_LEGS, quality: 1, nq: &[(16, 1), (28, 1), (12, 1), (34, 1)], hq: &[] }, // Dated Hempen Shepherd's Slops (Brown)
];

/// What the stat rebuild derives from the main attributes
/// (`apply_player_stat_derivation`): STR → Attack, DEX → Accuracy,
/// VIT → Defense (×0.667), INT → attack magic, MND → magic accuracy,
/// healing and enhancing, PIE → magic evasion and enfeebling (×0.25).
fn derived(p: &[i32; 35]) -> [i32; 35] {
    let f = |v: i32, k: f64| (f64::from(v) * k).floor() as i32;
    let mut d = [0; 35];
    d[17] = f(p[3], 0.667);
    d[15] = f(p[5], 0.667);
    d[18] = f(p[4], 0.667);
    d[23] = f(p[6], 0.25);
    d[27] = f(p[7], 0.25);
    d[24] = f(p[7], 0.25);
    d[25] = f(p[7], 0.25);
    d[28] = f(p[8], 0.25);
    d[26] = f(p[8], 0.25);
    d
}

struct Snapshot {
    params: [i32; 35],
    max_hp: i32,
    max_mp: i32,
}

async fn snapshot(registry: &ActorRegistry) -> Snapshot {
    let h = registry.get(1).await.unwrap();
    let c = h.character.read().await;
    Snapshot {
        params: c.battle_temp.general_parameter.map(i32::from),
        max_hp: c.chara.max_hp as i32,
        max_mp: c.chara.max_mp as i32,
    }
}

#[tokio::test]
async fn gear_bonuses_reach_the_character_window_and_leave_on_unequip() {
    let world = Arc::new(WorldManager::new());
    let registry = Arc::new(ActorRegistry::new());
    let db = Arc::new(
        crate::database::Database::open(common::test_db::fresh_blocking())
            .await
            .expect("db"),
    );
    let items = db.get_item_gamedata().await.expect("item tables");
    let catalogs = Arc::new(crate::lua::Catalogs::default());
    catalogs.install_items(items.clone());

    let mut zone = crate::zone::zone::Zone::new(
        100,
        "t",
        1,
        "/T",
        0,
        0,
        0,
        false,
        false,
        false,
        false,
        false,
        Some(&StubNavmeshLoader),
    );
    let mut ob = AreaOutbox::new();
    zone.core.add_actor(
        StoredActor {
            actor_id: 1,
            kind: ActorKind::Player,
            position: common::Vector3::ZERO,
            grid: (0, 0),
            is_alive: true,
        },
        &mut ob,
    );
    world.register_zone(zone).await;
    registry
        .insert(ActorHandle::new(
            1,
            ActorKindTag::Player,
            100,
            42,
            Character::new(1),
        ))
        .await;
    let (tx, mut rx) = tokio::sync::mpsc::channel::<Vec<u8>>(256);
    world.register_client(42, ClientHandle::new(42, tx)).await;
    let recalc = || async {
        dispatch_status_event(
            &StatusEvent::RecalcStats { owner_actor_id: 1 },
            &registry,
            &world,
            &db,
            &catalogs,
        )
        .await;
    };
    let mut drain = || {
        let mut n = 0;
        while let Ok(bytes) = rx.try_recv() {
            if bytes.len() >= 20
                && u16::from_le_bytes([bytes[18], bytes[19]]) == OP_SET_ACTOR_PROPERTY
            {
                n += 1;
            }
        }
        n
    };

    let mut failures = Vec::new();
    for (n, p) in PIECES.iter().enumerate() {
        let item = items
            .get(&p.id)
            .unwrap_or_else(|| panic!("{} not in the item tables", p.id));
        // The item tables carry the bonuses the test expects.
        let mut got_nq = item.gear_bonuses.clone();
        got_nq.sort();
        let mut want_nq: Vec<(u32, i32)> = p.nq.to_vec();
        want_nq.sort();
        assert_eq!(got_nq, want_nq, "{} ({}) NQ bonuses", p.id, item.name);
        assert_eq!(
            item.hq_bonuses,
            p.hq.to_vec(),
            "{} ({}) HQ bonus",
            p.id,
            item.name
        );

        {
            let h = registry.get(1).await.unwrap();
            let mut c = h.character.write().await;
            c.chara.class = p.class as i16;
            c.chara.level = p.level;
        }
        recalc().await;
        drain();
        let before = snapshot(&registry).await;

        let server_item = 10_000 + n as u64;
        let (class, slot, quality, id) = (p.class, p.slot, p.quality, p.id);
        db.conn_for_test()
            .call_db(move |c| {
                c.execute(
                    "INSERT INTO server_items (id, itemId, quantity, quality) VALUES (:sid, :iid, 1, :q)",
                    named_params! { ":sid": server_item, ":iid": id, ":q": quality },
                )?;
                c.execute(
                    "INSERT INTO characters_inventory_equipment (characterId, classId, equipSlot, itemId)
                     VALUES (1, :class, :slot, :sid)",
                    named_params! { ":class": class, ":slot": slot, ":sid": server_item },
                )?;
                Ok(())
            })
            .await
            .unwrap();
        recalc().await;
        let sent = drain();
        let after = snapshot(&registry).await;

        // Expected: before + the bonuses (+ the HQ one) + what the main
        // attributes derive + a weapon's flat Attack.
        let mut bonus = [0i32; 35];
        let (mut hp, mut mp) = (0, 0);
        let worn = p.nq.iter().chain(if p.quality >= 2 { p.hq } else { &[] });
        for &(stat, v) in worn {
            match stat {
                0 => hp += v,
                1 => mp += v,
                3..=34 => bonus[stat as usize] += v,
                _ => {}
            }
        }
        if matches!(p.slot, SLOT_MAINHAND | SLOT_OFFHAND)
            && let Some(w) = item.weapon
        {
            bonus[17] += i32::from(w.attack);
        }
        let mut prim_after = before.params;
        for i in 3..=8 {
            prim_after[i] += bonus[i];
        }
        let (d0, d1) = (derived(&before.params), derived(&prim_after));
        let mut want = before.params;
        for i in 3..35 {
            want[i] += bonus[i] + d1[i] - d0[i];
        }
        if after.params != want {
            failures.push(format!(
                "{} {}: window {:?}, want {:?}",
                p.id,
                item.name,
                &after.params[3..],
                &want[3..]
            ));
        }
        if after.max_hp != before.max_hp + hp || after.max_mp != before.max_mp + mp {
            failures.push(format!(
                "{} {}: HP/MP max {}/{} -> {}/{}, want +{hp}/+{mp}",
                p.id, item.name, before.max_hp, before.max_mp, after.max_hp, after.max_mp
            ));
        }
        if after.params != before.params && sent == 0 {
            failures.push(format!(
                "{} {}: stats moved but nothing was sent",
                p.id, item.name
            ));
        }

        db.conn_for_test()
            .call_db(move |c| {
                c.execute(
                    "DELETE FROM characters_inventory_equipment WHERE characterId = 1",
                    [],
                )?;
                Ok(())
            })
            .await
            .unwrap();
        recalc().await;
        let sent_off = drain();
        let off = snapshot(&registry).await;
        if off.params != before.params || off.max_hp != before.max_hp || off.max_mp != before.max_mp
        {
            failures.push(format!(
                "{} {}: unequip left {:?}",
                p.id,
                item.name,
                &off.params[3..]
            ));
        }
        if after.params != before.params && sent_off == 0 {
            failures.push(format!("{} {}: unequip sent nothing", p.id, item.name));
        }
    }
    assert!(
        failures.is_empty(),
        "{} of {} pieces failed:\n{}",
        failures.len(),
        PIECES.len(),
        failures.join("\n")
    );
}

/// An NQ piece doesn't get the HQ bonus (paramBonus slot 4); an HQ one does.
#[test]
fn hq_bonus_only_on_hq_pieces() {
    use crate::data::ItemData;
    let mut items = HashMap::new();
    items.insert(
        9,
        ItemData {
            id: 9,
            gear_bonuses: vec![(23, 10)],
            hq_bonuses: vec![(23, 2)],
            ..Default::default()
        },
    );
    let equipped: HashMap<u16, u32> = [(SLOT_BODY, 9)].into();
    let mut nq = Character::new(1);
    nq.apply_player_gear_stats(&items, &equipped);
    nq.apply_player_hq_gear_stats(&items, &equipped, &Default::default());
    assert_eq!(nq.chara.mods.get_raw(23), 10.0);
    let mut hq = Character::new(1);
    hq.apply_player_gear_stats(&items, &equipped);
    hq.apply_player_hq_gear_stats(&items, &equipped, &[SLOT_BODY].into());
    assert_eq!(hq.chara.mods.get_raw(23), 12.0);
}

/// The gear slot for an item-table `equipPoint` (as `!equip` uses).
fn slot_for_point(point: i64) -> Option<(u16, &'static str)> {
    Some(match point {
        36..=39 => (SLOT_MAINHAND, "main"),
        2 | 40 => (SLOT_OFFHAND, "offhand"),
        9 => (SLOT_HEAD, "head"),
        11 => (SLOT_BODY, "body"),
        13 => (SLOT_LEGS, "legs"),
        14 => (SLOT_HANDS, "hands"),
        15 => (SLOT_FEET, "feet"),
        16 => (SLOT_WAIST, "waist"),
        17 => (SLOT_NECK, "neck"),
        47 => (SLOT_EARS, "ears"),
        45 => (SLOT_WRISTS, "wrists"),
        49 => (SLOT_FINGER_RIGHT, "ring"),
        10 => (SLOT_UNDERSHIRT, "undershirt"),
        12 => (SLOT_UNDERGARMENT, "undergarment"),
        // Cowls (body + head), the Reindeer Suit and flanchards cover
        // more than one slot; the client wears them in the body slot.
        42..=44 => (SLOT_BODY, "body"),
        _ => return None,
    })
}

fn csv_field(s: &str) -> String {
    if s.contains([',', '"', '\n']) {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

/// Every equippable item in the tables, NQ and (where it has an HQ bonus)
/// HQ: equip it through the stat rebuild, compare each bonus stat's change
/// with the item row read straight from `gamedata_items_equipment`, take it
/// off and check it all comes back. Rows whose bonus data looks malformed
/// are noted. Slow (~4,400 items), so it only runs when asked:
/// `GEAR_ALL_CSV=<out.csv> cargo test -p map-server gear_stats_full_catalog -- --ignored`.
#[tokio::test]
#[ignore]
async fn gear_stats_full_catalog() {
    use crate::actor::modifier::Modifier;
    let out_path =
        std::env::var("GEAR_ALL_CSV").unwrap_or_else(|_| "gear_stats_server_all.csv".into());
    let world = Arc::new(WorldManager::new());
    let registry = Arc::new(ActorRegistry::new());
    let db = Arc::new(
        crate::database::Database::open(common::test_db::fresh_blocking())
            .await
            .expect("db"),
    );
    let items = db.get_item_gamedata().await.expect("item tables");
    let catalogs = Arc::new(crate::lua::Catalogs::default());
    catalogs.install_items(items.clone());
    // (id, name, level, mainSkill, equipPoint, [type, value] x10, crafted)
    type Row = (u32, String, i64, i64, i64, Vec<(i64, i64)>, bool);
    let rows: Vec<Row> = db
        .conn_for_test()
        .call_db(|c| {
            let mut st = c.prepare(
                "SELECT i.catalogID, i.name, i.level, i.mainSkill, e.equipPoint,
                        e.paramBonusType1, e.paramBonusValue1, e.paramBonusType2, e.paramBonusValue2,
                        e.paramBonusType3, e.paramBonusValue3, e.paramBonusType4, e.paramBonusValue4,
                        e.paramBonusType5, e.paramBonusValue5, e.paramBonusType6, e.paramBonusValue6,
                        e.paramBonusType7, e.paramBonusValue7, e.paramBonusType8, e.paramBonusValue8,
                        e.paramBonusType9, e.paramBonusValue9, e.paramBonusType10, e.paramBonusValue10,
                        EXISTS(SELECT 1 FROM gamedata_recipes r WHERE r.craftedItem = i.catalogID)
                 FROM gamedata_items i JOIN gamedata_items_equipment e ON e.catalogID = i.catalogID
                 WHERE i.catalogID >= 4000000 ORDER BY i.catalogID",
            )?;
            let rows = st
                .query_map([], |r| {
                    let mut b = Vec::new();
                    for k in 0..10 {
                        b.push((r.get::<_, i64>(5 + 2 * k)?, r.get::<_, i64>(6 + 2 * k)?));
                    }
                    Ok((
                        r.get::<_, u32>(0)?,
                        r.get::<_, String>(1).unwrap_or_default(),
                        r.get::<_, i64>(2).unwrap_or(0),
                        r.get::<_, i64>(3).unwrap_or(0),
                        r.get::<_, i64>(4).unwrap_or(0),
                        b,
                        r.get::<_, i64>(25).unwrap_or(0) != 0,
                    ))
                })?
                .collect::<common::sql::Result<Vec<Row>>>()?;
            Ok(rows)
        })
        .await
        .unwrap();

    let mut zone = crate::zone::zone::Zone::new(
        100,
        "t",
        1,
        "/T",
        0,
        0,
        0,
        false,
        false,
        false,
        false,
        false,
        Some(&StubNavmeshLoader),
    );
    let mut ob = AreaOutbox::new();
    zone.core.add_actor(
        StoredActor {
            actor_id: 1,
            kind: ActorKind::Player,
            position: common::Vector3::ZERO,
            grid: (0, 0),
            is_alive: true,
        },
        &mut ob,
    );
    world.register_zone(zone).await;
    let mut ch = Character::new(1);
    ch.chara.class = 3;
    ch.chara.level = 50;
    registry
        .insert(ActorHandle::new(1, ActorKindTag::Player, 100, 42, ch))
        .await;
    let (tx, mut rx) = tokio::sync::mpsc::channel::<Vec<u8>>(4096);
    world.register_client(42, ClientHandle::new(42, tx)).await;
    let recalc = || async {
        dispatch_status_event(
            &StatusEvent::RecalcStats { owner_actor_id: 1 },
            &registry,
            &world,
            &db,
            &catalogs,
        )
        .await;
    };
    // (mods by stat id, window params, max hp, max mp)
    let snap = || async {
        let h = registry.get(1).await.unwrap();
        let c = h.character.read().await;
        (
            c.chara.mods.clone(),
            c.battle_temp.general_parameter,
            c.chara.max_hp as i64,
            c.chara.max_mp as i64,
        )
    };
    let derived_ids = [15u32, 17, 18, 23, 24, 25, 26, 27, 28];
    let derive = |m: &crate::actor::modifier::ModifierMap| -> HashMap<u32, i64> {
        let f = |id: u32, k: f64| (m.get_raw(id) * k).floor() as i64;
        HashMap::from([
            (17, f(3, 0.667)),
            (15, f(5, 0.667)),
            (18, f(4, 0.667)),
            (23, f(6, 0.25)),
            (27, f(7, 0.25)),
            (24, f(7, 0.25)),
            (25, f(7, 0.25)),
            (28, f(8, 0.25)),
            (26, f(8, 0.25)),
        ])
    };
    let stat_name = |id: u32| -> String {
        Modifier::from_u32(id)
            .map(|m| format!("{m:?}"))
            .unwrap_or_else(|| format!("stat{id}"))
    };

    let mut csv = String::from(
        "item_id,name,slot,hq,class,level,bonus,expected,before,after,after_unequip,result,note\n",
    );
    let (mut total, mut pass) = (0, 0);
    let mut next_sid = 50_000u64;
    for (id, name, level, main_skill, point, raw, crafted) in &rows {
        // Malformed / odd bonus data, read from the raw row.
        let mut notes: Vec<String> = Vec::new();
        let mut nq: Vec<(u32, i64)> = Vec::new();
        let mut hq: Vec<(u32, i64)> = Vec::new();
        let mut seen = std::collections::HashSet::new();
        for (k, &(t, v)) in raw.iter().enumerate() {
            let slot = k + 1;
            match t {
                -1 => {
                    if v != 0 {
                        notes.push(format!("slot {slot}: value {v} with no stat type"));
                    }
                }
                15001..=15100 => {
                    let stat = (t - 15001) as u32;
                    if v == 0 {
                        notes.push(format!("slot {slot}: {} with value 0", stat_name(stat)));
                        continue;
                    }
                    if Modifier::from_u32(stat).is_none() {
                        notes.push(format!("slot {slot}: type {t} is no known stat"));
                    }
                    if slot == 4 {
                        hq.push((stat, v));
                        if !crafted {
                            notes.push("HQ bonus on an item no recipe makes".into());
                        }
                    } else {
                        if slot == 2 {
                            notes.push(format!(
                                "slot 2 bonus {}{v:+} (after a {} condition in slot 1) is applied unconditionally",
                                stat_name(stat),
                                raw[0].0
                            ));
                        }
                        if !seen.insert(stat) {
                            notes.push(format!("{} listed twice", stat_name(stat)));
                        }
                        nq.push((stat, v));
                    }
                }
                16000..=16999 if slot == 1 => {}
                _ => notes.push(format!("slot {slot}: unknown type {t} (value {v})")),
            }
        }
        let Some((slot, slot_name)) = slot_for_point(*point) else {
            total += 1;
            csv.push_str(&format!(
                "{id},{},?,NQ,,{level},,,,,,FAIL,{}\n",
                csv_field(name),
                csv_field(&format!("no gear slot for equipPoint {point}"))
            ));
            continue;
        };
        let item = items.get(id);
        if let Some(item) = item {
            let mut a: Vec<(u32, i64)> = item
                .gear_bonuses
                .iter()
                .map(|&(m, v)| (m, v as i64))
                .collect();
            let mut b = nq.clone();
            a.sort();
            b.sort();
            if a != b {
                notes.push(format!("loaded bonuses {a:?} differ from the row {b:?}"));
            }
        }
        let class = if (1..=60).contains(main_skill) && slot == SLOT_MAINHAND {
            *main_skill as i16
        } else {
            3
        };
        let qualities: &[u8] = if hq.is_empty() { &[1] } else { &[1, 2] };
        for &quality in qualities {
            total += 1;
            {
                let h = registry.get(1).await.unwrap();
                let mut c = h.character.write().await;
                c.chara.class = class;
                c.chara.level = (*level).clamp(1, 50) as i16;
            }
            recalc().await;
            while rx.try_recv().is_ok() {}
            let (m0, p0, hp0, mp0) = snap().await;
            let sid = next_sid;
            next_sid += 1;
            let (cid, s, q) = (*id, slot, quality);
            // Undershirts/undergarments are shared by every class (class 0).
            let row_class = if matches!(slot, SLOT_UNDERSHIRT | SLOT_UNDERGARMENT) {
                0
            } else {
                class
            };
            db.conn_for_test()
                .call_db(move |c| {
                    c.execute(
                        "INSERT INTO server_items (id, itemId, quantity, quality) VALUES (:sid, :iid, 1, :q)",
                        named_params! { ":sid": sid, ":iid": cid, ":q": q },
                    )?;
                    c.execute(
                        "INSERT INTO characters_inventory_equipment (characterId, classId, equipSlot, itemId)
                         VALUES (1, :class, :slot, :sid)",
                        named_params! { ":class": row_class, ":slot": s, ":sid": sid },
                    )?;
                    Ok(())
                })
                .await
                .unwrap();
            recalc().await;
            let mut sent = 0;
            while let Ok(bytes) = rx.try_recv() {
                if bytes.len() >= 20
                    && u16::from_le_bytes([bytes[18], bytes[19]]) == OP_SET_ACTOR_PROPERTY
                {
                    sent += 1;
                }
            }
            let (m1, p1, hp1, mp1) = snap().await;
            db.conn_for_test()
                .call_db(move |c| {
                    c.execute(
                        "DELETE FROM characters_inventory_equipment WHERE characterId = 1",
                        [],
                    )?;
                    c.execute(
                        "DELETE FROM server_items WHERE id = :sid",
                        named_params! { ":sid": sid },
                    )?;
                    Ok(())
                })
                .await
                .unwrap();
            recalc().await;
            while rx.try_recv().is_ok() {}
            let (m2, p2, hp2, mp2) = snap().await;

            let worn: Vec<(u32, i64)> = nq
                .iter()
                .chain(if quality >= 2 { hq.iter() } else { [].iter() })
                .copied()
                .collect();
            let mut delta: HashMap<u32, i64> = HashMap::new();
            for &(s, v) in &worn {
                *delta.entry(s).or_default() += v;
            }
            if let Some(w) = item.and_then(|i| i.weapon)
                && matches!(slot, SLOT_MAINHAND | SLOT_OFFHAND)
            {
                *delta.entry(17).or_default() += i64::from(w.attack);
                *delta.entry(39).or_default() += i64::from(w.parry);
            }
            let (d0, d1) = (derive(&m0), derive(&m1));
            let mut stats: Vec<u32> = Vec::new();
            // The listed bonuses, then weapon Attack (Parry, 39, isn't in
            // the window).
            let weapon = delta.iter().filter(|(_, v)| **v != 0).map(|(s, _)| *s);
            for s in worn.iter().map(|(s, _)| *s).chain(weapon) {
                if !stats.contains(&s) && s != 39 {
                    stats.push(s);
                }
            }
            let mut ok = true;
            let mut bad = Vec::new();
            let (mut exp_s, mut bef_s, mut aft_s, mut off_s) =
                (Vec::new(), Vec::new(), Vec::new(), Vec::new());
            for &s in &stats {
                let (b, a, o, e) = match s {
                    0 => (hp0, hp1, hp2, hp0 + delta[&0]),
                    1 => (mp0, mp1, mp2, mp0 + delta[&1]),
                    _ => {
                        let mut e = m0.get_raw(s) as i64 + delta.get(&s).copied().unwrap_or(0);
                        if derived_ids.contains(&s) {
                            e += d1[&s] - d0[&s];
                        }
                        (
                            m0.get_raw(s) as i64,
                            m1.get_raw(s) as i64,
                            m2.get_raw(s) as i64,
                            e,
                        )
                    }
                };
                // The window copy the client was sent matches the stat.
                if (3..35).contains(&s) && i64::from(p1[s as usize]) != a {
                    ok = false;
                    bad.push(format!(
                        "{} window {} vs stat {a}",
                        stat_name(s),
                        p1[s as usize]
                    ));
                }
                if (3..35).contains(&s) && (p2[s as usize] != p0[s as usize]) {
                    ok = false;
                    bad.push(format!("{} window not back after unequip", stat_name(s)));
                }
                if a != e || o != b {
                    ok = false;
                    bad.push(format!(
                        "{}: want {e}, got {a} (off {o}, before {b})",
                        stat_name(s)
                    ));
                }
                let n = stat_name(s);
                exp_s.push(format!("{n}={e}"));
                bef_s.push(format!("{n}={b}"));
                aft_s.push(format!("{n}={a}"));
                off_s.push(format!("{n}={o}"));
            }
            if p1 != p0 && sent == 0 {
                ok = false;
                bad.push("stats moved but nothing was sent".into());
            }
            if stats.is_empty() && (p1 != p0 || hp1 != hp0 || mp1 != mp0) {
                ok = false;
                bad.push("no bonuses but the window moved".into());
            }
            let result = if ok { "PASS" } else { "FAIL" };
            if result == "PASS" {
                pass += 1;
            }
            let mut note = bad;
            note.extend(notes.iter().cloned());
            if worn.is_empty() {
                note.push("no stat bonuses".into());
            }
            csv.push_str(
                &[
                    id.to_string(),
                    csv_field(name),
                    slot_name.into(),
                    if quality >= 2 {
                        "HQ".into()
                    } else {
                        "NQ".into()
                    },
                    class.to_string(),
                    level.to_string(),
                    csv_field(
                        &worn
                            .iter()
                            .map(|(s, v)| format!("{}{v:+}", stat_name(*s)))
                            .collect::<Vec<_>>()
                            .join("; "),
                    ),
                    csv_field(&exp_s.join("; ")),
                    csv_field(&bef_s.join("; ")),
                    csv_field(&aft_s.join("; ")),
                    csv_field(&off_s.join("; ")),
                    result.into(),
                    csv_field(&note.join("; ")),
                ]
                .join(","),
            );
            csv.push('\n');
        }
    }
    std::fs::write(&out_path, csv).expect("write csv");
    eprintln!("gear_stats_full_catalog: {pass}/{total} pass -> {out_path}");
}
