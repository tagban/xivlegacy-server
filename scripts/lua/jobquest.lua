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
