require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Into the Dark
Code: 	Com5u1
Id: 	111811
Prereq: A sworn member of the Immortal Flames (company_gate in quest_offers.rs).

The Garleans hold Dzemael Darkhold, and Nael van Darnus, Legatus of the
VIIth, was seen among them. House Fortemps is calling knights from Ishgard's
outer reaches to retake it, so Aubrey sends you north as one: with a Norwick
knight's sigil, to Ser Artoirel at Owl's Nest. Ser Vairemont there says
Artoirel has already ridden for the Darkhold. The House Dzemael guard at its
entrance (Dyrstweitz) lets the sigil's bearer in. Slaying the imperial
primus ordinarius inside yields a silver-winged kabuto, a legatus's helm.
Vairemont knows it for a decoy's, and Aubrey hears what the Darkhold means
to the Empire.

The client script (com5u1) names the events. Seed 139 places Vairemont and
the guard; the dungeon content script spawns the magitek terminal that takes
you back out.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Travel to Owl's Nest and find Ser Artoirel.
SEQ_010	= 10;	-- Travel to Dzemael Darkhold.
SEQ_015	= 15;	-- Slay the imperial primus ordinarius in the Darkhold.
SEQ_020	= 20;	-- Report to Ser Vairemont at Owl's Nest.
SEQ_030	= 30;	-- Report to Aubrey.

-- Quest Actors
AUBREY					= 1500198;
VAIREMONT				= 1000586;
DYRSTWEITZ				= 1001154;	-- the House Dzemael guard at the entrance
TERMINAL				= 1002062;	-- the magitek terminal in the lower chambers

-- The Darkhold's imperial primus ordinarius (battle npc class)
PRIMUS_ORDINARIUS		= 2307001;

-- Key items
NORWICK_SIGIL			= 11000265;
SILVER_WINGED_KABUTO	= 11000266;

-- Entry to the Darkhold: the party and level the guards' lines name. The
-- server has no party state for scripts yet, so only the level and the
-- discipline are checked.
ENTRY_LEVEL				= 45;
PARTY_MIN				= 2;
PARTY_MAX				= 4;
TIME_LIMIT				= 60;		-- minutes, as the guard tells it

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 4000;
COMPANY					= 3;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(VAIREMONT, QFLAG_TALK);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(DYRSTWEITZ, QFLAG_TALK);
		quest:SetENpc(VAIREMONT);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(DYRSTWEITZ, QFLAG_TALK);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
		quest:SetENpc(VAIREMONT);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(VAIREMONT, QFLAG_REWARD);
		quest:SetENpc(DYRSTWEITZ);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(AUBREY, QFLAG_REWARD);
		quest:SetENpc(VAIREMONT);
		quest:SetENpc(DYRSTWEITZ);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
	end
end

-- Only Disciples of War or Magic at the entry level go in.
local function mayEnter(player)
	return (player:IsDiscipleOfWar() or player:IsDiscipleOfMagic())
		and player:GetHighestLevel() >= ENTRY_LEVEL;
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(NORWICK_SIGIL, 1, 1);
		end
	elseif (sequence < SEQ_030 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_000 and classId == VAIREMONT) then
		-- the swineherd's son, and Artoirel gone ahead to the Darkhold
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", PARTY_MIN, PARTY_MAX, ENTRY_LEVEL);
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == DYRSTWEITZ) then
		-- the sigil, the pincer, and the Darkhold's rules
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020", TIME_LIMIT, 0, 0);
		quest:StartSequence(SEQ_015);
	elseif (sequence == SEQ_015 and classId == DYRSTWEITZ) then
		local enter = callClientFunction(player, "delegateEvent", player, quest, "processEvent_020_1");
		if (enter == 1) then
			if (mayEnter(player)) then
				player:EndEvent();
				enterDungeon(player, "dzemael");
				return;
			end
		end
	elseif (sequence >= SEQ_020 and classId == DYRSTWEITZ) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_020_2");
	elseif (classId == TERMINAL and player:GetZoneID() == DUNGEONS.dzemael.zone) then
		-- the terminal's way back to the entrance
		player:EndEvent();
		leaveDungeon(player);
		return;
	elseif (sequence == SEQ_020 and classId == VAIREMONT) then
		-- a decoy's helm, and the bumpkin's accent
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030");
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == AUBREY) then
		-- House Fortemps's parcel, and the crystals under the Darkhold
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(NORWICK_SIGIL, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(SILVER_WINGED_KABUTO, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The primus falls: his helm is the proof Vairemont asked for.
function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() == SEQ_015 and bnpc == PRIMUS_ORDINARIUS) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(SILVER_WINGED_KABUTO, 1, 1);
		quest:StartSequence(SEQ_020);
	end
end

function onPush(player, quest, npc)
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
