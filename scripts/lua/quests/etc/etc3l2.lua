require ("global")
require ("quest")
require ("questbattle")

--[[

Quest Script

Name: 	Shot Through the Heart
Code: 	Etc3l2
Id: 	110745
Prereq: Level 21, any class

Mynadaeg of the Knights of the Barracuda wants proof that the Bloody
Executioners sank the galley Braveheart, and sends you to comb the
coastline east of Cassiopeia Hollow for wreckage. Stepping onto the beach
starts the fight (SimpleContentEtc3l201, the client's SimpleQuestBattle
QuestDirectorEtc3l201). Then you meet Malin of the Barracudas: the pirates
stripped the beach, but she kept a holster with a fine firearm (key item
11000203). Speak with her again and the Echo shows you the Braveheart's
last hours and Admiral Merlwyb facing down Hyllfyr (cutscene etc3l210).
Malin is gone when the vision ends, her firearm left behind. Bring it to
Mynadaeg in the Coral Tower. Reward 10,000 gil (the client's reward table,
data/01/03/05/61.DAT); the table gives the experience only as a rank, so
that amount is an estimate.

The beach's foes are not named in the client's scripts; the fight uses
the client's bandit classes. Malin stands on the beach (open world,
visible to everyone); she is hidden from you once she has gone.

Client script etc3l2: processEventMynadaegStart (offer), processEvent000
(Mynadaeg while you search), processEvent010 (Malin and her holster),
processEvent010_2 (Malin's confession; returns 1 when you answer her),
processEvent010_3 (the Echo), processEvent015 (the reward). Journal steps
232-238.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Comb the beach east of Cassiopeia Hollow.
SEQ_005	= 5;	-- Speak with the Barracuda on the beach.
SEQ_007	= 7;	-- Speak with Malin again.
SEQ_010	= 10;	-- Bring the firearm to Mynadaeg.

-- Actor Class Ids
ENPC_MYNADAEG		= 1000130;
ENPC_MALIN			= 1001634;
BEACH_TRIGGER		= 1090610;

-- Key Items
ITEM_FIREARM		= 11000203;

-- Quest Markers
MRKR_BEACH			= 11074501;
MRKR_MALIN			= 11074502;
MRKR_MYNADAEG		= 11074503;

-- Places: the fight, and where a win or a loss sets you down (outside the
-- trigger circle).
FIGHT				= {130, 1305.0, 1.32, -758.0, 3.14};

-- Rewards
REWARD_EXP			= 1500;
REWARD_GIL			= 10000;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_MYNADAEG, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(BEACH_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(ENPC_MYNADAEG);
	elseif (sequence == SEQ_005 or sequence == SEQ_007) then
		quest:SetENpc(ENPC_MALIN, QFLAG_TALK);
		quest:SetENpc(ENPC_MYNADAEG);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(ENPC_MYNADAEG, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local seq = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (seq == SEQ_ACCEPT and classId == ENPC_MYNADAEG) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventMynadaegStart");
		if (accepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	elseif (classId == ENPC_MYNADAEG and seq ~= SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000");
	elseif (classId == ENPC_MYNADAEG and seq == SEQ_010) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(ITEM_FIREARM, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddGil(REWARD_GIL);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	elseif (classId == ENPC_MALIN and seq == SEQ_005) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(ITEM_FIREARM, 1, 1);
		player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, ITEM_FIREARM, 1); -- You obtain <item>.
		player:EndEvent();
		quest:StartSequence(SEQ_007);
		return;
	elseif (classId == ENPC_MALIN and seq == SEQ_007) then
		local answered = callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		if (answered == 1) then
			-- The Echo ends fadeInAfterWarp: a same-zone warp lifts the veil.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3");
			attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
			player:EndEvent();
			quest:StartSequence(SEQ_010);
			GetWorldManager():DoZoneChange(player, player:GetZoneID(), nil, 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation);
			-- After the warp: its zone-in would send the NPC again.
			player:HideActor(npc.Id);
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	if (quest:getSequence() == SEQ_000 and npc:GetActorClassId() == BEACH_TRIGGER) then
		questBattle.start(player, "Etc3l201", FIGHT);
		return;
	end
	player:EndEvent();
end

-- QuestDirectorEtc3l201, once the beach is clear.
function winEtc3l2Fight(player, quest)
	attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	quest:StartSequence(SEQ_005);
	player:EndEvent();
	questBattle.leave(player, FIGHT);
end

-- SimpleContentEtc3l201, on a loss.
function loseEtc3l2Fight(player, timedOut)
	questBattle.leave(player, FIGHT);
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
	local seq = quest:getSequence();
	if (seq == SEQ_000) then
		return MRKR_BEACH;
	elseif (seq == SEQ_005 or seq == SEQ_007) then
		return MRKR_MALIN;
	elseif (seq == SEQ_010) then
		return MRKR_MYNADAEG;
	end
end
