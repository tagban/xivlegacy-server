require ("global")
require ("modifiers")
require ("dungeon")

-- Garuda in the Howling Eye (Hard), for Louisoix's Taming the Tempest
-- (Sum6g0; content SimpleContentHowlingEyeHard). The client's director is an
-- empty InstanceRaidBaseClass: startEvent opens the battle timer, and there
-- is no cut scene. Once Garuda falls, the quest goes to its report and you
-- are back in the beastman aetheryte's cave.

TAMING_THE_TEMPEST	= 110867;

CONTENT_ID		= 11;		-- the Howling Eye (Hard) in the client's raid list (timer widget)
TIME_LIMIT		= 30;		-- minutes

function init()
	return "/Director/InstanceRaid/InstanceRaidNormalGaruda";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 0);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	-- GetQuest hands back a quest for any id, held or not
	if player:HasQuest(TAMING_THE_TEMPEST) then
		player:GetQuest(TAMING_THE_TEMPEST):StartSequence(20);	-- SEQ_020 in quests/sum/sum6g0.lua
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player, "howling_hard");
end

function main()
end
