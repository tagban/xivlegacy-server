require ("global")
require ("quest")

--[[

Quest Script

Name:	The Big Payback
Code:	Thm200
Id:	110240
Prereq: Level 20, Thaumaturge

In 1.23b this is the Thaumaturges' Guild's welcome (the client script and
its dialogue, not the quest name, say so). Keeper Yayake of Arrzaneth
Ossuary enrolls you in the Traders' ledger (thm20010) and sends you to
Prelate I'llofii, who reads you a patron's last will and testament
(thm20020): it carries a vengeance order against the death-marked billygoat
that killed him. Kill it in Western Thanalan, take its twisted aldgoat horn
as proof, and report to I'llofii (thm20030).

Journal: steps 6-8 of the quest journal sheet.

]]

-- Sequence Numbers
SEQ_010	= 10;  -- Speak with Prelate I'llofii.
SEQ_020	= 20;  -- Kill the death-marked billygoat.
SEQ_030	= 30;  -- Report to I'llofii.

-- Actor Class Ids
ENPC_YAYAKE			= 1000846;
ENPC_ILLOFII		= 1000847;
ENPC_GOGOFU			= 1000046;
ENPC_WAWATON		= 1000648;
ENPC_TOTONO			= 1001143;
ENPC_KAMLITO_HALITO	= 1001142;
ENPC_FYRILSUNN		= 1001144;
BNPC_DEATH_MARKED	= 2202303;

-- Quest Markers
MRKR_ILLOFII		= 11024001;
MRKR_BILLYGOAT		= 11024002;
MRKR_ILLOFII2		= 11024003;

-- Key item
ITEM_TWISTED_HORN	= 11000015;

-- Each thaumaturge has a word for the new member (010_2..7) and advice for
-- the hunt (020_2..8). Yayake's lines fit her; I'llofii repeats the order.
TALKS_010 = {
	[ENPC_YAYAKE] = "processEvent010_2",
	[ENPC_GOGOFU] = "processEvent010_3",
	[ENPC_WAWATON] = "processEvent010_4",
	[ENPC_TOTONO] = "processEvent010_5",
	[ENPC_KAMLITO_HALITO] = "processEvent010_6",
	[ENPC_FYRILSUNN] = "processEvent010_7",
};
TALKS_020 = {
	[ENPC_YAYAKE] = "processEvent020_2",
	[ENPC_ILLOFII] = "processEvent020_3",
	[ENPC_GOGOFU] = "processEvent020_4",
	[ENPC_WAWATON] = "processEvent020_5",
	[ENPC_TOTONO] = "processEvent020_6",
	[ENPC_KAMLITO_HALITO] = "processEvent020_7",
	[ENPC_FYRILSUNN] = "processEvent020_8",
};

REWARD_EXP = 2000;

function onStart(player, quest)
	quest:StartSequence(SEQ_010);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_YAYAKE, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_ILLOFII, QFLAG_TALK);
		for classId, _ in pairs(TALKS_010) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_020) then
		for classId, _ in pairs(TALKS_020) do
			quest:SetENpc(classId);
		end
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_ILLOFII, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_YAYAKE) then
		-- "Do you wish to join the Thaumaturges' Guild?" Yes plays thm20010.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventYayakeStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_010) then
		if (npcClassId == ENPC_ILLOFII) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			quest:StartSequence(SEQ_020);
		elseif (TALKS_010[npcClassId] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_010[npcClassId]);
		end
	elseif (seq == SEQ_020) then
		if (TALKS_020[npcClassId] ~= nil) then
			callClientFunction(player, "delegateEvent", player, quest, TALKS_020[npcClassId]);
		end
	elseif (seq == SEQ_030 and npcClassId == ENPC_ILLOFII) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:CompleteQuest(quest);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onKillBNpc(player, quest, bnpc)
	if (bnpc == BNPC_DEATH_MARKED and quest:GetSequence() == SEQ_020) then
		player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_TWISTED_HORN, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_030);
	end
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_010) then
		return MRKR_ILLOFII;
	elseif (seq == SEQ_020) then
		return MRKR_BILLYGOAT;
	elseif (seq == SEQ_030) then
		return MRKR_ILLOFII2;
	end
end
