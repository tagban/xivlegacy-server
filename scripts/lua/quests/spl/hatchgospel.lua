require ("global")
require ("quest")
require ("quests/spl/hatchingtide")

--[[

The Dreamer's Gospel, shared by Spl0u1 (Ul'dah), Spl0g1 (Gridania) and
Spl0l1 (Limsa Lominsa); each quest script names its city and calls these.
See quests/spl/hatchingtide.lua for the story and the numbers.

The client's events (the same in all three): processEventGirlStart (the
offer), processEvent000 (no egg yet) and processEvent000_over10 (another
egg), processEvent010/_2 (the helper explains), processEvent020 (the trade),
beforeGirl/beforeBoy/beforeSp1/beforeSp2/afterBoy/isCapMes (chatter).

]]

GOSPEL_SEQ_000		= 0;	-- Gather the eggs and trade them to the helper.
GOSPEL_FLAG_HELPER	= 0;	-- the helper has explained the eggs
GOSPEL_COUNTER_EGG	= 0;	-- minute stamp of the Dreamer's last egg

local H = HATCHINGTIDE;

function gospelStart(player, quest)
	quest:StartSequence(GOSPEL_SEQ_000);
end

function gospelStateChange(city, player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(city.dreamer, QFLAG_TALK);
		return;
	end
	quest:SetENpc(city.dreamer);
	quest:SetENpc(city.helper, QFLAG_REWARD);
	quest:SetENpc(city.hint);
end

function gospelTalk(city, player, quest, npc)
	local classId = npc:GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT) then
		if (classId == city.dreamer) then
			if (hatchFinishedGospel(player)) then
				-- one Gospel per adventurer (quest_offers.rs keeps the others back)
				callClientFunction(player, "delegateEvent", player, quest, "beforeGirl");
			elseif (IsSeasonalQuestOpen(quest:GetQuestId())
				and callClientFunction(player, "delegateEvent", player, quest, "processEventGirlStart") == 1) then
				player:AcceptQuest(quest);
				hatchGiveEgg(player, {H.ARCHON_EGG});
				hatchStampEgg(quest, GOSPEL_COUNTER_EGG);
			end
		end
		player:EndEvent();
		return;
	end

	if (classId == city.dreamer) then
		if (hatchEggReady(quest, GOSPEL_COUNTER_EGG)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_over10");
			hatchGiveEgg(player, {H.ARCHON_EGG, H.FIRE_EGG, H.ICE_EGG, H.WIND_EGG, H.EARTH_EGG, H.LIGHTNING_EGG, H.WATER_EGG});
			hatchStampEgg(quest, GOSPEL_COUNTER_EGG);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		end
	elseif (classId == city.helper) then
		if (hatchHasEggs(player, H.GOSPEL_EGGS)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			hatchTakeEggs(player, H.GOSPEL_EGGS);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(H.PRISTINE_CAP, 1, 1);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		elseif (not quest:GetData():GetFlag(GOSPEL_FLAG_HELPER)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			quest:GetData():SetFlag(GOSPEL_FLAG_HELPER);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		end
	elseif (classId == city.hint) then
		callClientFunction(player, "delegateEvent", player, quest, "beforeSp2");
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function gospelKill(player, quest, bnpc)
	hatchOnKill(player, bnpc, false);
end

-- The client's recipe lines count the eggs from these: one Archon egg and
-- one each of the three aspected eggs.
function gospelJournal(player, quest)
	return 1, 1, 0, 0, 0;
end
