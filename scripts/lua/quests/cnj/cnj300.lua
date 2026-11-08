require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name:	Good Knight, Sweet Dreams
Code:	Cnj300
Id:	110261
Prereq: Level 30, Conjurer, Cnj200

Soileine sends you to scout the Twelveswood with Brother Morys. At Lifemend
Stump Morys hears the wood calling and leaves (cnj30010); Soileine points
you to Amberscale Rock (processEvent010_2), where Morys stands among angry
elementals (processEvent015_1) and you must put them down (content
Cnj30001: two wind elementals and an earth elemental). In the cave you find
a fallen Ishgardian knight and call Soileine (cnj30020). Back at the Fane
she and Ingram send you after Morys, who is seeing the knight home to Owl's
Nest (cnj30030). Ser Yuhelmeric lets you question the knight (cnj30040);
with the Echo you see what he saw (processEvent050, cnj30050). At the
forest's edge Morys hears the knight's apology and says he must return
(cnj30060), and Soileine, relieved, pays you (cnj30070): 30,000 gil and
3,000 experience, like the other level-30 class quests (the client's reward
table has no row for this quest).

Morys and the knight (Newly outfitted knight, 1000573) have no class path in
1.23b, so they appear only in cutscenes: each meeting is a push circle where
its scene starts. The client's QuestDirectorCnj30001 is an empty class (only
QuestDirectorBaseClass), so the fight is ours: the journal (row 72) says the
elementals must be defeated.

Places (estimates, from a 2010 walkthrough's map grid and the client's ground
mesh): Lifemend Stump beside Lnc200's circle; Amberscale Rock in the cave
chamber under the hill south of it (Central Shroud, floor y -25); the knight
beside Yuhelmeric at Owl's Nest; the forest's edge by Arc300's Coerthas
border spot. The journal markers (11026101-08) are unprobed.

Guild chatter: Soileine and Hetzkin have their lines per step; the other
speakers of 005_4-11, 020_2-3, 030_4-8 and 040_2-6 have no spawn.

]]

-- Sequence Numbers
SEQ_005	= 5;   -- Meet Brother Morys at Lifemend Stump.
SEQ_010	= 10;  -- Ask Soileine where Morys went.
SEQ_015	= 15;  -- Find Morys near Amberscale Rock (the fight).
SEQ_017	= 17;  -- The fallen knight in the cave.
SEQ_020	= 20;  -- Return to Soileine.
SEQ_030	= 30;  -- Follow Morys to Owl's Nest: speak with Ser Yuhelmeric.
SEQ_040	= 40;  -- Question the knight.
SEQ_050	= 50;  -- Find Morys at the forest's edge.
SEQ_060	= 60;  -- Report to Soileine.

-- Actor Class Ids
ENPC_SOILEINE		= 1000234;
ENPC_HETZKIN		= 1000460;
ENPC_YUHELMERIC		= 1000370;
ENPC_LIFEMEND_STUMP	= 1090650; -- push circles where the cutscene-only meetings start
ENPC_AMBERSCALE		= 1090651;
ENPC_KNIGHT			= 1090652;
ENPC_FOREST_EDGE	= 1090653;

-- Quest Markers (in journal order; unprobed)
MRKR_LIFEMEND_STUMP	= 11026101;
MRKR_SOILEINE_1		= 11026102;
MRKR_AMBERSCALE		= 11026103;
MRKR_SOILEINE_2		= 11026104;
MRKR_YUHELMERIC		= 11026105;
MRKR_KNIGHT			= 11026106;
MRKR_FOREST_EDGE	= 11026107;
MRKR_SOILEINE_3		= 11026108;

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- The fight in the cave chamber, and where a win or a loss sets you down:
-- 8 yalms south of the Amberscale circle, so stepping back in plays the
-- next scene (or retries the fight).
FIGHT		= {150, -584.0, -24.88, -448.0, 3.14};
FIGHT_OUT	= {150, -584.0, -24.5, -456.0, 3.14};
-- Where the after-warp scenes set you down.
CAVE_AFTER	= {150, -584.0, -25.0, -444.0, 3.14};
OWL_AFTER	= {145, 2540.0, 174.3, 1312.0, 0.0};

TALKS_SOILEINE = {
	[SEQ_005] = "processEvent005_2",
	[SEQ_015] = "processEvent010_2",
	[SEQ_017] = "processEvent010_2",
	[SEQ_030] = "processEvent030_2",
	[SEQ_040] = "processEvent030_2",
	[SEQ_050] = "processEvent050_2",
};

