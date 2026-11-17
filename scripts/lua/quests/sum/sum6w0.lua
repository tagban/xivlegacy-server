require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	The Raven, Nevermore
Code: 	Sum6w0
Id: 	110870
Prereq: Level 45, Living on a Prayer (Etc304; the quests table's
		prerequisite column).

At the airship landing in Gridania, Serpent Private Hodder asks whether you
are ready to board the Enterprise and face Nael van Darnus once more.
Serpent Private Dauremant puts you aboard: Rivenroad (Hard), where Nael
falls again. Back in Gridania, Hodder admires the earring you bring.
Experience only.

Client text sheet 10560. The battle is the client's raid list entry 16,
"Rivenroad (Hard)", run by its InstanceRaidNormalWhiteGeneral director (the
GC fight is InstanceRaidLesserWhiteGeneral, entry 15). The boarding menu is
the client's processEventTrisselle (Dauremant's default talk is
defaultTalkWithTrisselle): 1 boards after a last warning, 2 reviews the
requirements, 3 or Escape leaves.

Our choices: the fight's numbers (Nael level 52, 40,000 HP, the GC Nael's
moves). No party size check, no re-entry timer, no repeat (the client's
processEventClearAfter, for a later visit, is not used).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Board the Enterprise and defeat Nael van Darnus.
SEQ_010	= 10;	-- Report to Hodder (set by the battle's director).

-- Quest Actors
HODDER					= 1002090;	-- Serpent Private Hodder, Gridania
DAUREMANT				= 1002091;	-- Serpent Private Dauremant, Gridania

ENTRY_LEVEL				= 45;
RAID_CONTENT			= 16;		-- Rivenroad (Hard) in the client's raid list
BOARD					= 1;		-- Dauremant's menu: board the Enterprise

-- Reward (the client's reward sheet row: EXP tier 6 in slot 1, nothing else)
REWARD_EXP				= 1322;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(HODDER, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(HODDER);
		quest:SetENpc(DAUREMANT, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(DAUREMANT);
		quest:SetENpc(HODDER, QFLAG_REWARD);
	end
end

local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == HODDER) then
		-- "Are you ready to board the Enterprise?"
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == DAUREMANT) then
		if (callClientFunction(player, "delegateEvent", player, quest, "processEventTrisselle", RAID_CONTENT) == BOARD
				and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "rivenroad_hard");
			return;
		end
	elseif (sequence == SEQ_010 and classId == HODDER) then
		-- welcome back, and a splendid earring
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
end

function getJournalMapMarkerList(player, quest)
end
