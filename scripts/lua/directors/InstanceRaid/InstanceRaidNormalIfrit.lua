require ("global")
require ("modifiers")
require ("dungeon")

-- Ifrit in the Bowl of Embers (Hard), for Louisoix's Ifrit Bleeds, We Can
-- Kill It (Sum6a0; content SimpleContentBowlOfEmbersHard). The client's
-- director is an empty InstanceRaidBaseClass: startEvent opens the battle
-- timer, and there is no cut scene. Once Ifrit falls, the quest goes to
-- its report and you are back in the beastman aetheryte's cave.

IFRIT_BLEEDS	= 110627;

CONTENT_ID		= 3;		-- the Bowl of Embers (Hard) in the client's raid list (timer widget)
TIME_LIMIT		= 30;		-- minutes, as the journal tells it

function init()
	return "/Director/InstanceRaid/InstanceRaidNormalIfrit";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 0);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	-- GetQuest hands back a quest for any id, held or not
	if player:HasQuest(IFRIT_BLEEDS) then
		player:GetQuest(IFRIT_BLEEDS):StartSequence(20);	-- SEQ_020 in quests/sum/sum6a0.lua
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player, "embers_hard");
end

function main()
end
