require ("global")
require ("quest")

--[[

Quest Script

Name: 	Arms Race
Code: 	Com0u4
Id: 	111804
Prereq: Com0u3 complete (an Immortal Flames recruit).

Flame Lieutenant Aubrey sends a recruit after the Hellhounds, Garlean
sellswords blockading Ul'dah's eastern trade route near the Golden Bazaar
(a duty entered in place, SimpleContentCom0u401). With the Empire marching on
east Thanalan regardless, Aubrey sends you to Limsa Lominsa to sign three arms
dealers for Lord Lolorito's East Aldenard Trading Company: Woolvale Arms,
Straight Edge Traders and the Gigas Forge, in any order. Aubrey takes the
contracts and tells of the peace Lolorito bought.

The client script (com0u4) names the events; seed 126 holds the cast, the
Hellhounds' camp and the Hellhounds. The dealers' own classes aren't known,
so a Roegadyn pirate, a Lalafell peddler and a Miqo'te smithy stand in for
them at the Limsa Lominsa shops.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Break the Hellhounds' blockade near the Golden Bazaar.
SEQ_010	= 10;	-- Report to Aubrey.
SEQ_020	= 20;	-- Secure three arms contracts in Limsa Lominsa.
SEQ_050	= 50;	-- Return to Aubrey with the contracts.

-- Quest Actors
AUBREY					= 1500198;
WOOLVALE				= 1001740;	-- Woolvale Arms (a Roegadyn pirate)
STRAIGHT_EDGE			= 1000420;	-- Straight Edge Traders (a Lalafell)
GIGAS_FORGE				= 1000719;	-- the Gigas Forge (a Miqo'te)

-- Triggers
HELLHOUND_CAMP			= 1090326;

-- Key Items
WOOLVALE_CONTRACT		= 11000253;
STRAIGHT_EDGE_CONTRACT	= 11000255;
GIGAS_FORGE_CONTRACT	= 11000256;

-- Quest Flags (one per signed contract)
FLAG_WOOLVALE			= 0;
FLAG_STRAIGHT_EDGE		= 1;
FLAG_GIGAS_FORGE		= 2;

-- Places
HELLHOUND_ROAD			= {171, 1200.0, 266.0, -612.0, 3.14};

-- Rewards (as the other companies' fourth missions)
REWARD_EXP				= 1541;
REWARD_SEALS			= 500;
COMPANY					= 3;

-- Each dealer: its contract, its flag, and its first and repeat talk.
DEALERS = {
	[WOOLVALE]		= {WOOLVALE_CONTRACT,		FLAG_WOOLVALE,		"processEvent_020", "processEvent_020_1"},
	[STRAIGHT_EDGE]	= {STRAIGHT_EDGE_CONTRACT,	FLAG_STRAIGHT_EDGE,	"processEvent_030", "processEvent_030_1"},
	[GIGAS_FORGE]	= {GIGAS_FORGE_CONTRACT,	FLAG_GIGAS_FORGE,	"processEvent_040", "processEvent_040_1"},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(HELLHOUND_CAMP, QFLAG_PUSH, false, true);
		quest:SetENpc(AUBREY);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(AUBREY);
		for classId, dealer in pairs(DEALERS) do
			quest:SetENpc(classId, quest:GetData():GetFlag(dealer[2]) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_050) then
		quest:SetENpc(AUBREY, QFLAG_REWARD);
		for classId in pairs(DEALERS) do
			quest:SetENpc(classId);
		end
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();
	local dealer = DEALERS[classId];

	if (sequence == SEQ_ACCEPT and classId == AUBREY) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventAUBREYStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
	elseif (sequence == SEQ_010 and classId == AUBREY) then
		-- Lolorito's bribe, the Empire's march, and orders for Limsa
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
		quest:StartSequence(SEQ_020);
	elseif (sequence == SEQ_020 and classId == AUBREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
	elseif (sequence == SEQ_020 and dealer ~= nil and not quest:GetData():GetFlag(dealer[2])) then
		callClientFunction(player, "delegateEvent", player, quest, dealer[3]);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(dealer[1], 1, 1);
		quest:GetData():SetFlag(dealer[2]);
		-- A flag set in this talk isn't readable until it ends, so check the others.
		local allSigned = true;
		for _, d in pairs(DEALERS) do
			if (d[2] ~= dealer[2] and not quest:GetData():GetFlag(d[2])) then
				allSigned = false;
			end
		end
		if (allSigned) then
			quest:StartSequence(SEQ_050);
		end
	elseif (dealer ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, dealer[4]);
	elseif (sequence == SEQ_050 and classId == AUBREY) then
		-- the contracts, the demilitarized road, and Lolorito's peace
		callClientFunction(player, "delegateEvent", player, quest, "processEvent_050");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);
		for _, d in pairs(DEALERS) do
			keyItems:RemoveItem(d[1], 1);
		end
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
	if (npc:GetActorClassId() == HELLHOUND_CAMP and quest:getSequence() == SEQ_000) then
		startCom0u4Content(player, quest);
		return;
	end
	player:EndEvent();
end

-- The blockade, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorCom0u401) sends you back to Aubrey once the Hellhounds fall.
function startCom0u4Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Com0u401", "SimpleContentCom0u401", "Quest/SimpleQuestBattle/QuestDirectorCom0u401");
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
		player.positionX, player.positionY, player.positionZ, player.rotation, 0x16);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
