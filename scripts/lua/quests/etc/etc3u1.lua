require ("global")
require ("quest")
require ("questbattle")
require ("allyfight")

--[[

Quest Script

Name: 	Quid Pro Quo
Code: 	Etc3u1
Id: 	110726
Prereq: Level 15, Disciples of War or Magic

Brother Peneli Zuneli of Milvaneth Sacrarium hands you five talismans for
the Order's most generous donors. The client's script names them only by
letter (processEvent005_K/N/R/S/A); their lines and Gamer Escape's
walkthrough match them to Kukusi (the Phrontistery), Naida Zamaida (praying
on Sapphire Avenue), Rorojaru (the rich merchant), Singleton (a servant
whose master gives to the Order) and Abylgo Hamylgo (the Coliseum). Then
Peneli sends you to the airship wreck northwest of Ul'dah, where four
Unsavory Characters come at you two at a time (content SimpleContentEtc3u101,
the client's SimpleQuestBattle QuestDirectorEtc3u101). Nymiene, one of the
Ironworks engineers you saved, thanks you and takes them for Garlean agents
(processEvent020, a talk turn: it needs the NPC, so not from the director);
Aergfloh warns you not to linger (processEvent015_2). Peneli pays: an Ash
Mask, 7,500 gil and 500 exp (the client's reward row).

Client script etc3u1, text sheet 4339. Gamer Escape puts Nymiene at
Central Thanalan 22-29; the wreck is the bump in the client's collision
there.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Deliver the five talismans.
SEQ_010	= 10;	-- Clear the bandits from the airship wreck.
SEQ_015	= 15;	-- Talk to the engineers at the wreck.
SEQ_020	= 20;	-- Report to Peneli Zuneli.

-- Actor Class Ids
PENELI_ZUNELI		= 1001421;
KUKUSI				= 1001463;	-- K
NAIDA_ZAMAIDA		= 1000955;	-- N
RORORAJU			= 1000374;	-- R (Rorojaru)
SINGLETON			= 1001445;	-- S
ABYLGO_HAMYLGO		= 1000965;	-- A
NYMIENE				= 1001578;
AERGFLOH			= 1001579;
WRECK_TRIGGER		= 1091000;

-- The talisman recipients, in flag order, with their event letter.
RECIPIENTS = {
	{ classId = KUKUSI, letter = "K" },
	{ classId = NAIDA_ZAMAIDA, letter = "N" },
	{ classId = RORORAJU, letter = "R" },
	{ classId = SINGLETON, letter = "S" },
	{ classId = ABYLGO_HAMYLGO, letter = "A" },
};

-- The wreck fight: four Unsavory Characters, two at a time (battle npcs
-- 3474-3477). Spots: zone, x, y, z, rotation.
WRECK_FIGHT_SPOT	= {170, -428.0, 185.11, -136.0, 3.6};
WRECK_LEAVE_SPOT	= {170, -420.0, 184.7, -144.0, 3.6};
ETC3U1_FIGHT = {
	allies = {},
	waves = { { 3474, 3475 }, { 3476, 3477 } },
	limitSeconds = 20 * 60,
	winSignal = "allyFightWon",
};

-- Rewards (client reward row: 500 exp, 7,500 gil, an Ash Mask)
REWARD_EXP			= 500;
REWARD_GIL			= 7500;
REWARD_ASH_MASK		= 8090201;


function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

local function delivered(data)
	local n = 0;
	for i = 1, #RECIPIENTS do
		if (data:GetFlag(i - 1)) then n = n + 1 end
	end
	return n;
end

function onStateChange(player, quest, sequence)
	local data = quest:GetData();
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(PENELI_ZUNELI, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		local all = delivered(data) == #RECIPIENTS;
		quest:SetENpc(PENELI_ZUNELI, all and QFLAG_TALK or QFLAG_NONE);
		for i, r in ipairs(RECIPIENTS) do
			quest:SetENpc(r.classId, data:GetFlag(i - 1) and QFLAG_NONE or QFLAG_TALK);
		end
	elseif (sequence == SEQ_010) then
		quest:SetENpc(PENELI_ZUNELI);
		quest:SetENpc(WRECK_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(NYMIENE, QFLAG_TALK);
		quest:SetENpc(AERGFLOH);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(PENELI_ZUNELI, QFLAG_REWARD);
		quest:SetENpc(AERGFLOH);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();
	local data = quest:GetData();

	if (seq == SEQ_ACCEPT and classId == PENELI_ZUNELI) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventPeneliZuneliStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (seq == SEQ_000) then
		if (classId == PENELI_ZUNELI) then
			if (delivered(data) == #RECIPIENTS) then
				-- "You have a rueful look about you": the scavengers at the wreck.
				callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
				quest:StartSequence(SEQ_010);
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
			end
		else
			for i, r in ipairs(RECIPIENTS) do
				if (classId == r.classId) then
					if (data:GetFlag(i - 1)) then
						callClientFunction(player, "delegateEvent", player, quest, "processEvent005_" .. r.letter .. "_2");
					else
						callClientFunction(player, "delegateEvent", player, quest, "processEvent005_" .. r.letter);
						data:SetFlag(i - 1);
						if (delivered(data) == #RECIPIENTS) then
							attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
						end
					end
				end
			end
		end
	elseif (seq == SEQ_010 and classId == PENELI_ZUNELI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
	elseif (seq == SEQ_015 and classId == NYMIENE) then
		-- The engineers' thanks: Garlean agents, not common thieves.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		quest:StartSequence(SEQ_020);
	elseif ((seq == SEQ_015 or seq == SEQ_020) and classId == AERGFLOH) then
		-- "It would be unwise to linger here."
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015_2");
	elseif (seq == SEQ_020 and classId == PENELI_ZUNELI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent025");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:GetItemPackage(INVENTORY_NORMAL):AddItem(REWARD_ASH_MASK, 1, 1);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_010 and npc:GetActorClassId() == WRECK_TRIGGER) then
		questBattle.start(player, "Etc3u101", WRECK_FIGHT_SPOT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc3u101, once both pairs are down: out of the duty, by the
-- engineers.
function winEtc3u1Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_015);
	player:EndEvent();
	questBattle.leave(player, WRECK_LEAVE_SPOT);
end

-- SimpleContentEtc3u101, on a loss: set down by the wreck to try again.
function loseEtc3u1Fight(player, area, why)
	area:ContentFinished();
	questBattle.warp(player, WRECK_LEAVE_SPOT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	return;
end
