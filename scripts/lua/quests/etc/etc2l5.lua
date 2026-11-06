require ("global")
require ("quest")

--[[

Quest Script

Name: 	Carving a Name
Code: 	Etc2l5
Id: 	110648
Prereq: Level 47, any class

Sizha Epocan, a sculptor in Wineport, needs a rare stone for a prestigious
commission: the yellow marble the kobolds of upper La Noscea dig up. It is
under lock and key, so you "interrogate" the kobold cragsmen at their
encampment until one gives up the key to a brass strongbox (key item
11000227), open the strongbox there for the marble (11000206) and bring it
back. Reward: a Turquoise, from the client's reward table
(data/01/03/05/61.DAT). The table gives the experience only as a rank, so
that amount is an estimate.

Sizha had no spawn or class script; she stands in Wineport by I'nairoh.
The client script has no event for the strongbox, so it is an invisible
spot at the camp's upper end that opens with the key (its place is an
estimate), and the cragsmen are an open-world group by the encampment.

Client script etc2l5: processEventStart (offer), processEventStartAfter
(Sizha while you search), processEventClear (the reward). Journal steps
376-379.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Take the strongbox key from the kobolds.
SEQ_005	= 5;	-- Open the strongbox for the marble.
SEQ_010	= 10;	-- Bring the marble to Sizha Epocan in Wineport.

-- Actor Class Ids
ENPC_SIZHA			= 1001805;
STRONGBOX_TRIGGER	= 1090614;
BNPC_CRAGSMAN		= 2206606;

-- Key Items
ITEM_KEY			= 11000227;
ITEM_MARBLE			= 11000206;

-- Quest Markers
MRKR_ENCAMPMENT		= 11064801;
MRKR_STRONGBOX		= 11064802;
MRKR_SIZHA			= 11064803;

-- Rewards
REWARD_EXP			= 3500;
REWARD_TURQUOISE	= 10004114;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SIZHA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_SIZHA);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_SIZHA);
		quest:SetENpc(STRONGBOX_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_SIZHA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (classId == ENPC_SIZHA) then
		if (seq == SEQ_ACCEPT) then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
			if (accepted == 1) then
				player:AcceptQuest(quest);
			end
			player:EndEvent();
			return;
		elseif (seq == SEQ_000 or seq == SEQ_005) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
		elseif (seq == SEQ_010) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
			player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_MARBLE, 1);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_TURQUOISE, 1, 1);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_005 and npc:GetActorClassId() == STRONGBOX_TRIGGER) then
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_KEY, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_MARBLE, 1, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		return;
	end
	player:EndEvent();
end

-- A cragsman gives up the key.
function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() == SEQ_000 and bnpc == BNPC_CRAGSMAN) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_KEY, 1, 1);
		quest:StartSequence(SEQ_005);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_ENCAMPMENT;
	elseif (seq == SEQ_005) then
		return MRKR_STRONGBOX;
	elseif (seq == SEQ_010) then
		return MRKR_SIZHA;
	end
end
