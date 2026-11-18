require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name:	The Call of Nature
Code:	Cnj306
Id:	110262
Prereq: Level 36, Conjurer, Cnj300

Soileine asks whether you would test your potential: to hear the elementals
yourself (processEventSoileineStart, 1 = accepted). Brother Ingram teaches
you how to listen and gives you a leather bag (cnj30610, key item 11000101).
At Amberscale Rock Brother Morys appears, drawn by a voice, and asks you to
see him to Ishgard (cnj30620, processEvent025: 1 = you agree). At Camp
Emerald Moss you set out with him, but at the forest's edge a voice calls
and he vanishes (cnj30630). Back at Amberscale Rock you find him fallen
among three elementals (cnj30640); with the Echo (processEvent045) you see
his past: dreadwolves running for the cave (cnj30650), closing in on a small
boy (cnj30660, the fight: content Cnj30602, three dreadwolves), and the boy
taken by the wood (cnj30670). Ingram swears you to secrecy about Morys
(cnj30680), and Soileine pays you (cnj30690): 36,000 gil and 3,600
experience, like the other level-36 class quests (the client's reward table
has no row for this quest).

Morys has no class path in 1.23b, so he appears only in cutscenes: each
meeting is a push circle where its scene starts. Amberscale Rock is Cnj300's
circle (1090651) in the same cave chamber, and the fight uses that chamber.
Brother Ingram's only spawn was man0g1's Echo copy, so he gets one at
Stillglade Fane beside Soileine. The client's QuestDirectorCnj30601 and
Cnj30602 are both empty classes; the escort to the forest's edge plays as
its cutscene, and the fight in the Echo is ours under Cnj30602 (journal:
save the youth from the dreadwolves).

