require ("global")
require ("modifiers")
require ("dungeon")

-- Good King Moggle Mog XII in Thornmarch, for Louisoix's A Feast of Fools
-- (Sum6m0; content SimpleContentThornmarch). The client's director is an
-- empty InstanceRaidBaseClass: startEvent opens the battle timer, and there
-- is no cut scene. Once the court falls, the quest goes to Pukwa Pika and you
-- are back before him, south of Turning Leaf.

A_FEAST_OF_FOOLS	= 110816;

CONTENT_ID		= 5;		-- Thornmarch in the client's raid list (timer widget)
TIME_LIMIT		= 30;		-- minutes, as Pukwa Pika tells it

function init()
	return "/Director/InstanceRaid/InstanceRaidDarkMoogle";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 0);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	-- GetQuest hands back a quest for any id, held or not
	if player:HasQuest(A_FEAST_OF_FOOLS) then
		player:GetQuest(A_FEAST_OF_FOOLS):StartSequence(20);	-- SEQ_020 in quests/sum/sum6m0.lua
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player, "thornmarch");
end

function main()
end
