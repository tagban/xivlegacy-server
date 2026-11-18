require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Into the Dark
Code: 	Com5l1
Id: 	111411
Prereq: A sworn member of the Maelstrom (company_gate in quest_offers.rs).

Garleans of the XIVth Legion keep turning up wherever the aether runs
thick, and the Maelstrom wants to know why they hold Dzemael Darkhold.
Guincum sends you to Hasthwab, a Barracuda operative posing as one of the
Bloody Executioners on the Astalicia. He names his contact in the Faces of
Mercy, mercenaries with friends in every house of Ishgard: Quiliane, at
Owl's Nest. She gives you the Faces' medallion to show the House Dzemael
guard (Dyrstweitz, one of theirs) and asks a magitek dowsing rod from the
imperials' device in the Darkhold's farthest reaches. The device takes you
back out with it. Quiliane keeps the rod, which the Empire uses to find
crystals, and Guincum hears that they are hunting aether to summon a primal.

The client script (com5l1) names the events. Seed 139 places the guard;
seed 141 Quiliane; the dungeon content script spawns the magitek terminal
(Com5u1). Hasthwab already stands on the Astalicia.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Speak with Hasthwab on the Astalicia.
SEQ_005	= 5;	-- Travel to Owl's Nest and find Quiliane.
SEQ_010	= 10;	-- Travel to Dzemael Darkhold.
SEQ_015	= 15;	-- Find the magitek dowsing rod in the Darkhold.
SEQ_020	= 20;	-- Report to Quiliane at Owl's Nest.
SEQ_030	= 30;	-- Report to Guincum.

-- Quest Actors
GUINCUM					= 1500199;
HASTHWAB				= 1001064;
QUILIANE				= 1001635;
DYRSTWEITZ				= 1001154;	-- the House Dzemael guard at the entrance
TERMINAL				= 1002062;	-- the magitek terminal in the farthest chamber

-- Key items
MEDALLION				= 11000269;	-- Faces of Mercy Medallion
DOWSING_ROD				= 11000270;	-- Magitek Dowsing Rod

-- Entry to the Darkhold, as in Com5u1: only the level and the discipline
-- are checked (no party state for scripts yet).
ENTRY_LEVEL				= 45;
PARTY_MIN				= 2;
PARTY_MAX				= 4;
TIME_LIMIT				= 60;		-- minutes, as the guard tells it

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 4000;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(HASTHWAB, QFLAG_TALK);
		quest:SetENpc(GUINCUM);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(QUILIANE, QFLAG_TALK);
		quest:SetENpc(HASTHWAB);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(DYRSTWEITZ, QFLAG_TALK);
		quest:SetENpc(QUILIANE);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(DYRSTWEITZ, QFLAG_TALK);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
		quest:SetENpc(QUILIANE);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(QUILIANE, QFLAG_REWARD);
		quest:SetENpc(DYRSTWEITZ);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(GUINCUM, QFLAG_REWARD);
		quest:SetENpc(QUILIANE);
		quest:SetENpc(DYRSTWEITZ);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
	end
end

-- Only Disciples of War or Magic at the entry level go in.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == GUINCUM) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGUINCUMStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence < SEQ_030 and classId == GUINCUM) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == HASTHWAB) then
		-- the Executioner act, and his contact in the Faces of Mercy
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		quest:StartSequence(SEQ_005);
	elseif (sequence > SEQ_000 and classId == HASTHWAB) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (sequence == SEQ_005 and classId == QUILIANE) then
		-- the Faces' three rules, the medallion, and the rod she wants
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", PARTY_MIN, PARTY_MAX, ENTRY_LEVEL);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(MEDALLION, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == DYRSTWEITZ) then
		-- the medallion, the void's rift, and the Darkhold's rules
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030", TIME_LIMIT, 0, 0);
		quest:StartSequence(SEQ_015);
	elseif (sequence == SEQ_015 and classId == DYRSTWEITZ) then
		local enter = callClientFunction(player, "delegateEvent", player, quest, "processEvent_030_1");
		if (enter == 1) then
			if (mayEnter(player)) then
				player:EndEvent();
				enterDungeon(player, "dzemael");
				return;
			end
		end
	elseif (sequence >= SEQ_020 and classId == DYRSTWEITZ) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030_2");
	elseif (classId == TERMINAL and player:GetZoneID() == DUNGEONS.dzemael.zone) then
		-- the imperials' device: the rod comes off it, and it takes you out
		if (sequence == SEQ_015) then
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(DOWSING_ROD, 1, 1);
			quest:StartSequence(SEQ_020);
		end
		player:EndEvent();
		leaveDungeon(player);
		return;
	elseif (sequence == SEQ_020 and classId == QUILIANE) then
		-- the rod, and what the Empire wants with crystals
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(DOWSING_ROD, 1);
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == GUINCUM) then
		-- a primal, and the Maelstrom's next move
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(MEDALLION, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
