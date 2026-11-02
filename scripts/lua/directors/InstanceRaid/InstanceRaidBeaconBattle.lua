require ("global")
require ("modifiers")
require ("dungeon")

-- The Grand Companies' assault on Castrum Novum (United We Stand, Gc?106;
-- content SimpleContentCastrumNovum). The client's director has no scenes of
-- its own; startEvent opens the battle timer. Once the lunar transmitter and
-- its defenders fall you are back in Jagged Crest Cave.

UNITED_WE_STAND = { 111432, 111632, 111832 };

CONTENT_ID		= 13;		-- Castrum Novum in the client's raid list (timer widget)
TIME_LIMIT		= 60;		-- minutes

local function assaultQuest(player)
	for _, id in ipairs(UNITED_WE_STAND) do
		-- GetQuest hands back a quest for any id, held or not
		if player:HasQuest(id) then return player:GetQuest(id) end
	end
end

function init()
	return "/Director/InstanceRaid/InstanceRaidBeaconBattle";
end

function onEventStarted(player, actor, triggerName)
	local now = os.time();
	callClientFunction(player, "startEvent", "none", 0, 0, CONTENT_ID, now, now + TIME_LIMIT * 60, 0, 0);
	player:EndEvent();

	-- A battle that ends any other way purges this coroutine with the content.
	waitForSignal("battleComplete");
	wait(3);
	local quest = assaultQuest(player);
	if quest ~= nil then
		quest:StartSequence(20);	-- SEQ_020 in quests/gc/gc106.lua
	end
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	leaveDungeon(player);
end

function main()
end
