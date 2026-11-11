require ("global")
require ("allyfight")
require ("quests/man/man2g0")

--[[

Beckon of the Elementals: O-App-Pesi's battle against the Spirit of the
Wood in the East Shroud (director QuestDirectorMan2g001). From Gamer
Escape's walkthrough and the Spirit of the Wood's 1.x page: the spirit is
level 28 with 2,930 HP and 2,680 MP, aggressive; Grinnaux, Handeloup and
T'kebbe fight it beside you. A KO puts you back outside Quiver's Hold to
try again.

Not here yet (STUCK.md): the spirit's changing aspect, picking a ward from
O-App-Pesi to cast on the allies, and a fallen ally being replaced after a
while. Here the allies can't fall (a 1 HP floor) instead.

]]

function onCreate(player, contentArea, director)
	allyFight.create(MAN2G0_FIGHT, player, contentArea, director);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	allyFight.update(MAN2G0_FIGHT, tick, area, loseMan2g0Fight);
end

function onAbort(player, contentArea, director)
	allyFight.abort(player);
end

function onDestroy()
end
