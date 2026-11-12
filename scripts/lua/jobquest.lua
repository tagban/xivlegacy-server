require ("global")
require ("quest")

--[[

Shared parts of the 1.23b job quests (War0j1-6, Mnk0j1-6, Whm0j1-6,
Blm0j1-6, Pld0j1-6, Brd0j1-6, Drg0j1-6).

Job 1 is offered on the job's class at level 30 with a second class at 15,
Jobs 2-6 only to the job itself (processor/quest_offers.rs job_gate; the
levels and the chain are in gamedata_quests). Job 1 ends with the soul
crystal, which goes in the job items (package 101): the gear window's
soul crystal slot then offers the job (ChangeJobCommand).

The client scripts show the soul crystal and each new job ability in
their own widgets (showGetJobItemWidget / showGetJobAbilityWidget); the
abilities themselves come with the job's level (server_battle_commands).

]]

jobQuest = {};

-- Soul crystals by job.
jobQuest.SOUL_CRYSTAL = {
	[15] = 2000202, -- monk
	[16] = 2000201, -- paladin
	[17] = 2000203, -- warrior
	[18] = 2000205, -- bard
	[19] = 2000204, -- dragoon
	[26] = 2000207, -- black mage
	[27] = 2000206, -- white mage
};

function jobQuest.giveSoulCrystal(player, jobId)
	local crystal = jobQuest.SOUL_CRYSTAL[jobId];
	if (crystal ~= nil) then
		player:GetItemPackage(INVENTORY_JOBITEMS):AddItem(crystal, 1, 1);
	end
end

-- Run a talk table: TALKS[sequence][npc class] = client function.
function jobQuest.chatter(player, quest, talks, seq, classId)
	if (talks[seq] ~= nil and talks[seq][classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, talks[seq][classId]);
		return true;
	end
	return false;
end

-- Put up a talk marker on every NPC with something to say in this step.
function jobQuest.chatterMarkers(quest, talks, seq)
	if (talks[seq] ~= nil) then
		for classId, _ in pairs(talks[seq]) do
			quest:SetENpc(classId);
		end
	end
end

-- Fights. A job quest fight runs as a SimpleQuestBattle duty
-- (questbattle.lua). Only some fights have their own client director
-- (War0j101, War0j301, Whm0j101, ...), so every job fight uses one of
-- those, and the director asks this table which fight the player is in:
-- jobQuest.fights[questId][sequence] = function(player, quest) run on a win.
-- jobquest_fights.lua loads every job quest script so the table is full.
jobQuest.fights = {};

function jobQuest.registerFight(questId, sequence, onWin)
	jobQuest.fights[questId] = jobQuest.fights[questId] or {};
	jobQuest.fights[questId][sequence] = onWin;
end

-- Each job quest's duty is named <Job>0j<N>01 (e.g. "Mnk0j601"); the
-- job's quest ids run from its base + 1 (quest 1) to base + 6 (quest 6).
jobQuest.QUEST_BASE = {
	War = 111200, Mnk = 111220, Whm = 111240, Blm = 111260,
	Pld = 111280, Brd = 111300, Drg = 111320,
};

-- The job quest a duty belongs to, from its content area name; nil when
-- the name isn't a job quest duty.
function jobQuest.questForDuty(areaName)
	if (areaName == nil) then return nil end
	local job, n = string.match(areaName, "^(%a%a%a)0j(%d)%d%d$");
	local base = job and jobQuest.QUEST_BASE[job];
	if (base == nil) then return nil end
	return base + tonumber(n);
end

-- Director side: hand the duty to questBattle with the current fight's win.
-- The win goes to the quest whose duty the player is in, not just any held
-- job quest at a fight step: two job quests can be at their fights at once.
function jobQuest.runFightDirector(player, actor)
	local areaName = player:GetContentAreaName();
	local questId = jobQuest.questForDuty(areaName);
	if (questId ~= nil) then
		local bySequence = jobQuest.fights[questId];
		if (bySequence ~= nil and player:HasQuest(questId)) then
			local onWin = bySequence[player:GetQuest(questId):GetSequence()];
			if (onWin ~= nil) then
				questBattle.runDirector(player, actor, questId, onWin);
				return;
			end
		end
	elseif (areaName == nil) then
		-- No duty name (shouldn't happen inside a duty): the first held
		-- quest at a fight step, as before.
		for id, bySequence in pairs(jobQuest.fights) do
			if (player:HasQuest(id)) then
				local onWin = bySequence[player:GetQuest(id):GetSequence()];
				if (onWin ~= nil) then
					questBattle.runDirector(player, actor, id, onWin);
					return;
				end
			end
		end
	end
	player:EndEvent();
end

-- The client's own ending for a job quest finished away from its NPC: the
-- "quest complete" notice, the new job ability, and the NPC linkpearl.
function jobQuest.completeAway(player, quest)
	callClientFunction(player, "delegateEvent", player, quest, "onJobQuestCompleteFirst");
	callClientFunction(player, "delegateEvent", player, quest, "onJobQuestCompleteSecond");
	callClientFunction(player, "delegateEvent", player, quest, "onJobQuestCompleteThird");
	player:CompleteQuest(quest);
end
