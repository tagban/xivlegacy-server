require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	What Glitters Always Isn't Gold
Code: 	Etc201
Id: 	110819
Prereq: Level 45, any class

Leleyo at Camp Dragonhead asks adventurers who fought in Dzemael Darkhold
to help the Holy See. Imperial soldiers have taken an Ishgardian
theologian into the Aurum Vale. Coultenet of House Dzemael waits by the
Vale and sends you after the imperial commander, the primus ordinarius.
Sir Tristechambel's magicks take you inside. After the kill you bring
Coultenet the theologian's book, found on the commander's body. The
reward is experience only. The client's reward row gives it as a rank,
the same as Etc200's, so the amount is an estimate.

The Vale is the server's dungeon copy (dungeon.lua). The client script
has no event for Tristechambel, so talking to him takes quest holders who
are Disciples of War or Magic at the quest's level inside. The primus
ordinarius is the copy's own (group 30010, in the storage cache past
the Coincounter's Chest). Coultenet and Tristechambel stand at Teriggan's
Stand, where the dungeon's exit sets you down; their exact spots are an
estimate.

Client script etc201: processEventLELEYOStart (offer), processEvent000
(Leleyo while you go), processEvent005 (Coultenet's briefing),
processEvent005_1 (Coultenet while you go), processEvent010 (the book).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Speak with Coultenet by the Aurum Vale.
SEQ_005	= 5;	-- Slay the primus ordinarius in the Vale.
SEQ_010	= 10;	-- Report to Coultenet.

-- Actor Class Ids
ENPC_LELEYO			= 1001641;
ENPC_COULTENET		= 1001904;
ENPC_TRISTECHAMBEL	= 1001955;
BNPC_PRIMUS			= 2307002;

-- Quest Markers
MRKR_COULTENET		= 11081901;
MRKR_AURUM_VALE		= 11081902;

-- Entry to the Aurum Vale, as Coultenet's briefing tells it.
ENTRY_LEVEL			= 45;

-- Rewards
REWARD_EXP			= 3500;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_LELEYO, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_LELEYO);
		quest:SetENpc(ENPC_COULTENET, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_COULTENET);
		quest:SetENpc(ENPC_TRISTECHAMBEL, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_COULTENET, QFLAG_REWARD);
	end
end

local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (classId == ENPC_LELEYO) then
		if (seq == SEQ_ACCEPT) then
			local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventLELEYOStart");
			if (accepted == 1) then
				player:AcceptQuest(quest);
			end
			player:EndEvent();
			return;
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
		end
	elseif (classId == ENPC_COULTENET) then
		if (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
			quest:StartSequence(SEQ_005);
		elseif (seq == SEQ_005) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_1");
		elseif (seq == SEQ_010) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	elseif (classId == ENPC_TRISTECHAMBEL) then
		if (seq == SEQ_005 and mayEnter(player)) then
			player:EndEvent();
			enterDungeon(player, "aurum");
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() == SEQ_005 and bnpc == BNPC_PRIMUS) then
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_005) then
		return MRKR_AURUM_VALE;
	else
		return MRKR_COULTENET;
	end
end
