require ("global")
require ("quest")
require ("quests/spl/allsaints")

--[[

Quest Script

Name: 	Impish Impositions
Code: 	Spl0i2
Id: 	110800
Prereq: none. Seasonal: All Saints' Wake (settings/events.toml).

An Adventurers' Guild runner in costume (Ursielle in Limsa Lominsa, Mudede
in Gridania, Yvane in Ul'dah) explains that imps escaped while their wardens
kept All Saints' Wake indoors, and now hide among the townsfolk at night,
challenging the guild to riddles. Unmask the imps, answer their riddles for
Pumpkin Cookies, and trade the cookies at any runner for a pumpkin head;
the first trade completes the quest. Trading goes on afterwards
(quests/spl/allsaints.lua, allSaintsRunnerTalk).

]]

SEQ_000	= 0;	-- Outwit the imps, trade cookies at a runner.

local S = ALLSAINTS;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	for runner in pairs(S.RUNNERS) do
		quest:SetENpc(runner, (sequence == SEQ_ACCEPT) and QFLAG_TALK or QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc, eventName)
	local runner = S.RUNNERS[npc:GetActorClassId()];
	if (runner == nil) then
		player:EndEvent();
		return;
	end

	if (quest:GetSequence() == SEQ_ACCEPT) then
		if (IsSeasonalQuestOpen(SPL0I2_ID)
			and callClientFunction(player, "delegateEvent", player, quest, runner.offer) == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end

	allSaintsExchange(player, quest, runner.city, function()
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", S.SPL0I2_EXP, 1, 1);
		player:CompleteQuest(quest);
	end);
	quest:UpdateENPCs();
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
