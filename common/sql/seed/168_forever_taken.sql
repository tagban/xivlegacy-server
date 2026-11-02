-- Forever Taken (Man304, the shared level 34 story), Hedyn's errand for the
-- sylphs of the Ashcrown Consortium (scripts/lua/quests/man/man304.lua).
-- Hedyn and the Waking Sands staff already stand where Man300 put them.
-- This adds:
--
-- * The quest's place in the story: it follows Toll of the Warden.
-- * The five warm spots where the crystals are buried, in eastern Mor Dhona
--   (zone 190) by the road from the Black Shroud: three around the pond and
--   two in the valley walls. Positions are the client's own journal map
--   markers for the quest (11001607-11001611), read off the quest's map;
--   heights checked in the test client. The north wall marker sits on a
--   ledge about six yalms above anywhere a player can walk, so that spot
--   is stepped down to the ground below it.
--
-- Idempotent: UPDATEs guarded, INSERTs OR IGNORE on id. No schema change.

UPDATE "gamedata_quests" SET "prerequisite" = 110015 WHERE "id" = 110016 AND "prerequisite" = 0;

-- Five walk-in triggers, borrowing stripped classes (classPath '', no spawn,
-- no other reference). Their push circles stay off until the quest turns
-- them on.
UPDATE "gamedata_actor_class" SET
    "classPath" = '/Chara/Npc/Populace/PopulaceStandard',
    "propertyFlags" = 1,
    "eventConditions" = '{
  "pushWithCircleEventConditions": [
    {
      "isEnabled": "false",
      "radius": "3.0",
      "outwards": "false",
      "silent": "false",
      "conditionName": "pushDefault"
    }
  ]
}'
WHERE "id" IN (1090358, 1090359, 1090360, 1090361, 1090362) AND ("classPath" = '' OR "classPath" IS NULL);

INSERT OR IGNORE INTO "server_spawn_locations"
    ("id", "actorClassId", "uniqueId", "zoneId", "privateAreaName", "privateAreaLevel",
     "positionX", "positionY", "positionZ", "rotation", "actorState", "animationId", "customDisplayName")
VALUES
    (27881, 1090358, 'man304_burial_wall_north', 190, '', 0,  795.10, 54.90, -218.40, 0.00, 0, 0, null),
    (27882, 1090359, 'man304_burial_wall_east',  190, '', 0,  862.70, 44.40, -298.20, 0.00, 0, 0, null),
    (27883, 1090360, 'man304_burial_pond_east',  190, '', 0,  752.90, 31.20, -373.20, 0.00, 0, 0, null),
    (27884, 1090361, 'man304_burial_pond_west',  190, '', 0,  722.00, 31.00, -381.20, 0.00, 0, 0, null),
    (27885, 1090362, 'man304_burial_pond_north', 190, '', 0,  745.00, 33.80, -307.20, 0.00, 0, 0, null);
