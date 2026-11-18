require ("global")
require ("quest")

--[[

Quest Script

Name: 	It's a Piece of Cake to Bake a Poison Cake
Code: 	Gcl303
Id: 	111419
Prereq: Level 40, a sworn member of the Maelstrom (company_gate in quest_offers.rs).

R'sushmo of the Bismarck has baked a suncake that keeps the scurvy from the
Maelstrom's troops, but Kikkiroon Irongut stole the batch she meant to show
Storm Commander Rhiki. She baked a second batch laced with Nightbreath and
let the Qiqirn steal that too; Aentfoet saw him run off towards Cedarwood.
She sends you after him, to find his body, or to finish the job. Kikkiroon
is still on his feet (a duty entered in place, SimpleContentGcl30301), and
once he yields he swears off suncakes. Rhiki, who followed you from Limsa
Lominsa, takes him into custody, and is relieved to hear the first batch
was clean.

The client script (gcl303) names the events; seed 159 holds the Cedarwood
trigger, Kikkiroon (the foe and, after, the penitent), and Rhiki there.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find Kikkiroon Irongut in Cedarwood.
SEQ_010	= 10;	-- Speak with Storm Commander Rhiki.

-- Quest Actors
RSUSHMO					= 1000170;
RHIKI					= 1001810;	-- Storm Commander R'ashaht Rhiki
KIKKIROON				= 1001811;	-- Kikkiroon Irongut, once he yields

-- Triggers
CEDARWOOD				= 1090346;

-- Places
CEDARWOOD_FIGHT			= {565.5, 53.17, 15.85, -1.57};	-- where the duty puts you, facing him
CEDARWOOD_FOOT			= {128, 572.5, 53.73, 17.9, -1.57};	-- set down here when Kikkiroon yields

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 1000;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(RSUSHMO, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(RSUSHMO);
		quest:SetENpc(CEDARWOOD, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(RSUSHMO);
		quest:SetENpc(KIKKIROON);
		quest:SetENpc(RHIKI, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == RSUSHMO and sequence == SEQ_ACCEPT) then
		-- the suncakes, the thief, and the Nightbreath
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == RSUSHMO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == KIKKIROON and sequence == SEQ_010) then
		-- one time enough
		callClientFunction(player, "delegateEvent", player, quest, "processEventQiqirn");
	elseif (classId == RHIKI and sequence == SEQ_010) then
		-- the brig for Irongut, and the first batch clean after all
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (npc:GetActorClassId() == CEDARWOOD and quest:GetSequence() == SEQ_000 and player:GetDirector() == nil) then
		startGcl303Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- Kikkiroon, a duty entered by warp (spawnType 16) rather than in place:
-- in place, the client keeps the clearing's NPCs in view, and the penitent
-- Kikkiroon would stand beside the one you fight. Its director
-- (QuestDirectorGcl30301) sets you back down in Cedarwood once he yields.
function startGcl303Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcl30301", "SimpleContentGcl30301", "Quest/SimpleQuestBattle/QuestDirectorGcl30301");
	if (contentArea == nil) then
		player:EndEvent();
		return;
	end
	local director = contentArea:GetContentDirector();
	player:AddDirector(director);
	director:StartDirector(false);
	player:KickEvent(director, "noticeEvent", true);
	player:SetLoginDirector(director);
	player:EndEvent();
	GetWorldManager():DoZoneChangeContent(player, contentArea,
		CEDARWOOD_FIGHT[1], CEDARWOOD_FIGHT[2], CEDARWOOD_FIGHT[3], CEDARWOOD_FIGHT[4], 16);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