Places (estimates): Ingram beside Soileine and Hetzkin; Camp Emerald Moss
beside Miraudont (ground y 20.5 from the client's ground mesh). The journal
markers (11026201-09) are unprobed.

Guild chatter: Soileine, Hetzkin and Ingram have their lines per step; the
other speakers of 005_4-12, 010_4 and 070_3-10 have no spawn.

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Speak with Brother Ingram.
SEQ_010	= 10;  -- Listen for the elementals at Amberscale Rock.
SEQ_020	= 20;  -- Meet Brother Morys at Camp Emerald Moss.
SEQ_030	= 30;  -- Search for Morys after he vanishes.
SEQ_040	= 40;  -- Use the Echo on Morys.
SEQ_050	= 50;  -- Follow the dreadwolves into the cave (the fight).
SEQ_055	= 55;  -- After the fight: the boy taken by the wood.
SEQ_060	= 60;  -- Tell Brother Ingram what you learned.
SEQ_070	= 70;  -- Soileine has your reward.

-- Actor Class Ids
ENPC_SOILEINE		= 1000234;
ENPC_HETZKIN		= 1000460;
ENPC_INGRAM			= 1000372;
ENPC_AMBERSCALE		= 1090651; -- Cnj300's circle in the Amberscale Rock cave
ENPC_EMERALD_MOSS	= 1090658;

ITEM_LEATHER_BAG	= 11000101; -- Mysterious Leather Bag

-- Quest Markers (in journal order; unprobed)
MRKR_INGRAM_1		= 11026201;
MRKR_AMBERSCALE_1	= 11026202;
MRKR_EMERALD_MOSS	= 11026203;
MRKR_AMBERSCALE_2	= 11026204;
MRKR_MORYS			= 11026205;
MRKR_CAVE			= 11026206;
MRKR_INGRAM_2		= 11026208;
MRKR_SOILEINE		= 11026209;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- The fight in the cave chamber, and where a win, a loss or an after-warp
-- scene sets you down: 8 yalms south of the Amberscale circle, so stepping
-- back in plays the next scene (or retries the fight).
FIGHT		= {150, -584.0, -24.88, -448.0, 3.14};
CAVE_OUT	= {150, -584.0, -24.5, -456.0, 3.14};
FANE_AFTER	= {206, -356.5, 6.25, -1704.0, -2.37};

TALKS_SOILEINE = {
	[SEQ_000] = "processEvent005_2",
	[SEQ_010] = "processEvent010_3",
	[SEQ_020] = "processEvent010_3",
	[SEQ_030] = "processEvent030_2",
	[SEQ_040] = "processEvent030_2",
	[SEQ_050] = "processEvent030_2",
	[SEQ_055] = "processEvent030_2",
	[SEQ_060] = "processEvent070_5",
};

TALKS_HETZKIN = {
	[SEQ_000] = "processEvent005_3",
	[SEQ_010] = "processEvent005_3",
	[SEQ_020] = "processEvent005_3",
	[SEQ_030] = "processEvent070_2",
	[SEQ_040] = "processEvent070_2",
	[SEQ_050] = "processEvent070_2",
	[SEQ_055] = "processEvent070_2",
	[SEQ_060] = "processEvent070_2",
	[SEQ_070] = "processEvent070_2",
};

TALKS_INGRAM = {
	[SEQ_010] = "processEvent010_2",
	[SEQ_020] = "processEvent010_2",
	[SEQ_030] = "processEvent030_3",
	[SEQ_040] = "processEvent030_3",
	[SEQ_050] = "processEvent030_3",
	[SEQ_055] = "processEvent030_3",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
		return;
	end
	quest:SetENpc(ENPC_HETZKIN);
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_INGRAM, QFLAG_TALK);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_010 or sequence == SEQ_030
			or sequence == SEQ_040 or sequence == SEQ_050 or sequence == SEQ_055) then
		-- Stays open in SEQ_010 and SEQ_040 (turning Morys or the Echo down
		-- leaves him waiting) and in SEQ_050 (a lost fight is retried here).
		quest:SetENpc(ENPC_AMBERSCALE, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_INGRAM);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_EMERALD_MOSS, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_INGRAM);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_INGRAM, QFLAG_TALK);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_REWARD);
		quest:SetENpc(ENPC_INGRAM);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_SOILEINE) then
		-- Test your potential: hear the elementals yourself (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSoileineStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_INGRAM and seq == SEQ_000) then
		-- cnj30610: how to listen, and the leather bag.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_LEATHER_BAG, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif (npcClassId == ENPC_INGRAM and seq == SEQ_060) then
		-- cnj30680: Morys was a wildling; keep the secret.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
		quest:StartSequence(SEQ_070);
	elseif (npcClassId == ENPC_SOILEINE and seq == SEQ_070) then
		-- cnj30690: you have heard the elementals, and your pay.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent095");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_LEATHER_BAG, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (npcClassId == ENPC_SOILEINE and TALKS_SOILEINE[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_SOILEINE[seq]);
	elseif (npcClassId == ENPC_HETZKIN and TALKS_HETZKIN[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_HETZKIN[seq]);
	elseif (npcClassId == ENPC_INGRAM and TALKS_INGRAM[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_INGRAM[seq]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_010 and npcClassId == ENPC_AMBERSCALE) then
		-- cnj30620: Morys, drawn by a voice; then his request (1 = you will
		-- see him to Ishgard).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		local agreed = callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		if (agreed == 1) then
			quest:StartSequence(SEQ_020);
		end
	elseif (seq == SEQ_040 and npcClassId == ENPC_AMBERSCALE) then
		-- The Echo on Morys (1 = look); then cnj30650, the dreadwolves on
		-- the path (after-warp).
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent045");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			quest:StartSequence(SEQ_050);
			player:EndEvent();
			warpTo(player, CAVE_OUT);
			return;
		end
	elseif (seq == SEQ_030 and npcClassId == ENPC_AMBERSCALE) then
		-- cnj30640: Morys fallen among three elementals (after-warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		warpTo(player, CAVE_OUT);
		return;
	elseif (seq == SEQ_050 and npcClassId == ENPC_AMBERSCALE) then
		-- cnj30660: the dreadwolves close in on the boy (after-warp: the
		-- move into the fight lifts it), then the fight.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		questBattle.start(player, "Cnj30602", FIGHT, "Quest/QuestDirectorCnj30602");
		return;
	elseif (seq == SEQ_055 and npcClassId == ENPC_AMBERSCALE) then
		-- cnj30670: the boy was Morys, taken by the wood (after-warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		quest:StartSequence(SEQ_060);
		player:EndEvent();
		warpTo(player, CAVE_OUT);
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_EMERALD_MOSS) then
		-- cnj30630: setting out with Morys; at the forest's edge he vanishes.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

-- QuestDirectorCnj30602, once the dreadwolves are down.
function winCnj306Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_055);
	player:EndEvent();
	questBattle.leave(player, CAVE_OUT);
end

-- SimpleContentCnj30602, on a loss.
function loseCnj306Fight(player, timedOut)
	questBattle.leave(player, CAVE_OUT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_000) then
		return MRKR_INGRAM_1;
	elseif (seq == SEQ_010) then
		return MRKR_AMBERSCALE_1;
	elseif (seq == SEQ_020) then
		return MRKR_EMERALD_MOSS;
	elseif (seq == SEQ_030) then
		return MRKR_AMBERSCALE_2;
	elseif (seq == SEQ_040) then
		return MRKR_MORYS;
	elseif (seq == SEQ_050 or seq == SEQ_055) then
		return MRKR_CAVE;
	elseif (seq == SEQ_060) then
		return MRKR_INGRAM_2;
	elseif (seq == SEQ_070) then
		return MRKR_SOILEINE;
	end
end
