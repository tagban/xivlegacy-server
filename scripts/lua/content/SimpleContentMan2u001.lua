require ("global")
require ("allyfight")
require ("quests/man/man2u0")

--[[

Calamity Cometh: the minemites Corguevais calls up with his horn, outside
Ul'dah's north wall (director QuestDirectorMan2u001). From Gamer Escape's
walkthrough and journal: you fight beside Niellefresne and his companion,
the minemites come one or two at a time, and the duty fails if your allies
are defeated. Their count and level aren't recorded: six minemites in four
waves at level 14 are ours.

]]

function onCreate(player, contentArea, director)
	allyFight.create(MAN2U0_FIGHT, player, contentArea, director);
end

function onZoneIn(player, contentArea, director)
	player:ChangeMusic(37); -- the 1.x duty theme
end

function onUpdate(tick, area)
	allyFight.update(MAN2U0_FIGHT, tick, area, loseMan2u0Fight);
end

function onAbort(player, contentArea, director)
	allyFight.abort(player);
end

function onDestroy()
end
