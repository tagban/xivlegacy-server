require ("global")
require ("quest")
require ("quests/spl/hatchingtide")

--[[

The Dreamer's Dilemma, shared by Spl0u2 (Ul'dah), Spl0g2 (Gridania) and
Spl0l2 (Limsa Lominsa); each quest script names its city and calls these.
See quests/spl/hatchingtide.lua for the story and the numbers.

The client's events (the same in all three, named for Gridania's cast):
eventJihliStart (the offer), eventJihliOffered, eventBricotOffered (the
helper explains the caps), eventBricotHint, eventBricotExchange (the cap
menu), eventDiggyHint (where the eggs are), eventTwiggyOffered/Hint/
Exchange/Resist (the thief), and the *Default chatter.

]]

DILEMMA_SEQ_000		= 0;	-- Find the eggs; trade them for caps.
DILEMMA_FLAG_HELPER	= 0;	-- the helper has explained the caps
DILEMMA_FLAG_THIEF	= 1;	-- the thief has been found
DILEMMA_FLAG_CAP	= 2;	-- flags 2-5: the helper's caps 1-4 traded

local H = HATCHINGTIDE;

function dilemmaStart(player, quest)
	quest:StartSequence(DILEMMA_SEQ_000);
end

function dilemmaStateChange(city, player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(city.dreamer, QFLAG_TALK);
		return;
	end
	quest:SetENpc(city.dreamer);
	quest:SetENpc(city.helper, QFLAG_REWARD);
	quest:SetENpc(city.hint);
	quest:SetENpc(city.thief, QFLAG_REWARD);
end

function dilemmaTalk(city, player, quest, npc)
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (classId == city.dreamer and IsSeasonalQuestOpen(quest:GetQuestId())
			and callClientFunction(player, "delegateEvent", player, quest, "eventJihliStart") == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	local traded = false;
	if (classId == city.dreamer) then
		callClientFunction(player, "delegateEvent", player, quest, "eventJihliOffered");
	elseif (classId == city.helper) then
		if (not data:GetFlag(DILEMMA_FLAG_HELPER)) then
			callClientFunction(player, "delegateEvent", player, quest, "eventBricotOffered");
			data:SetFlag(DILEMMA_FLAG_HELPER);
		elseif (hatchHasAnyFancy(player)) then
			local pick = hatchCapExchange(player, quest, function(i)
				return data:GetFlag(DILEMMA_FLAG_CAP + i - 1);
			end);
			if (pick ~= nil) then
				data:SetFlag(DILEMMA_FLAG_CAP + pick - 1);
				traded = true;
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, "eventBricotHint");
		end
	elseif (classId == city.hint) then
		hatchHint(player, quest);
	elseif (classId == city.thief) then
		traded = hatchThiefTalk(player, quest, not data:GetFlag(DILEMMA_FLAG_THIEF));
		data:SetFlag(DILEMMA_FLAG_THIEF);
	end

	if (traded) then
		-- the first cap finishes the quest; the rest trade on afterwards
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function dilemmaKill(player, quest, bnpc)
	hatchOnKill(player, bnpc, true);
end

-- The client's recipe lines count the eggs from these: one of each.
function dilemmaJournal(player, quest)
	return 1, 1, 1, 0, 0;
end
