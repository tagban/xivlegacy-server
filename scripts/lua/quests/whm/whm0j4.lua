require ("global")
require ("quest")
require ("questbattle")
require ("jobquest")

--[[

Quest Script

Name:	The Wheel of Disaster
Code:	Whm0j4
Id:		111244
Prereq: Whm0j3, White Mage 45

Raya-O-Senna tells of the Fifth Astral Era and its flood, and fears the
same end is coming. A bandit and his men prey on travelers at the land
bridge south of Camp Bearded Rock, likely under the elementals' sway; free
them (processEventStart). Walking onto the bridge starts the fight
(SimpleContentWhm0j401). With the bandits freed, Oha-Sok leaves you a
warning (processEventNQ cutscene, processEventLS); back at the cave Raya-O
hears it all (processEventClear).

The bandits' own battle class isn't known; bandit spearmen stand in.

]]

local SEQ_000	= 0;	-- Free the bandits at the land bridge south of Camp Bearded Rock.
local SEQ_010	= 10;	-- Return to Raya-O-Senna.

local ENPC_RAYA_O_SENNA	= 1001570;
local BRIDGE_TRIGGER	= 1090923;

local FIGHT = { 128, 45.0, 46.0, 155.0, 0.0 };

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_RAYA_O_SENNA);
		quest:SetENpc(BRIDGE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_RAYA_O_SENNA, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local seq = quest:GetSequence();
	if (npc.GetActorClassId() == ENPC_RAYA_O_SENNA) then
		if (seq == SEQ_ACCEPT) then
			-- The Fifth Astral Era, and the bandits (1 = accepted).
			if (callClientFunction(player, "delegateEvent", player, quest, "processEventStart") == 1) then
				player:AcceptQuest(quest);
			end
		elseif (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventRyaoAfter");
		elseif (seq == SEQ_010) then
			-- Oha-Sok's warning, and new white magic.
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			player:CompleteQuest(quest);
		end
	end
	player:EndEvent();
end

function onPush(player, quest, npc)
	if (quest:GetSequence() == SEQ_000 and npc:GetActorClassId() == BRIDGE_TRIGGER) then
		questBattle.start(player, "Whm0j401", FIGHT, "Quest/SimpleQuestBattle/QuestDirectorWar0j101");
		return;
	end
	player:EndEvent();
end

-- The bandits are freed; Oha-Sok's warning.
jobQuest.registerFight(111244, SEQ_000, function(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "processEventNQ");
	callClientFunction(player, "delegateEvent", player, quest, "processEventLS");
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end);

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
