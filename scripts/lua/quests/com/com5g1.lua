require ("global")
require ("quest")
require ("dungeon")

--[[

Quest Script

Name: 	Into the Dark
Code: 	Com5g1
Id: 	111611
Prereq: A sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

The Garleans hold Dzemael Darkhold, and Kan-E-Senna has promised Ishgard
reinforcements to retake it. Fulke sends you north to watch the knights as
much as to help them: to Ser Yuhelmeric, lord commander of House
Durendaire's knights at Owl's Nest. He trusts no mercenary and asks proof:
slay the imperials in the captain's quarters. The guard at the entrance
(Dyrstweitz) lets you in. One of the speculators there carries a draconian
rosary, the mark of a heretic who sided with the dragons. Yuhelmeric takes
it for proof that a fallen knight guided the Empire in, and Fulke hears that
the north's defections are isolated no more.

The client script (com5g1) names the events. Seed 139 places the guard,
seed 140 Ser Yuhelmeric; the dungeon content script spawns the magitek
terminal that takes you back out (Com5u1).

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Travel to Owl's Nest and speak with Ser Yuhelmeric.
SEQ_010	= 10;	-- Travel to Dzemael Darkhold.
SEQ_015	= 15;	-- Slay the imperial speculators in the captain's quarters.
SEQ_020	= 20;	-- Report to Ser Yuhelmeric at Owl's Nest.
SEQ_030	= 30;	-- Report to Fulke.

-- Quest Actors
FULKE					= 1500200;
YUHELMERIC				= 1000370;
DYRSTWEITZ				= 1001154;	-- the House Dzemael guard at the entrance
TERMINAL				= 1002062;	-- the magitek terminal in the lower chambers

-- The imperial speculators in the captain's quarters (battle npc class)
SPECULATOR				= 2380003;

-- Key item: the heretic's mark one of them carried
DRACONIAN_ROSARY		= 11000264;

-- Entry to the Darkhold, as in Com5u1: only the level and the discipline
-- are checked (no party state for scripts yet).
ENTRY_LEVEL				= 45;
PARTY_MIN				= 2;
PARTY_MAX				= 4;
TIME_LIMIT				= 60;		-- minutes, as the guard tells it

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 4000;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(YUHELMERIC, QFLAG_TALK);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(DYRSTWEITZ, QFLAG_TALK);
		quest:SetENpc(YUHELMERIC);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(DYRSTWEITZ, QFLAG_TALK);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
		quest:SetENpc(YUHELMERIC);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(YUHELMERIC, QFLAG_REWARD);
		quest:SetENpc(DYRSTWEITZ);
		quest:SetENpc(TERMINAL, QFLAG_TALK);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(FULKE, QFLAG_REWARD);
		quest:SetENpc(YUHELMERIC);
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

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFULKEStart", PARTY_MIN, PARTY_MAX, ENTRY_LEVEL);
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence < SEQ_030 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000", PARTY_MIN, PARTY_MAX, ENTRY_LEVEL);
	elseif (sequence == SEQ_000 and classId == YUHELMERIC) then
		-- mercenaries for reinforcements, and the proof he asks
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010", PARTY_MIN, PARTY_MAX, ENTRY_LEVEL);
		quest:StartSequence(SEQ_010);
	elseif (sequence == SEQ_010 and classId == DYRSTWEITZ) then
		-- the Darkhold's rules, and the device in its farthest reaches
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
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_030_1");
	elseif (classId == TERMINAL and player:GetZoneID() == DUNGEONS.dzemael.zone) then
		-- the device's way back to the entrance
		player:EndEvent();
		leaveDungeon(player);
		return;
	elseif (sequence == SEQ_020 and classId == YUHELMERIC) then
		-- the rosary, and the heretic who led the imperials in
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_040");
		quest:StartSequence(SEQ_030);
	elseif (sequence == SEQ_030 and classId == FULKE) then
		-- defectors across the realm, and Ishgard's thanks
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(DRACONIAN_ROSARY, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- A speculator falls: the rosary he carried is Yuhelmeric's proof.
function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() == SEQ_015 and bnpc == SPECULATOR) then
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(DRACONIAN_ROSARY, 1, 1);
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
