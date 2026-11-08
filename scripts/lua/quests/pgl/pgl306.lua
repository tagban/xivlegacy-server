require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name:	Two Sides to Every Chip
Code:	Pgl306
Id:	110062
Prereq: Level 36, Pugilist, Pgl300

Titinin, furious that another collector came back empty-handed, asks you
to collect Lady Lewena's payment once more (pgl30610, 1 = accepted). At the
Mirage entrance Hurrey and Lewena's handmaiden are worried for her
(pgl30620); the Echo on Hurrey shows him escorting her to a plateau by the
Silver Bazaar (processEvent030, pgl30630). The handmaiden's Echo
(processEvent040, pgl30640) is optional. On the plateau Lewena watches her
pugilists fight a thaumaturge of Arrzaneth Ossuary (pgl30650), who turns on
you (content Pgl30601: the thaumaturge and her doppelganger). After the
fight Lewena buys off the order of condemnation and owns up to minting the
counterfeit chips (pgl30660). Titinin hears your report (pgl30670), and
Gagaruna pays you (pgl30680, processEvent090): 36,000 gil and 3,600
experience, like the other level-36 class quests (the client's reward table
has no row for this quest).

Hurrey, Lady Lewena and her handmaiden have no class path in 1.23b, so
their meetings are push circles. The client's QuestDirectorPgl30601 is an
empty class, so the fight is ours (journal: defeat the thaumaturge; a loss
lets you challenge her again). The thaumaturge uses the caster class of
Arc300's thunder mage (2180131, thaumaturge spells).

Places: the Mirage entrance at the top of its stairs, with Hurrey and the
handmaiden on the floor below it; the plateau east of the Silver Bazaar,
whose circle sits at its foot (the top is a ledge you can't walk onto from
the south). Walked in the client. The journal markers (11006201-07) are
unprobed.

]]

-- Sequence Numbers
SEQ_010	= 10;  -- Look for Lady Lewena near the Mirage's main entrance.
SEQ_020	= 20;  -- Use the Echo to learn where she went.
SEQ_030	= 30;  -- Find her on a plateau by the Silver Bazaar (the fight).
SEQ_035	= 35;  -- After the fight: Lady Lewena and the thaumaturge.
SEQ_060	= 60;  -- Report to Titinin.
SEQ_070	= 70;  -- Gagaruna has your reward.

-- Actor Class Ids
ENPC_GAGARUNA		= 1000862;
ENPC_TITININ		= 1000934;
ENPC_ENTRANCE		= 1090654; -- push circles where the cutscene-only meetings start
ENPC_HURREY			= 1090655;
ENPC_HANDMAIDEN		= 1090656;
ENPC_PLATEAU		= 1090657;

-- Quest Markers (in journal order; unprobed)
MRKR_ENTRANCE		= 11006201;
MRKR_HURREY			= 11006202;
MRKR_PLATEAU		= 11006203;
MRKR_TITININ		= 11006205;
MRKR_GAGARUNA		= 11006206;

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- The fight, in the hollow at the plateau's foot (the top is a ledge the
-- client can't stand on; heights from tools/terrain), and where a win or a
-- loss sets you down: south of the plateau circle, so stepping back in
-- plays the next scene (or retries the fight).
FIGHT		= {172, -1172.0, 117.4, 504.0, 3.14};
FIGHT_OUT	= {172, -1170.0, 117.06, 500.0, 3.14};
-- Where the after-warp scenes set you down.
ENTRANCE_AFTER	= {175, -151.0, 185.65, 126.0, 3.14};
PLATEAU_AFTER	= {172, -1170.0, 117.06, 500.0, 3.14}; -- the plateau's foot, as FIGHT_OUT
MIRAGE_AFTER	= {175, -172.0, 190.0, 113.0, 0.0};

TALKS_GAGARUNA = {
	[SEQ_010] = "processEvent010_2",
	[SEQ_020] = "processEvent010_2",
	[SEQ_030] = "processEvent010_2",
	[SEQ_035] = "processEvent010_2",
	[SEQ_060] = "processEvent070_2",
};

