require ("global")
require ("quest")

--[[

Quest Script

Name:	Dream On, Dream Away
Code:	Alc306
Id:	110422
Prereq: Level 36, Alchemist

Damielliot is worse, and the healers mean to try a treatment the children
must not see. Healer S'lyhhia asks you to talk them away from his bedside.
At his bed the Echo takes you into his past: a boy fallen from a cliff
after a dragon scattered his captors. He gives you a poultice and its
recipe; make the salve and treat him, and in the sickroom Damielliot wakes
(alc30610, alc30620). Nogeloix hears the news and pays 36,000 gil and
3,600 experience (alc30630).

Simplified here: the Echo's place (runCharaSchedulerPastAreaIn) has no
private area on this server, so the injured boy's lines play at the
sickroom bed. The salve has no recipe on this server yet, so it is checked
in the bag as it would come out of a synthesis. S'lyhhia (1000932, spawn
31070), Damielliot (1000853, 31071) and the schoolgirl (1001039, 31072) have
public spawns in the Phrontistery.

Journal: steps 139-142, 241 and 265 of the quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Go to Damielliot's sickroom.
SEQ_010	= 10;  -- Make the salve and treat the injured boy.
SEQ_020	= 20;  -- Report to Nogeloix.

-- Actor Class Ids
ENPC_NOGELOIX		= 1000597;
ENPC_XAU_NBOLO		= 1000641;
ENPC_OEFYRBLAET		= 1000642;
ENPC_BABAKI			= 1000643;
ENPC_SLYHHIA		= 1000932;
ENPC_DAMIELLIOT		= 1000853; -- in his sickroom
ENPC_SCHOOLGIRL		= 1001039; -- soft-spoken schoolgirl

ITEM_POULTICE	= 11000078; -- Frondale's poultice (from Damielliot, a synthesis input)
ITEM_SALVE		= 11000079; -- Faustigeant's salve (crafted)

REWARD_GIL	= 36000;
REWARD_EXP	= 3600;

-- Markers (01/03/05/A9: one per cutscene).
MRKR_SICKROOM	= 11042201; -- alc30610
MRKR_NOGELOIX	= 11042203; -- alc30630

-- In front of Damielliot's bed.
ULDAH_ZONE = 209;
SICKROOM_SPOT = { -220.97, 229.5, 308.29, -0.54 };

-- The Phrontistery's chatter; slot 2 is Nogeloix, slots 3-5 the same
-- alchemists as in Alc200. Of the children only the schoolgirl has an actor.
TALKS = {
	[SEQ_000] = {
		[ENPC_NOGELOIX] = "processEvent002_2",
		[ENPC_XAU_NBOLO] = "processEvent002_3",
		[ENPC_OEFYRBLAET] = "processEvent002_4",
		[ENPC_BABAKI] = "processEvent002_5",
		[ENPC_SCHOOLGIRL] = "processEvent002_10",
		[ENPC_SLYHHIA] = "processEvent002_12",
	},
	[SEQ_010] = {
		[ENPC_SLYHHIA] = "processEvent002_12",
	},
	[SEQ_020] = {
		[ENPC_SCHOOLGIRL] = "processEvent020_4",
		[ENPC_XAU_NBOLO] = "processEvent020_7",
		[ENPC_OEFYRBLAET] = "processEvent020_8",
		[ENPC_BABAKI] = "processEvent020_9",
		[ENPC_DAMIELLIOT] = "processEvent020_10",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_SLYHHIA, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000 or sequence == SEQ_010) then
		quest:SetENpc(ENPC_DAMIELLIOT, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_NOGELOIX, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_SLYHHIA) then
		-- Keep the children away from his bedside? (1 = accepted)
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventSlyhhiaStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_DAMIELLIOT) then
		-- The Echo (1 = look into his past): the fallen boy, his story and
		-- the poultice.
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent008");
			callClientFunction(player, "delegateEvent", player, quest, "processEvent009");
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_POULTICE, 1, 1);
			quest:StartSequence(SEQ_010);
		end
	elseif (seq == SEQ_010 and npcClassId == ENPC_DAMIELLIOT) then
		if (player:GetItemPackage(INVENTORY_NORMAL):HasItem(ITEM_SALVE, 1)) then
			-- The salve, and Damielliot wakes (alc30610, alc30620,
			-- after-warp fade).
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_SALVE, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			quest:StartSequence(SEQ_020);
			player:EndEvent();
			warpTo(player, ULDAH_ZONE, SICKROOM_SPOT);
			return;
		end
		callClientFunction(player, "delegateEvent", player, quest, "processEvent009_2");
	elseif (seq == SEQ_020 and npcClassId == ENPC_NOGELOIX) then
		-- alc30630: the news, and payment.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
	elseif (TALKS[seq] ~= nil and TALKS[seq][npcClassId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, TALKS[seq][npcClassId]);
	end

	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:GetSequence();
	if (seq == SEQ_000 or seq == SEQ_010) then
		return MRKR_SICKROOM;
	elseif (seq == SEQ_020) then
		return MRKR_NOGELOIX;
	end
end
