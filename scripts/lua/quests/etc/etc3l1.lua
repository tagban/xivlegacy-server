require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Winds of Change
Code: 	Etc3l1
Id: 	110744
Prereq: Level 15, any class

Zanthael of the Knights of the Barracuda can't leave his post, so he asks
you to carry the Coral Tower's warrants for imperial operatives (key item
11000175) to five fellow knights: Bibiraka, Arthurioux, J'ghonako,
Sundhimal and Gert. When you report back, the operatives have been seen
going down into the caves west of Camp Bearded Rock; stepping into the
depression starts the fight (SimpleContentEtc3l101, the client's
SimpleQuestBattle QuestDirectorEtc3l101). You save a party from the Garlond
Ironworks (L'trimmna, Lowell and Kopel Yorpel), speak with them, then
report to Zanthael. Reward 7,500 gil, a Rope Belt and 500 experience
(the client's reward table, data/01/03/05/61.DAT).

The three engineers had no spawn or class script; they stand in the
depression after the fight (open world, visible to everyone).

Client script etc3l1: processEventZanthaelStart (offer), processEvent000
(Zanthael while you deliver), processEvent<Knight> / <Knight>01 (the
deliveries, and after), processEvent000_1 (Zanthael: the caves),
processEvent005 (Zanthael while you go), processEventLtrimmna,
processEventLowell, processEventKopelyorpel (the engineers),
processEvent010 (the reward). Journal steps 187-192.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Deliver the warrants to the five knights.
SEQ_001	= 1;	-- Report back to Zanthael.
SEQ_005	= 5;	-- Stop the operatives in the caves west of Camp Bearded Rock.
SEQ_007	= 7;	-- Speak with the party you saved.
SEQ_010	= 10;	-- Report back to Zanthael.

-- Actor Class Ids
ENPC_ZANTHAEL		= 1000351;
ENPC_BIBIRAKA		= 1001511;
ENPC_ARTHURIOUX		= 1000133;
ENPC_JGHONAKO		= 1000342;
ENPC_SUNDHIMAL		= 1000349;
ENPC_GERT			= 1500004;
ENPC_LTRIMMNA		= 1001575;
ENPC_LOWELL			= 1001576;
ENPC_KOPELYORPEL	= 1001577;
CAVE_TRIGGER		= 1090603;

-- Key Items
ITEM_WARRANTS		= 11000175;

-- The five knights: class id -> quest flag, delivery event, follow-up event, marker.
KNIGHTS = {
	[ENPC_BIBIRAKA]		= {0, "processEventBibiraka",	"processEventBibiraka01",	11074401},
	[ENPC_ARTHURIOUX]	= {1, "processEventArthurioux",	"processEventArthurioux01",	11074402},
	[ENPC_JGHONAKO]		= {2, "processEventJGhonako",	"processEventJGhonako01",	11074403},
	[ENPC_SUNDHIMAL]	= {3, "processEventSundhimal",	"processEventSundhimal01",	11074404},
	[ENPC_GERT]			= {4, "processEventGert",		"processEventGert01",		11074405},
};

KNIGHT_ORDER = {ENPC_BIBIRAKA, ENPC_ARTHURIOUX, ENPC_JGHONAKO, ENPC_SUNDHIMAL, ENPC_GERT};

-- Quest Markers
MRKR_ZANTHAEL		= 11074406;
MRKR_CAVES			= 11074407;
MRKR_ENGINEERS		= 11074408;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle, toward the camp).
FIGHT				= {128, -128.0, 24.5, -130.0, -1.57};

-- Rewards
REWARD_EXP			= 500;
REWARD_GIL			= 7500;
REWARD_BELT			= 8090402;

function onStart(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_WARRANTS, 1, 1);
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_ZANTHAEL, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_ZANTHAEL);
		for classId, k in pairs(KNIGHTS) do
			quest:SetENpc(classId, data:GetFlag(k[1]) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_001) then
		quest:SetENpc(ENPC_ZANTHAEL, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_ZANTHAEL);
		quest:SetENpc(CAVE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_007) then
		quest:SetENpc(ENPC_ZANTHAEL);
		quest:SetENpc(ENPC_LTRIMMNA);
		quest:SetENpc(ENPC_LOWELL);
		quest:SetENpc(ENPC_KOPELYORPEL, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ZANTHAEL, QFLAG_REWARD);
		quest:SetENpc(ENPC_LTRIMMNA);
		quest:SetENpc(ENPC_LOWELL);
		quest:SetENpc(ENPC_KOPELYORPEL);
	end
end

function allDelivered(data)
	for _, k in pairs(KNIGHTS) do
		if (not data:GetFlag(k[1])) then
			return false;
		end
	end
	return true;
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == ENPC_ZANTHAEL) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventZanthaelStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	local knight = KNIGHTS[classId];
	if (seq == SEQ_000 and knight ~= nil) then
		if (not data:GetFlag(knight[1])) then
			callClientFunction(player, "delegateEvent", player, quest, knight[2]);
			data:SetFlag(knight[1]);
			if (allDelivered(data)) then
				player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_WARRANTS, 1);
				attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
				player:EndEvent();
				quest:StartSequence(SEQ_001);
				return;
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, knight[3]);
		end
	elseif (knight ~= nil and seq ~= SEQ_ACCEPT) then
		callClientFunction(player, "delegateEvent", player, quest, knight[3]);
	elseif (classId == ENPC_ZANTHAEL) then
		if (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		elseif (seq == SEQ_001) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_1");
			player:EndEvent();
			quest:StartSequence(SEQ_005);
			return;
		elseif (seq == SEQ_005 or seq == SEQ_007) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		elseif (seq == SEQ_010) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_BELT, 1, 1);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	elseif (classId == ENPC_LTRIMMNA and (seq == SEQ_007 or seq == SEQ_010)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventLtrimmna");
	elseif (classId == ENPC_LOWELL and (seq == SEQ_007 or seq == SEQ_010)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventLowell");
	elseif (classId == ENPC_KOPELYORPEL and (seq == SEQ_007 or seq == SEQ_010)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventKopelyorpel");
		if (seq == SEQ_007) then
			player:EndEvent();
			quest:StartSequence(SEQ_010);
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_005 and npc:GetActorClassId() == CAVE_TRIGGER) then
		questBattle.start(player, "Etc3l101", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc3l101, once the operatives are down.
function winEtc3l1Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_007);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc3l101, on a loss.
function loseEtc3l1Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	local data = quest:GetData();
	local markers = {};
	if (seq == SEQ_000) then
		for _, classId in ipairs(KNIGHT_ORDER) do
			local k = KNIGHTS[classId];
			if (not data:GetFlag(k[1])) then
				table.insert(markers, k[4]);
			end
		end
	elseif (seq == SEQ_001 or seq == SEQ_010) then
		table.insert(markers, MRKR_ZANTHAEL);
	elseif (seq == SEQ_005) then
		table.insert(markers, MRKR_CAVES);
	elseif (seq == SEQ_007) then
		table.insert(markers, MRKR_ENGINEERS);
	end
	return unpack(markers);
end