TALKS_TITININ = {
	[SEQ_010] = "processEvent010_9",
	[SEQ_020] = "processEvent010_9",
	[SEQ_030] = "processEvent010_9",
	[SEQ_035] = "processEvent010_9",
};

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_TALK);
		return;
	end
	if (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ENTRANCE, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_TITININ);
	elseif (sequence == SEQ_020) then
		-- Stays open: turning the Echo down leaves them waiting.
		quest:SetENpc(ENPC_HURREY, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_HANDMAIDEN, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_TITININ);
	elseif (sequence == SEQ_030 or sequence == SEQ_035) then
		-- Stays open in SEQ_030: a lost or abandoned fight is retried here.
		quest:SetENpc(ENPC_PLATEAU, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_TITININ);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(ENPC_TITININ, QFLAG_TALK);
		quest:SetENpc(ENPC_GAGARUNA);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_REWARD);
		quest:SetENpc(ENPC_TITININ);
	end
end

local function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], nil, 0, 15, spot[2], spot[3], spot[4], spot[5]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_GAGARUNA) then
		-- pgl30610: Titinin's collector failed; collect from Lady Lewena (1 = accepted).
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGagarunaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (npcClassId == ENPC_TITININ and seq == SEQ_060) then
		-- pgl30670: the report, and the Ossuary's "investigation" (after-warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		quest:StartSequence(SEQ_070);
		player:EndEvent();
		warpTo(player, MIRAGE_AFTER);
		return;
	elseif (npcClassId == ENPC_GAGARUNA and seq == SEQ_070) then
		-- pgl30680 and Gagaruna's tribute from the Mirage.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent090");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (npcClassId == ENPC_GAGARUNA and TALKS_GAGARUNA[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_GAGARUNA[seq]);
	elseif (npcClassId == ENPC_TITININ and TALKS_TITININ[seq] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS_TITININ[seq]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_010 and npcClassId == ENPC_ENTRANCE) then
		-- pgl30620: Hurrey and the handmaiden at the entrance (after-warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
		player:EndEvent();
		warpTo(player, ENTRANCE_AFTER);
		return;
	elseif (seq == SEQ_020 and npcClassId == ENPC_HURREY) then
		-- The Echo on Hurrey (pgl30630): the plateau by the Silver Bazaar.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		if (echo == 1) then
			quest:StartSequence(SEQ_030);
		end
	elseif (seq == SEQ_020 and npcClassId == ENPC_HANDMAIDEN) then
		-- The handmaiden's Echo (pgl30640): Lewena's boredom. Optional.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
	elseif (seq == SEQ_030 and npcClassId == ENPC_PLATEAU) then
		-- pgl30650: Lady Lewena and the thaumaturge (after-warp: the move
		-- into the fight lifts it), then the fight.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
		questBattle.start(player, "Pgl30601", FIGHT, "Quest/QuestDirectorPgl30601");
		return;
	elseif (seq == SEQ_035 and npcClassId == ENPC_PLATEAU) then
		-- pgl30660: the order of condemnation bought off (after-warp).
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:StartSequence(SEQ_060);
		player:EndEvent();
		warpTo(player, PLATEAU_AFTER);
		return;
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

-- QuestDirectorPgl30601, once the thaumaturge and her doppelganger are down.
function winPgl306Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_035);
	player:EndEvent();
	questBattle.leave(player, FIGHT_OUT);
end

-- SimpleContentPgl30601, on a loss.
function losePgl306Fight(player, timedOut)
	questBattle.leave(player, FIGHT_OUT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_010) then
		return MRKR_ENTRANCE;
	elseif (seq == SEQ_020) then
		return MRKR_HURREY;
	elseif (seq == SEQ_030 or seq == SEQ_035) then
		return MRKR_PLATEAU;
	elseif (seq == SEQ_060) then
		return MRKR_TITININ;
	elseif (seq == SEQ_070) then
		return MRKR_GAGARUNA;
	end
end
