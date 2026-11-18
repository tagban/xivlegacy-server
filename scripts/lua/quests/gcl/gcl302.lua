require ("global")
require ("quest")

--[[

Quest Script

Name: 	Saving the Stead Instead
Code: 	Gcl302
Id: 	111418
Prereq: Level 25, a sworn member of the Maelstrom (company_gate in quest_offers.rs).

Since Merlwyb shackled the pirates to the bay, the Bloody Executioners'
idle crew has taken to bloodying one another, and Red Rooster Stead, which
they used to watch over, is losing its crops to kobolds. Captain Hyllfyr
sends his most restless men to an old kobold den north and east of
Bloodshore, and as they may not leave the city, a sworn Maelstrommer must
go with them. Fyrilskyf leads you against the kobolds (a duty entered in
place, SimpleContentGcl30201); back aboard the Astalicia Hyllfyr allows
that a Storm Pup may not be all bad.

The client script (gcl302) names the events but not the giver; Hyllfyr,
captain of the Bloody Executioners, stands in for him. Seed 158 holds
Hyllfyr aboard the Astalicia, the crew at the den and the kobolds.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Join the Executioners at the old kobold den north and east of Bloodshore.
SEQ_010	= 10;	-- Report to Hyllfyr aboard the Astalicia.

-- Quest Actors
HYLLFYR					= 1000215;	-- Captain of the Bloody Executioners
FYRILSKYF				= 1001681;	-- leads the foray
ALBIN					= 1001682;
TGIZZOH					= 1001683;
DENSTON					= 1001684;

-- The rest of the crew: each one's talk.
CREW = {
	[ALBIN]		= "processEventAlbin",
	[TGIZZOH]	= "processEventTGizzoh",
	[DENSTON]	= "processEventDenston",
};

-- Places
DEN						= {130, 1652.0, 0.0, -812.0, 3.14};	-- set down here, among the crew, when the kobolds fall

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 300;
COMPANY					= 1;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(HYLLFYR, QFLAG_TALK);
		return;
	end

	quest:SetENpc(HYLLFYR, sequence == SEQ_010 and QFLAG_REWARD or QFLAG_NONE);
	quest:SetENpc(FYRILSKYF, sequence == SEQ_000 and QFLAG_TALK or QFLAG_NONE);
	for classId in pairs(CREW) do
		quest:SetENpc(classId);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();

	if (classId == HYLLFYR and sequence == SEQ_ACCEPT) then
		-- restless pirates, and a farm the kobolds are stripping
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == HYLLFYR and sequence == SEQ_000) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == HYLLFYR and sequence == SEQ_010) then
		-- not all bad, for a 'Cuda in disguise
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == FYRILSKYF) then
		-- the time for idle chatter is past
		callClientFunction(player, "delegateEvent", player, quest, "processEventFyrilskyf");
		if (sequence == SEQ_000 and player:GetDirector() == nil) then
			startGcl302Content(player, quest);
			return;
		end
	elseif (CREW[classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, CREW[classId]);
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The kobolds, a duty entered in place (spawnType 0x16). Its director
-- (QuestDirectorGcl30201) sets you back down among the crew once they fall.
function startGcl302Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcl30201", "SimpleContentGcl30201", "Quest/SimpleQuestBattle/QuestDirectorGcl30201");
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
