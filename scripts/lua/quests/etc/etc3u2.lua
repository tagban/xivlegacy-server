require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	There Might Be Blood
Code: 	Etc3u2
Id: 	110727
Prereq: Level 21, any class

The pugilist Gunnulf and his unnamed master have word of a game at the
Platinum Mirage: the rich mean to loose a beast from the bloodsands on
Little Ala Mhigo, south of Camp Drybone, and wager on the slaughter.
Stepping onto the path into the settlement starts the fight
(SimpleContentEtc3u201, the client's SimpleQuestBattle QuestDirectorEtc3u201)
with the beast, a Coliseum yarzon. Then search the area: Rycharde, who
lost his seat on the Syndicate and the Coliseum to Raubahn, is lurking
nearby. Answer him and the Echo shows you Raubahn's thousandth victory
(cutscene etc3u210). Report back to Gunnulf. Reward 10,000 gil (the
client's reward table, data/01/03/05/61.DAT); the table gives the
experience only as a rank, so that amount is an estimate.

The beast is not named in the client's scripts; the Coliseum yarzon is the
client's own bloodsands beast. Rycharde stands at the edge of the
settlement (open world, visible to everyone; his com0u6 spawn is in Ul'dah).

Client script etc3u2: processEventStart (offer), processEventStartAfter
(Gunnulf while you go), processEventRycharde (returns 1 when you answer
him), processEventNqetc3u2 (the Echo, then Rycharde's threat),
processEventRychardeFree (Rycharde after), processEventClear (the reward).
Journal steps 409-413.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Fell the beast at Little Ala Mhigo.
SEQ_005	= 5;	-- Search the area for whoever loosed it.
SEQ_010	= 10;	-- Report back to Gunnulf.

-- Actor Class Ids
ENPC_GUNNULF		= 1001256;
ENPC_RYCHARDE		= 1001718;
PATH_TRIGGER		= 1090608;

-- Quest Markers
MRKR_PATH			= 11072701;
MRKR_RYCHARDE		= 11072702;
MRKR_GUNNULF		= 11072703;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {171, 1200.0, 251.13, 222.0, 3.14};

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
		quest:SetENpc(ENPC_GUNNULF, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(PATH_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_GUNNULF);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_RYCHARDE, QFLAG_TALK);
		quest:SetENpc(ENPC_GUNNULF);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_RYCHARDE);
		quest:SetENpc(ENPC_GUNNULF, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_GUNNULF) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (classId == ENPC_GUNNULF and (seq == SEQ_000 or seq == SEQ_005)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == ENPC_GUNNULF and seq == SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == ENPC_RYCHARDE and seq == SEQ_005) then
		local answered = callClientFunction(player, "delegateEvent", player, quest, "processEventRycharde");
		if (answered == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventNqetc3u2");
			attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
			player:EndEvent();
			quest:StartSequence(SEQ_010);
			return;
		end
	elseif (classId == ENPC_RYCHARDE and seq == SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventRychardeFree");
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == PATH_TRIGGER) then
		questBattle.start(player, "Etc3u201", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc3u201, once the beast is down.
function winEtc3u2Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_005);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc3u201, on a loss.
function loseEtc3u2Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_PATH;
	elseif (seq == SEQ_005) then
		return MRKR_RYCHARDE;
	elseif (seq == SEQ_010) then
		return MRKR_GUNNULF;
	end
end
