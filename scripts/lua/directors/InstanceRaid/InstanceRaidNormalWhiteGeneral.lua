require ("global")
require ("modifiers")
require ("dungeon")

-- Nael van Darnus in Rivenroad (Hard), for The Raven, Nevermore
-- (Sum6w0; content SimpleContentRivenroadHard). The client's director is an
-- empty InstanceRaidBaseClass: startEvent opens the battle timer, and there
-- is no cut scene. Once Nael falls, the quest goes to its report and the
-- Enterprise sets you down in Gridania.

RAVEN_NEVERMORE		= 110870;

CONTENT_ID		= 16;		-- Rivenroad (Hard) in the client's raid list (timer widget)
TIME_LIMIT		= 30;		-- minutes

function init()
	return "/Director/InstanceRaid/InstanceRaidNormalWhiteGeneral";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 0);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	-- GetQuest hands back a quest for any id, held or not
	if player:HasQuest(RAVEN_NEVERMORE) then
		player:GetQuest(RAVEN_NEVERMORE):StartSequence(10);	-- SEQ_010 in quests/sum/sum6w0.lua
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player, "rivenroad_hard");
end

function main()
end
