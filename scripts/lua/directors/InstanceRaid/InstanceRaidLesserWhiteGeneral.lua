require ("global")
require ("modifiers")
require ("dungeon")

-- The Grand Companies' battle with Nael van Darnus on Rivenroad (To Kill a
-- Raven, Gc?107; content SimpleContentRivenroad). The client's director
-- plays the Enterprise's approach (gc010715) and opens the battle timer from
-- startEvent; van Darnus's welcome follows (GC010720). Once he falls, he
-- calls Dalamud's power down upon himself (GC010730) and the Enterprise
-- carries you off the crumbling isle (GC010740), back to the clearing
-- before the Lotus Stand.

TO_KILL_A_RAVEN = { 111433, 111633, 111833 };

CONTENT_ID		= 15;		-- Rivenroad in the client's raid list (timer widget)
TIME_LIMIT		= 60;		-- minutes

local function ravenQuest(player)
	for _, id in ipairs(TO_KILL_A_RAVEN) do
		-- GetQuest hands back a quest for any id, held or not
		if player:HasQuest(id) then return player:GetQuest(id) end
	end
end

function init()
	return "/Director/InstanceRaid/InstanceRaidLesserWhiteGeneral";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	-- startEvent plays gc010715 (its processStartEvent), then the scene it
	-- is named (GC010720), then fades back in. The owner after each name must
	-- be nil (the director) or an actor: a number crashes the client. So no
	-- trailing argument, which processStartEvent hands to gc010715 as owner.
	callClientFunction(player, "startEvent", "GC010720", nil, true, CONTENT_ID, now, now + TIME_LIMIT * 60, 0);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	local quest = ravenQuest(player);
	if quest ~= nil then
		quest:StartSequence(60);	-- SEQ_060 in quests/gc/gc107.lua
	end
	-- A fresh notice event to play them in; no owner (nil) has the director
	-- play them as its own.
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- exitCutScene fades out, plays, and fades back in only after the next
	-- warp, so only the last scene goes through it.
	callClientFunction(player, "executeCutScene", "GC010730", nil, false);
	callClientFunction(player, "exitCutScene", "GC010740", nil, true);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player);
end

function main()
end