TALKS_HETZKIN = {
	[SEQ_005] = "processEvent005_3",
	[SEQ_010] = "processEvent005_3",
	[SEQ_015] = "processEvent020_6",
	[SEQ_017] = "processEvent020_6",
	[SEQ_020] = "processEvent020_6",
	[SEQ_030] = "processEvent030_3",
	[SEQ_040] = "processEvent030_3",
	[SEQ_050] = "processEvent050_3",
	[SEQ_060] = "processEvent050_3",
};

TALKS_YUHELMERIC = {
	[SEQ_040] = "processEvent040_1",
	[SEQ_050] = "processEvent050_1",
	[SEQ_060] = "processEvent050_1",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_005);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
		return;
	end
	quest:SetENpc(ENPC_HETZKIN);
	if (sequence == SEQ_005) then
		quest:SetENpc(ENPC_LIFEMEND_STUMP, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
	elseif (sequence == SEQ_015 or sequence == SEQ_017) then
		-- Stays open in SEQ_015: a lost or abandoned fight is retried here.
		quest:SetENpc(ENPC_AMBERSCALE, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_YUHELMERIC, QFLAG_TALK);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_040) then
		-- Stays open: turning down the Echo leaves the knight waiting.
		quest:SetENpc(ENPC_KNIGHT, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_YUHELMERIC);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(ENPC_FOREST_EDGE, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_YUHELMERIC);
		quest:SetENpc(ENPC_SOILEINE);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_SOILEINE, QFLAG_REWARD);
		quest:SetENpc(ENPC_YUHELMERIC);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_SOILEINE) then
		-- Scout the Twelveswood with Brother Morys (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSoileineStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_SOILEINE and seq == SEQ_010) then
		-- Morys was called by the wood again: try Amberscale Rock.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		quest:StartSequence(SEQ_015);
	elseif (npcClassId == ENPC_SOILEINE and seq == SEQ_020) then
		-- cnj30030: the knight is from Ishgard; follow Morys to Owl's Nest.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		quest:StartSequence(SEQ_030);
	elseif (npcClassId == ENPC_SOILEINE and seq == SEQ_060) then
		-- cnj30070: Morys is safe, and your pay.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (npcClassId == ENPC_YUHELMERIC and seq == SEQ_030) then
		-- cnj30040: Ser Yuhelmeric and the knight's tale (after-warp fade).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		quest:StartSequence(SEQ_040);
		player:EndEvent();
		warpTo(player, OWL_AFTER);
		return;
	elseif (npcClassId == ENPC_SOILEINE and TALKS_SOILEINE[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_SOILEINE[seq]);
	elseif (npcClassId == ENPC_HETZKIN and TALKS_HETZKIN[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_HETZKIN[seq]);
	elseif (npcClassId == ENPC_YUHELMERIC and TALKS_YUHELMERIC[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_YUHELMERIC[seq]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_005 and npcClassId == ENPC_LIFEMEND_STUMP) then
		-- cnj30010: Morys hears the wood and leaves.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_015 and npcClassId == ENPC_AMBERSCALE) then
		-- Morys among the elementals ("Your sins. They must be purged."),
		-- then the fight.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015_1");
		questBattle.start(player, "Cnj30001", FIGHT, "Quest/QuestDirectorCnj30001");
		return;
	elseif (seq == SEQ_017 and npcClassId == ENPC_AMBERSCALE) then
		-- cnj30020: the fallen knight, and the call to Soileine (after-warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, CAVE_AFTER);
		return;
	elseif (seq == SEQ_040 and npcClassId == ENPC_KNIGHT) then
		-- The knight's dragon; 1 = look with the Echo (cnj30050).
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		if (echo == 1) then
			quest:StartSequence(SEQ_050);
		end
	elseif (seq == SEQ_050 and npcClassId == ENPC_FOREST_EDGE) then
		-- cnj30060: Morys hears the apology; he must return.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:StartSequence(SEQ_060);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

-- QuestDirectorCnj30001, once the elementals are down.
function winCnj300Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_017);
	player:EndEvent();
	questBattle.leave(player, FIGHT_OUT);
end

-- SimpleContentCnj30001, on a loss.
function loseCnj300Fight(player, timedOut)
	questBattle.leave(player, FIGHT_OUT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_005) then
		return MRKR_LIFEMEND_STUMP;
	elseif (seq == SEQ_010) then
		return MRKR_SOILEINE_1;
	elseif (seq == SEQ_015 or seq == SEQ_017) then
		return MRKR_AMBERSCALE;
	elseif (seq == SEQ_020) then
		return MRKR_SOILEINE_2;
	elseif (seq == SEQ_030) then
		return MRKR_YUHELMERIC;
	elseif (seq == SEQ_040) then
		return MRKR_KNIGHT;
	elseif (seq == SEQ_050) then
		return MRKR_FOREST_EDGE;
	elseif (seq == SEQ_060) then
		return MRKR_SOILEINE_3;
	end
end
