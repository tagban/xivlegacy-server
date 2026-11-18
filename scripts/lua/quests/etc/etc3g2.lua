require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Disorganized Crime
Code: 	Etc3g2
Id: 	110736
Prereq: Level 21, any class

Biddy at Stillglade Fane tells you someone has been stealing the broken
things Gridanians leave on Lifemend Stump for the moogles to mend.
Stepping up to the stump starts the fight (SimpleContentEtc3g201, the
client's SimpleQuestBattle QuestDirectorEtc3g201): three bandits of the
Redbelly Wasps waylay you. Their leader Colbert swears they never touched
the stump, but lets slip they snatched a girl, and hands over a map to
their den. There the bandits lie senseless around the Seedseer
Raya-O-Senna, who let herself be taken to hunt the stump's thieves. Answer
her and the Echo shows you her sister Kan-E (cutscene etc3g210). Report to
Biddy. Reward 10,000 gil (the client's reward table, data/01/03/05/61.DAT);
the table gives the experience only as a rank, so that amount is an
estimate.

Colbert, Bryce and C'kepaga stand at the stump after the fight, and
Raya-O-Senna at the den (open world, visible to everyone). The den's
place isn't recorded anywhere; it is a glade east of the stump.

Client script etc3g2: processEventBiddyStart (offer), processEvent_000_01
(Biddy while you go), processEvent_010 (Colbert's parley),
processEvent_010_01 / _010_02 (Bryce and C'kepaga), processEvent_010_3
(the bandits once the girl is found), processEvent_015 (Raya-O-Senna;
returns 1 when you answer her), processEvent_015_2 (asked again),
processEvent_020 (the Echo), processEvent_030 (the reward).
Journal steps 329-334.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Search Lifemend Stump for the thieves.
SEQ_005	= 5;	-- Question Colbert.
SEQ_010	= 10;	-- Find the girl at the bandits' den.
SEQ_015	= 15;	-- Report back to Biddy.

-- Actor Class Ids
ENPC_BIDDY			= 1000737;
ENPC_COLBERT		= 1001692;
ENPC_BRYCE			= 1001690;
ENPC_CKEPAGA		= 1001691;
ENPC_RAYA_O_SENNA	= 1001570;
STUMP_TRIGGER		= 1090609;

-- Quest flags
FLAG_ASKED			= 0;	-- Raya-O-Senna has asked once.

-- Quest Markers
MRKR_STUMP			= 11073601;
MRKR_COLBERT		= 11073602;
MRKR_DEN			= 11073603;
MRKR_BIDDY			= 11073604;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {150, -790.0, 20.6, -1044.0, 3.14};

-- Rewards
REWARD_EXP			= 1500;
REWARD_GIL			= 10000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_BIDDY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(STUMP_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_BIDDY);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_BIDDY);
		quest:SetENpc(ENPC_COLBERT, QFLAG_TALK);
		quest:SetENpc(ENPC_BRYCE);
		quest:SetENpc(ENPC_CKEPAGA);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_BIDDY);
		quest:SetENpc(ENPC_COLBERT);
		quest:SetENpc(ENPC_BRYCE);
		quest:SetENpc(ENPC_CKEPAGA);
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_BIDDY, QFLAG_REWARD);
		quest:SetENpc(ENPC_COLBERT);
		quest:SetENpc(ENPC_BRYCE);
		quest:SetENpc(ENPC_CKEPAGA);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == ENPC_BIDDY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventBiddyStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (classId == ENPC_BIDDY and seq ~= SEQ_015) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_01");
	elseif (classId == ENPC_BIDDY and seq == SEQ_015) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == ENPC_COLBERT and seq == SEQ_005) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		return;
	elseif ((classId == ENPC_COLBERT or classId == ENPC_BRYCE or classId == ENPC_CKEPAGA) and seq == SEQ_015) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_3");
	elseif ((classId == ENPC_COLBERT or classId == ENPC_BRYCE) and (seq == SEQ_005 or seq == SEQ_010)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_01");
	elseif (classId == ENPC_CKEPAGA and (seq == SEQ_005 or seq == SEQ_010)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_02");
	elseif (classId == ENPC_RAYA_O_SENNA and seq == SEQ_010) then
		local answered;
		if (data:GetFlag(FLAG_ASKED)) then
			answered = callClientFunction(player, "delegateEvent", player, quest, "processEvent_015_2");
		else
			answered = callClientFunction(player, "delegateEvent", player, quest, "processEvent_015", true);
			data:SetFlag(FLAG_ASKED);
		end
		if (answered == 1) then
			-- The Echo ends fadeInAfterWarp: a same-zone warp lifts the veil.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
			player:EndEvent();
			quest:StartSequence(SEQ_015);
			GetWorldManager():DoZoneChange(player, player:GetZoneID(), nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation);
			-- After the warp: its zone-in would send the NPC again.
			player:HideActor(npc.Id);
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == STUMP_TRIGGER) then
		questBattle.start(player, "Etc3g201", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc3g201, once the three bandits are down.
function winEtc3g2Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_005);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc3g201, on a loss.
function loseEtc3g2Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_STUMP;
	elseif (seq == SEQ_005) then
		return MRKR_COLBERT;
	elseif (seq == SEQ_010) then
		return MRKR_DEN;
	elseif (seq == SEQ_015) then
		return MRKR_BIDDY;
	end
end
