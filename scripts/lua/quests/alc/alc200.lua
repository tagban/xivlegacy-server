require ("global")
require ("quest")

--[[

Quest Script

Name:	Sleep, Cousin of Death
Code:	Alc200
Id:	110420
Prereq: Level 20, Alchemist

The Alchemists' Guild welcome at Frondale's Phrontistery. Nogeloix signs
you on (alc20010) and tells of Damielliot, the guildmaster's son, lost in
long fits of sleep. Fetch the rare reagent from Nomomo at Camp Black Brush,
brew the medicine with it, and show it to Nogeloix; Healer S'lyhhia takes
you to Damielliot's room, where he stirs for a moment (alc20020). Nogeloix
pays you, while a Limsan assessor is turned away (alc20030): 20,000 gil and
2,000 experience.

The medicine has no recipe on this server yet, so it is checked in the bag
as it would come out of a synthesis. S'lyhhia (1000932) only stood in the
Phrontistery's instances in 1.23b; she has a public spawn by the children's
ward (31070).

The client's alc20020/alc20030 functions take a fourth argument that picks
a cutscene variant when it is 3; it is not passed here (the other variant).

Journal: steps 68-72 of the quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Get the reagent from Nomomo at Camp Black Brush.
SEQ_010	= 10;  -- Brew the medicine and bring it to Nogeloix.
SEQ_015	= 15;  -- Take it to Damielliot with Healer S'lyhhia.
SEQ_020	= 20;  -- Back to Nogeloix for the reward.

-- Actor Class Ids
ENPC_NOGELOIX		= 1000597;
ENPC_XAU_NBOLO		= 1000641;
ENPC_OEFYRBLAET		= 1000642;
ENPC_BABAKI			= 1000643;
ENPC_NOMOMO			= 1001392; -- Camp Black Brush
ENPC_SLYHHIA		= 1000932;

ITEM_MOLE		= 11000076; -- mummified mole (from Nomomo, a synthesis input)
ITEM_MEDICINE	= 11000077; -- potent medication (crafted)

REWARD_GIL	= 20000;
REWARD_EXP	= 2000;

-- Markers (01/03/05/A9: one per cutscene).
MRKR_NOGELOIX	= 11042001; -- alc20010
MRKR_SICKROOM	= 11042002; -- alc20020
MRKR_REWARD		= 11042003; -- alc20030

-- In front of S'lyhhia at the children's ward.
ULDAH_ZONE = 209;
SLYHHIA_SPOT = { -216.0, 229.5, 303.0, -3.14 };

-- The alchemists' chatter. No speaker is named; slot 2 is Nogeloix (his
-- lines point you on), slots 3-5 go to the same alchemists in Alc300 and
-- Alc306.
TALKS = {
	[SEQ_000] = {
		[ENPC_NOGELOIX] = "processEvent005_2",
		[ENPC_XAU_NBOLO] = "processEvent005_3",
		[ENPC_OEFYRBLAET] = "processEvent005_4",
		[ENPC_BABAKI] = "processEvent005_5",
	},
	[SEQ_010] = {
		[ENPC_NOMOMO] = "processEvent010_2",
		[ENPC_XAU_NBOLO] = "processEvent005_3",
		[ENPC_OEFYRBLAET] = "processEvent005_4",
		[ENPC_BABAKI] = "processEvent005_5",
	},
	[SEQ_015] = {
		[ENPC_NOGELOIX] = "processEvent015_2",
		[ENPC_XAU_NBOLO] = "processEvent015_3",
		[ENPC_OEFYRBLAET] = "processEvent015_4",
		[ENPC_BABAKI] = "processEvent015_5",
	},
	[SEQ_020] = {
		[ENPC_SLYHHIA] = "processEvent020_2",
		[ENPC_XAU_NBOLO] = "processEvent020_3",
		[ENPC_OEFYRBLAET] = "processEvent020_4",
	},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_NOGELOIX, QFLAG_TALK);
		return;
	end
	if (TALKS[sequence] ~= nil) then
		for classId, _ in pairs(TALKS[sequence]) do
			quest:SetENpc(classId);
		end
	end
	if (sequence == SEQ_000) then
		quest:SetENpc(ENPC_NOMOMO, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_NOGELOIX, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_SLYHHIA, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_NOGELOIX, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

local function hasItem(player, itemId)
	return player:GetItemPackage(INVENTORY_NORMAL):HasItem(itemId, 1);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NOGELOIX) then
		-- Join the guild; on yes, alc20010 (Damielliot's case and the
		-- formula). 1 = accepted.
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNogeloixStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_NOMOMO) then
		-- Nomomo grumbles and hands over the reagent.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(ITEM_MOLE, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif (seq == SEQ_010 and npcClassId == ENPC_NOGELOIX) then
		if (hasItem(player, ITEM_MEDICINE)) then
			-- Take it to Damielliot yourself; S'lyhhia will guide you.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
			quest:StartSequence(SEQ_015);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_2");
		end
	elseif (seq == SEQ_015 and npcClassId == ENPC_SLYHHIA) then
		-- May I have the medicine? (1 = go with her)
		local go = callClientFunction(player, "delegateEvent", player, quest, "processEvent015_6");
		if (go == 1 and hasItem(player, ITEM_MEDICINE)) then
			-- alc20020: Damielliot stirs, briefly (after-warp fade).
			player:GetItemPackage(INVENTORY_NORMAL):RemoveItem(ITEM_MEDICINE, 1);
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			quest:StartSequence(SEQ_020);
			player:EndEvent();
			warpTo(player, ULDAH_ZONE, SLYHHIA_SPOT);
			return;
		end
	elseif (seq == SEQ_020 and npcClassId == ENPC_NOGELOIX) then
		-- alc20030: the assessor turned away, and payment.
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
	if (seq == SEQ_010) then
		return MRKR_NOGELOIX;
	elseif (seq == SEQ_015) then
		return MRKR_SICKROOM;
	elseif (seq == SEQ_020) then
		return MRKR_REWARD;
	end
end
