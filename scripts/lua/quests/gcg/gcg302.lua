require ("global")
require ("quest")

--[[

Quest Script

Name: 	The Pen Is Mightier Than the Spear
Code: 	Gcg302
Id: 	111618
Prereq: Level 25, a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

Dhemdaeg of the Wood Wailers despairs of Hilith, a recruit hopeless with
a spear and forever missing from drill. He searches Quarrymill Landing and
sends you to the Rootslake in the South Shroud. There you slay a beast, and
Challinie of Stillglade Fane, who came to put it down, tells you Hilith has
been training alone in secret, and hands you a sketch Hilith drew of her.
The sketch shows Dhemdaeg the gift he missed: the Twin Adder wants artists.

The client script (gcg302) names the events; seed 163 holds Challinie and
the beast at the Rootslake.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Search for Hilith near the Rootslake.
SEQ_005	= 5;	-- Speak with Challinie.
SEQ_010	= 10;	-- Show the sketch to Dhemdaeg.

-- Quest Actors
DHEMDAEG				= 1000567;
CHALLINIE				= 1000956;
DREADWOLF				= 2101403;

-- Key items
SKETCH					= 11000403;	-- Sketch of Challinie, by Hilith

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(DHEMDAEG, QFLAG_TALK);
		return;
	end

	quest:SetENpc(DHEMDAEG, sequence == SEQ_010 and QFLAG_REWARD or QFLAG_NONE);
	if (sequence == SEQ_005) then
		quest:SetENpc(CHALLINIE, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(CHALLINIE);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == DHEMDAEG and sequence == SEQ_ACCEPT) then
		-- Hilith, the recruit who will not drill
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == DHEMDAEG and sequence == SEQ_010) then
		-- a brush in place of a spear
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(SKETCH, 1);
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == DHEMDAEG) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == CHALLINIE and sequence == SEQ_005) then
		-- Hilith trains alone, and draws
		callClientFunction(player, "delegateEvent", player, quest, "processEventChallinie");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(SKETCH, 1, 1);
		quest:StartSequence(SEQ_010);
	elseif (classId == CHALLINIE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventChallinieFree");
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= DREADWOLF) then
		return;
	end
	quest:StartSequence(SEQ_005);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
