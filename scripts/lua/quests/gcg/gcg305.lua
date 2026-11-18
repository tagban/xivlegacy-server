require ("global")
require ("quest")

--[[

Quest Script

Name: 	A Taste for Death
Code: 	Gcg305
Id: 	111626
Prereq: Level 50, a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

The elementals warned Brother Telent that "they who devour death shall come
to smother the land", and now a team of botanists has vanished in the South
Shroud, the bowmaker Dodowani among them. Zuzupoja of the Oak Atrium sends
you to the clearing west of the Thousand Maws of Toto-Rak, where they were
last heard from. You find no botanists there, only a swarm of shriekers,
and after the fight the Yellow Serpents. Their high commander, Quinquerol
Flutaint, came to investigate the "devourers of death" himself, and pays
you for your trouble.

The client script (gcg305) names the events; seed 166 holds the shriekers
and the three Yellow Serpents at the clearing.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Slay the shriekers in the clearing west of Toto-Rak.
SEQ_010	= 10;	-- Speak with the Yellow Serpents.

-- Quest Actors
ZUZUPOJA				= 1000701;
FLUTAINT				= 1001809;	-- High Commander Quinquerol Flutaint
VEVINA					= 1001808;	-- Serpent Commander Vevina Yarborough
TALL_OAK				= 1001807;	-- Serpent Captain Tall Oak
SHRIEKER				= 2105909;

-- The Serpents' second spawns stand at the clearing; the others belong to other quests
CLEARING_ZONE			= 154;

-- Counters
COUNTER_SHRIEKERS		= 0;
SHRIEKERS_NEEDED		= 6;

-- Rewards (the client's reward sheet row: EXP tier 6 in slot 1, seals in slot 5)
REWARD_EXP				= 1322;
REWARD_SEALS			= 700;
COMPANY					= 2;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ZUZUPOJA, QFLAG_TALK);
		return;
	end

	quest:SetENpc(ZUZUPOJA);
	if (sequence == SEQ_010) then
		quest:SetENpc(FLUTAINT, QFLAG_REWARD);
		quest:SetENpc(VEVINA);
		quest:SetENpc(TALL_OAK);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:GetSequence();
	local classId = npc:GetActorClassId();
	local atClearing = player:GetZoneID() == CLEARING_ZONE;

	if (classId == ZUZUPOJA and sequence == SEQ_ACCEPT) then
		-- Brother Telent's warning, and the missing botanists
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (classId == ZUZUPOJA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (classId == FLUTAINT and atClearing and sequence == SEQ_010) then
		-- the shriekers that feed on death, and the Flutaint tracker
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == VEVINA and atClearing and sequence == SEQ_010) then
		-- her commander, and his power to command
		callClientFunction(player, "delegateEvent", player, quest, "processEventVevina");
	elseif (classId == TALL_OAK and atClearing and sequence == SEQ_010) then
		-- the fine show you put on
		callClientFunction(player, "delegateEvent", player, quest, "processEventTall");
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onKillBNpc(player, quest, bnpc)
	if (quest:GetSequence() ~= SEQ_000 or bnpc ~= SHRIEKER) then
		return;
	end
	-- the counter reads back stale within this hook: count this kill by hand
	local killed = quest:GetData():GetCounter(COUNTER_SHRIEKERS) + 1;
	quest:GetData():IncCounter(COUNTER_SHRIEKERS);
	if (killed >= SHRIEKERS_NEEDED) then
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_010);
	end
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
