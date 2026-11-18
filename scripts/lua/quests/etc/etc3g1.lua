require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Scrubbing the Soul
Code: 	Etc3g1
Id: 	110735
Prereq: Level 15, any class

The conjurers mean to hold a rite of cleansing, and the botanist
Mestonnaux at Greatloam Growery asks you to carry word of it to the
town's guilds: Biddy (conjurers), Tatagoi, Alaire (archers), Nuala (Wood
Wailers) and Nellaure. Nuala gives you a message for him: a tree south of
Camp Bentbranch has been scarred. Mestonnaux sends you there; stepping
into the glade starts the fight (SimpleContentEtc3g101, the client's
SimpleQuestBattle QuestDirectorEtc3g101) with imperial soldiers. Bardo
and Yayatu of the Garlond Ironworks were hiding nearby; Bardo tells you
Garlean blades cut the tree. Report to Mestonnaux. Reward 7,500 gil,
Dodoskin Ringbands and 500 experience (ZAM).

Biddy had no open-world spawn (only man0g1's echo); she stands at
Stillglade Fane beside Kinborow. Yayatu had no spawn or class script;
she and Bardo stand south of Camp Bentbranch (open world, visible to
everyone). The text calls the archer "Araire"; the client's NPC is Alaire.

Client script etc3g1: processEventMestonnauxStart (offer),
processEvent000_2 (Mestonnaux while you spread the word),
processEvent<Guild> / <Guild>_2 (the guilds, and after),
processEvent010 (Mestonnaux: the tree), processEvent010_2 (Mestonnaux
while you go), processEvent015 (Bardo), processEventYayatu,
processEvent020 (the reward). Journal steps 251-256.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Carry word of the rite to the guilds.
SEQ_005	= 5;	-- Bring Nuala's message to Mestonnaux.
SEQ_010	= 10;	-- Find the scarred tree south of Camp Bentbranch.
SEQ_015	= 15;	-- Speak with the two you saved.
SEQ_020	= 20;	-- Report back to Mestonnaux.

-- Actor Class Ids
ENPC_MESTONNAUX		= 1001103;
ENPC_BIDDY			= 1000737;
ENPC_TATAGOI		= 1001080;
ENPC_ALAIRE			= 1000831;
ENPC_NUALA			= 1000681;
ENPC_NELLAURE		= 1000821;
ENPC_BARDO			= 1001580;
ENPC_YAYATU			= 1001581;
TREE_TRIGGER		= 1090604;

-- The guilds: class id -> quest flag, first event, follow-up event, marker.
GUILDS = {
	[ENPC_BIDDY]	= {0, "processEventBiddy",		"processEventBiddy_2",		11073501},
	[ENPC_TATAGOI]	= {1, "processEventTatagoi",	"processEventTatagoi_2",	11073502},
	[ENPC_ALAIRE]	= {2, "processEventAraire",		"processEventAraire_2",		11073503},
	[ENPC_NUALA]	= {3, "processEventNuala",		"processEventNuala_2",		11073504},
	[ENPC_NELLAURE]	= {4, "processEventNellaure",	"processEventNellaure_2",	11073505},
};
GUILD_ORDER = {ENPC_BIDDY, ENPC_TATAGOI, ENPC_ALAIRE, ENPC_NUALA, ENPC_NELLAURE};

-- Quest Markers
MRKR_MESTONNAUX		= 11073506;
MRKR_TREE			= 11073507;
MRKR_BARDO			= 11073508;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {150, 270.0, 4.03, -380.0, 0.0};

-- Rewards
REWARD_EXP			= 500;
REWARD_GIL			= 7500;
REWARD_RINGBANDS	= 8071201;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_MESTONNAUX, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_MESTONNAUX);
		for classId, g in pairs(GUILDS) do
			quest:SetENpc(classId, data:GetFlag(g[1]) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_MESTONNAUX, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_MESTONNAUX);
		quest:SetENpc(TREE_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_MESTONNAUX);
		quest:SetENpc(ENPC_YAYATU);
		quest:SetENpc(ENPC_BARDO, QFLAG_TALK);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(ENPC_MESTONNAUX, QFLAG_REWARD);
		quest:SetENpc(ENPC_YAYATU);
		quest:SetENpc(ENPC_BARDO);
	end
end

function allToldOfRite(data)
	for _, g in pairs(GUILDS) do
		if (not data:GetFlag(g[1])) then
			return false;
		end
	end
	return true;
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == ENPC_MESTONNAUX) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMestonnauxStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	local guild = GUILDS[classId];
	if (seq == SEQ_000 and guild ~= nil) then
		if (not data:GetFlag(guild[1])) then
			callClientFunction(player, "delegateEvent", player, quest, guild[2]);
			data:SetFlag(guild[1]);
			if (allToldOfRite(data)) then
				attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
				player:EndEvent();
				quest:StartSequence(SEQ_005);
				return;
			end
		else
			callClientFunction(player, "delegateEvent", player, quest, guild[3]);
		end
	elseif (classId == ENPC_MESTONNAUX) then
		if (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		elseif (seq == SEQ_005) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			player:EndEvent();
			quest:StartSequence(SEQ_010);
			return;
		elseif (seq == SEQ_010 or seq == SEQ_015) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		elseif (seq == SEQ_020) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
			player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(REWARD_GIL);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_RINGBANDS, 1, 1);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	elseif (classId == ENPC_BARDO and (seq == SEQ_015 or seq == SEQ_020)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		if (seq == SEQ_015) then
			player:EndEvent();
			quest:StartSequence(SEQ_020);
			return;
		end
	elseif (classId == ENPC_YAYATU and (seq == SEQ_015 or seq == SEQ_020)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventYayatu");
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_010 and npc:GetActorClassId() == TREE_TRIGGER) then
		questBattle.start(player, "Etc3g101", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc3g101, once the soldiers are down.
function winEtc3g1Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_015);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc3g101, on a loss.
function loseEtc3g1Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	local data = quest:GetData();
	local markers = {};
	if (seq == SEQ_000) then
		for _, classId in ipairs(GUILD_ORDER) do
			local g = GUILDS[classId];
			if (not data:GetFlag(g[1])) then
				table.insert(markers, g[4]);
			end
		end
	elseif (seq == SEQ_005 or seq == SEQ_020) then
		table.insert(markers, MRKR_MESTONNAUX);
	elseif (seq == SEQ_010) then
		table.insert(markers, MRKR_TREE);
	elseif (seq == SEQ_015) then
		table.insert(markers, MRKR_BARDO);
	end
	return unpack(markers);
end
