require ("global")
require ("quest")

--[[

Quest Script

Name:	The Boy and the Dragon Gay
Code:	Alc300
Id:	110421
Prereq: Level 30, Alchemist

Nogeloix calls you back: Damielliot has not woken, and those who stirred
him are asked to visit. At his bedside he murmurs of dragons, and a
schoolgirl tells you the tale he left unfinished. Nogeloix sends you to
Gridania for starfall grass. At the Adventurers' Guild the bard Penelope
has some but will not part with it; Miounne sells you a little about her,
and Penelope trades the grass for the tale of the boy and the dragon
(alc30010). Bring the grass to Nogeloix, then help Healer S'lyhhia with the
bored children: they get a story (alc30020) and S'lyhhia hands over the
guild's thanks, 30,000 gil and 3,000 experience.

Simplified here: the parley with Penelope is left out; once Miounne has
told you about her, Penelope gives in. 008_3/008_4 (another informant) and
007_7 (a second Gridanian) have no actors. Damielliot (1000853), the
schoolgirl (1001039) and S'lyhhia (1000932) get public spawns in the
Phrontistery (31071, 31072, 31070).

Journal: steps 131-138 of the quest journal sheet (0B/45/08/4E).

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Visit Damielliot.
SEQ_003	= 3;   -- Ask the children what his murmurs mean.
SEQ_005	= 5;   -- Report to Nogeloix.
SEQ_007	= 7;   -- Find starfall grass in Gridania.
SEQ_008	= 8;   -- Learn about Penelope, then deal with her.
SEQ_010	= 10;  -- Bring the grass to Nogeloix.
SEQ_015	= 15;  -- Help Healer S'lyhhia with the children.

-- Actor Class Ids
ENPC_NOGELOIX		= 1000597;
ENPC_XAU_NBOLO		= 1000641;
ENPC_OEFYRBLAET		= 1000642;
ENPC_BABAKI			= 1000643;
ENPC_SLYHHIA		= 1000932;
ENPC_DAMIELLIOT		= 1000853; -- in his sickroom
ENPC_SCHOOLGIRL		= 1001039; -- soft-spoken schoolgirl
ENPC_PENELOPE		= 1700001; -- Adventurers' Guild, Gridania
ENPC_MIOUNNE		= 1000230; -- Adventurers' Guild, Gridania

ITEM_STARFALL_GRASS	= 11000041; -- key item

FLAG_MIOUNNE_TOLD	= 0; -- Miounne has told you about Penelope

REWARD_GIL	= 30000;
REWARD_EXP	= 3000;

-- Markers (01/03/05/A9: one per cutscene).
MRKR_PENELOPE	= 11042101; -- alc30010
MRKR_CHILDREN	= 11042102; -- alc30020

-- In front of S'lyhhia at the children's ward.
ULDAH_ZONE = 209;
SLYHHIA_SPOT = { -216.0, 229.5, 303.0, -3.14 };

-- The Phrontistery's chatter; slot 2 is Nogeloix, slots 3-5 the same
-- alchemists as in Alc200. The children's slots (002_6-002_10) have no
-- actors.
TALKS = {
	[SEQ_000] = {
		[ENPC_NOGELOIX] = "processEvent002_2",
		[ENPC_XAU_NBOLO] = "processEvent002_3",
		[ENPC_OEFYRBLAET] = "processEvent002_4",
		[ENPC_BABAKI] = "processEvent002_5",
	},
	[SEQ_003] = {
		[ENPC_DAMIELLIOT] = "processEvent005_2",
		[ENPC_NOGELOIX] = "processEvent002_2",
	},
	[SEQ_005] = {
		[ENPC_DAMIELLIOT] = "processEvent005_2",
		[ENPC_SCHOOLGIRL] = "processEvent005_3",
	},
	[SEQ_007] = {
		[ENPC_NOGELOIX] = "processEvent007_2",
		[ENPC_XAU_NBOLO] = "processEvent007_3",
		[ENPC_OEFYRBLAET] = "processEvent007_4",
		[ENPC_BABAKI] = "processEvent007_5",
		[ENPC_MIOUNNE] = "processEvent007_6",
	},
	[SEQ_008] = {
		[ENPC_NOGELOIX] = "processEvent007_2",
	},
	[SEQ_010] = {
		[ENPC_PENELOPE] = "processEvent010_2",
		[ENPC_XAU_NBOLO] = "processEvent010_3",
		[ENPC_OEFYRBLAET] = "processEvent010_4",
		[ENPC_BABAKI] = "processEvent010_5",
	},
	[SEQ_015] = {
		[ENPC_NOGELOIX] = "processEvent015_2",
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
		quest:SetENpc(ENPC_DAMIELLIOT, QFLAG_TALK);
	elseif (sequence == SEQ_003) then
		quest:SetENpc(ENPC_SCHOOLGIRL, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_NOGELOIX, QFLAG_TALK);
	elseif (sequence == SEQ_007) then
		quest:SetENpc(ENPC_PENELOPE, QFLAG_TALK);
	elseif (sequence == SEQ_008) then
		local told = quest:GetData():GetFlag(FLAG_MIOUNNE_TOLD);
		quest:SetENpc(ENPC_MIOUNNE, told and QFLAG_OFF or QFLAG_TALK);
		quest:SetENpc(ENPC_PENELOPE, told and QFLAG_TALK or QFLAG_OFF);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_NOGELOIX, QFLAG_TALK);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_SLYHHIA, QFLAG_REWARD);
	end
end

local function warpTo(player, zoneId, spot)
	GetWorldManager():DoZoneChange(player, zoneId, nil, 0, 15, spot[1], spot[2], spot[3], spot[4]);
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT and npcClassId == ENPC_NOGELOIX) then
		-- Visit Damielliot again? (1 = accepted)
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventNogeloixStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000 and npcClassId == ENPC_DAMIELLIOT) then
		-- Feverish murmurs of dragons.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent003");
		quest:StartSequence(SEQ_003);
	elseif (seq == SEQ_003 and npcClassId == ENPC_SCHOOLGIRL) then
		-- The tale Damielliot left unfinished.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
		quest:StartSequence(SEQ_005);
	elseif (seq == SEQ_005 and npcClassId == ENPC_NOGELOIX) then
		-- Starfall grass, from Gridania.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent007");
		quest:StartSequence(SEQ_007);
	elseif (seq == SEQ_007 and npcClassId == ENPC_PENELOPE) then
		-- Penelope knows the herb, but it is rare.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent008");
		quest:StartSequence(SEQ_008);
	elseif (seq == SEQ_008 and npcClassId == ENPC_MIOUNNE) then
		if (quest:GetData():GetFlag(FLAG_MIOUNNE_TOLD)) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent008_6");
		else
			-- Miounne will talk, for a contribution (1 = pay).
			local paid = callClientFunction(player, "delegateEvent", player, quest, "processEvent008_5");
			if (paid == 1) then
				quest:GetData():SetFlag(FLAG_MIOUNNE_TOLD);
				quest:SetENpc(ENPC_MIOUNNE, QFLAG_OFF);
				quest:SetENpc(ENPC_PENELOPE, QFLAG_TALK);
			end
		end
	elseif (seq == SEQ_008 and npcClassId == ENPC_PENELOPE) then
		if (quest:GetData():GetFlag(FLAG_MIOUNNE_TOLD)) then
			-- alc30010: the grass for the tale of the boy and the dragon.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_STARFALL_GRASS, 1, 1);
			quest:StartSequence(SEQ_010);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEvent008_2");
		end
	elseif (seq == SEQ_010 and npcClassId == ENPC_NOGELOIX) then
		-- The grass handed over; S'lyhhia is waiting for you.
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_STARFALL_GRASS, 1);
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		quest:StartSequence(SEQ_015);
	elseif (seq == SEQ_015 and npcClassId == ENPC_SLYHHIA) then
		-- A story for the children (alc30020, the choice is in the
		-- cutscene), S'lyhhia's thanks and payment. After-warp fade.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015_3");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 2);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:CompleteQuest(quest);
		player:EndEvent();
		warpTo(player, ULDAH_ZONE, SLYHHIA_SPOT);
		return;
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
	if (seq == SEQ_008) then
		return MRKR_PENELOPE;
	elseif (seq == SEQ_015) then
		return MRKR_CHILDREN;
	end
end
