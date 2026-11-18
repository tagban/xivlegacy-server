//! Item use through `use_catalog_item` on the battle-test scene: the
//! item kinds a single test client can't reach (a KO'd ally for Raise).

use std::sync::Arc;

use crate::database::UsableItem;
use crate::lua::LuaEngine;
use crate::runtime::battle_audit_tests as bat;

const BLIND: u32 = 223_007;

async fn scene(rcpt: bat::Recipient) -> bat::Scene {
    let db = Arc::new(
        crate::database::Database::open(bat::tempdb())
            .await
            .expect("seeded db"),
    );
    let lua = Arc::new(LuaEngine::new(bat::script_root()));
    let (catalog, by_level) = db.load_global_battle_command_list().await.unwrap();
    let defs = db.load_global_status_effect_list().await.unwrap();
    lua.catalogs()
        .install_battle_commands_with_level_index(catalog.clone(), by_level);
    lua.catalogs().install_status_effects(defs);
    let esuna = catalog[&27_357].clone();
    bat::scene(&db, &lua, &esuna, rcpt).await
}

fn item(category: &str, magnitude: f64, recast_group: i32) -> UsableItem {
    UsableItem {
        category: category.into(),
        usable: true,
        magnitude,
        duration_s: 10.0,
        recast_group,
        ..Default::default()
    }
}

async fn dead(sc: &bat::Scene, id: u32) -> bool {
    let h = sc.registry.get(id).await.unwrap();
    h.character.read().await.base.current_main_state == crate::actor::MAIN_STATE_DEAD
}

#[tokio::test]
async fn company_tonic_raises_a_fallen_ally() {
    let sc = scene(bat::Recipient::DeadFriend).await;
    assert!(dead(&sc, bat::FRIEND).await);
    // Company-issue Tonic: always works (magnitude 1).
    let tonic = item("Normal/RaiseItem", 1.0, 9_101);
    sc.processor
        .use_catalog_item(bat::PLAYER, 0, 3_020_412, &tonic, bat::FRIEND)
        .await;
    assert!(!dead(&sc, bat::FRIEND).await);
}

#[tokio::test]
async fn raise_items_need_a_fallen_ally() {
    let sc = scene(bat::Recipient::Friend).await;
    let tonic = item("Normal/RaiseItem", 1.0, 9_102);
    // A living ally, or yourself: refused, nothing changes.
    for target in [bat::FRIEND, bat::PLAYER] {
        sc.processor
            .use_catalog_item(bat::PLAYER, 0, 3_020_412, &tonic, target)
            .await;
        assert!(!dead(&sc, target).await);
    }
}

#[tokio::test]
async fn blinding_potion_blinds_the_enemy_only() {
    let sc = scene(bat::Recipient::Enemy).await;
    let has_blind = |id: u32| {
        let r = sc.registry.clone();
        async move {
            let h = r.get(id).await.unwrap();
            h.character.read().await.status_effects.has(BLIND)
        }
    };
    // Used on yourself: refused.
    let potion = item("Normal/CmnBadStatusItem", 0.0, 9_103);
    sc.processor
        .use_catalog_item(bat::PLAYER, 0, 3_020_301, &potion, bat::PLAYER)
        .await;
    assert!(!has_blind(bat::PLAYER).await);
    // On the enemy: Blind lands and the enemy hates the user.
    let potion = item("Normal/CmnBadStatusItem", 0.0, 9_104);
    sc.processor
        .use_catalog_item(bat::PLAYER, 0, 3_020_301, &potion, bat::ENEMY)
        .await;
    assert!(has_blind(bat::ENEMY).await);
    let h = sc.registry.get(bat::ENEMY).await.unwrap();
    assert!(h.character.read().await.hate.has_hate_for(bat::PLAYER));
}
