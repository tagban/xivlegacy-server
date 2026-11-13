require ("global")
require ("quest")
require ("questbattle")
require ("allyfight")

--[[

Quest Script

Name: 	Blood Price
Code: 	Etc2i2
Id: 	110708
Prereq: Level 45, Disciples of War or Magic

Foxe of Owl's Nest (Coerthas Eastern Lowlands) says the Lambs of Dalamud,
a moon cult, took his wife to the stone circle Gwyr-Aen, and the cult only
holds its rites at night. The client calls him "ROGER" in its event names
(processEventROGERStart). At the ??? by day you find only bloodstained
stones (processEventdaytime). By night the cultists come up behind you
(processEvent000, processEventBeloreBattle): four Lunatic Lambs and the
Lunatic Shepherd (Gamer Escape, "Blood Price"), fought in the client's
SimpleQuestBattle QuestDirectorEtc2i201, here two Lambs at a time and
then the Shepherd. Back at Owl's Nest, Foxe turns out to be one of them
(processEvent010). 5,340 exp.

Gwyr-Aen really lies far north, on the Sea of Clouds past the cavern east
of Camp Dragonhead, but no map grid for it is known, so (the user's call,
2026-11-13) its ??? stands just outside Owl's Nest, south of the gate.

Client script etc2i2, text sheet 4835.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Look for Foxe's wife at Gwyr-Aen, by night.
SEQ_010	= 10;	-- Return to Foxe.

-- Actor Class Ids
FOXE		= 1001839;
GWYR_AEN	= 1091002;	-- the ??? (name 4000257) at the stone circle

-- The fight: battle npcs 3478-3481 (Lunatic Lambs, two at a time), then
-- 3482 (the Lunatic Shepherd). Spots: zone, x, y, z, rotation.
GWYR_AEN_FIGHT_SPOT	= {145, 2525.0, 173.8, 1262.0, 3.14};
GWYR_AEN_LEAVE_SPOT	= {145, 2532.0, 174.08, 1266.0, 3.14};
ETC2I2_FIGHT = {
	allies = {},
	waves = { { 3478, 3479 }, { 3480, 3481 }, { 3482 } },
	limitSeconds = 20 * 60,
	winSignal = "allyFightWon",
};

-- Night at Gwyr-Aen: Eorzean hours 18:00-5:59. One Eorzean hour is 175
-- real seconds (the client's clock).
NIGHT_FROM	= 18;
NIGHT_UNTIL	= 6;

-- Rewards (client reward row: 5,340 exp)
REWARD_EXP	= 5340;

function eorzeaHour()
	return math.floor(os.time() / 175) % 24;
end

function isNightAtGwyrAen()
	local hour = eorzeaHour();
	return hour >= NIGHT_FROM or hour < NIGHT_UNTIL;
end

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FOXE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(FOXE);
		quest:SetENpc(GWYR_AEN, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(GWYR_AEN);
		quest:SetENpc(FOXE, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == FOXE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventROGERStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000) then
		if (classId == FOXE) then
			-- "Save my wife!" and the way to Gwyr-Aen.
			callClientFunction(player, "delegateEvent", player, quest, "processEventdefault_1");
		elseif (classId == GWYR_AEN) then
			if (not isNightAtGwyrAen()) then
				-- Nothing out of the ordinary, save the stained stones.
				callClientFunction(player, "delegateEvent", player, quest, "processEventdaytime");
			else
				-- A rustling behind you: the Lambs, and the Shepherd's boast.
				callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
				callClientFunction(player, "delegateEvent", player, quest, "processEventBeloreBattle");
				questBattle.start(player, "Etc2i201", GWYR_AEN_FIGHT_SPOT);
				return;
			end
		end
	elseif (seq == SEQ_010 and classId == FOXE) then
		-- Foxe is one of them, and his wife went willingly.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	player:EndEvent();
end

-- QuestDirectorEtc2i201, once the Shepherd is down: out of the duty, by
-- the stones.
function winEtc2i2Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_010);
	player:EndEvent();
	questBattle.leave(player, GWYR_AEN_LEAVE_SPOT);
end

-- SimpleContentEtc2i201, on a loss: set down by the stones to try again.
function loseEtc2i2Fight(player, area, why)
	area:ContentFinished();
	questBattle.warp(player, GWYR_AEN_LEAVE_SPOT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	return;
end
