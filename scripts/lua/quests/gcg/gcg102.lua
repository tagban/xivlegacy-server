require ("global")
require ("quest")

--[[

Quest Script

Name: 	Two Vans are Better than One
Code: 	Gcg102
Id: 	111627
Prereq: It Kills with Fire (Gcg101), a sworn member of the Order of the Twin Adder (company_gate in quest_offers.rs).

Arthur has gone to meet an Ala Mhigan informant, Pfrymloef, with a Yellow
Serpent escort, and Kan-E-Senna has heard ill whispers from the elementals.
Fulke sends you to the Toto-Moy Battlewarrens, south-west of Camp Nine Ivies.
You find them all felled by a Garlean gas attack. High Commander Flutaint
(Quinquerol in the client) hands you his mist emitter, and the Garleans come
back (a duty entered in place, SimpleContentGcg10201). Once they fall, the
Echo shows you Pfrymloef's memory of Nael van Darnus and Gaius van Baelsar
speaking of Meteor (cutscene gc01g210). Flutaint sends you to Cid at the
Gridania airship landing, who explains the Empire's Meteor project.

The client script (gcg102) names the events; seed 144 holds the cast and the
Garleans. The client's "Vevina" talks belong to Serpent Commander Yarborough,
the one Yellow Serpent officer beside Tall Oak with no other role.

]]

-- Sequence Numbers
SEQ_000	= 0;	-- Find Arthur at the Toto-Moy Battlewarrens.
SEQ_010	= 10;	-- See how Arthur and his companions are faring.
SEQ_020	= 20;	-- Speak to the others about what the Echo showed.
SEQ_030	= 30;	-- Find Cid at the Gridania airship landing.
SEQ_040	= 40;	-- Tell Cid what you have learned.

-- Quest Actors
FULKE					= 1500200;
ARTHUR					= 1001734;
TALLOAK					= 1001807;	-- Serpent Captain Tall Oak
VEVINA					= 1001808;	-- Serpent Commander Yarborough
QUINQUEROL				= 1001809;	-- High Commander Flutaint
PFRYMLOEF				= 1001812;
CID						= 1001572;
EBRELNAUX				= 1060011;
BARDO					= 1001580;

-- Places
BATTLEWARRENS			= {151, 1635.0, 64.0, -604.4, 3.14};

-- Key items
MIST_EMITTER			= 11000422;

-- Rewards (the client's reward sheet row: EXP tier 7 in slot 1, seals in slot 5)
REWARD_EXP				= 1541;
REWARD_SEALS			= 1000;
COMPANY					= 2;

-- The Yellow Serpents' talks at the Battlewarrens, by sequence.
SERPENTS = {
	[SEQ_000] = { [ARTHUR] = "processEventArthur", [TALLOAK] = "processEventTalloak01",
		[VEVINA] = "processEventVevina01", [PFRYMLOEF] = "processEventPfrymloef" },
	[SEQ_010] = { [ARTHUR] = "processEventArthurNQF", [TALLOAK] = "processEventTalloak02",
		[VEVINA] = "processEventVevina02", [QUINQUEROL] = "processEventQuinquerolNQF" },
	[SEQ_020] = { [ARTHUR] = "processEventArthurNQA", [TALLOAK] = "processEventTalloak04",
		[VEVINA] = "processEventVevina03", [PFRYMLOEF] = "processEventPfrymloefNQA" },
	[SEQ_030] = { [ARTHUR] = "processEventArthurNQA", [TALLOAK] = "processEventTalloak04",
		[VEVINA] = "processEventVevina03", [PFRYMLOEF] = "processEventPfrymloefNQA",
		[QUINQUEROL] = "processEventQuinquerolFragC" },
};

-- Quest flags
FLAG_ALLAG_ASKED		= 0;	-- Tall Oak's first word on Allag (Talloak03) heard

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FULKE, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(QUINQUEROL, QFLAG_TALK);
		quest:SetENpc(ARTHUR);
		quest:SetENpc(TALLOAK);
		quest:SetENpc(VEVINA);
		quest:SetENpc(PFRYMLOEF);
		quest:SetENpc(FULKE);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(PFRYMLOEF, QFLAG_TALK);
		quest:SetENpc(ARTHUR);
		quest:SetENpc(TALLOAK);
		quest:SetENpc(VEVINA);
		quest:SetENpc(QUINQUEROL);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(QUINQUEROL, QFLAG_TALK);
		quest:SetENpc(ARTHUR);
		quest:SetENpc(TALLOAK);
		quest:SetENpc(VEVINA);
		quest:SetENpc(PFRYMLOEF);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(EBRELNAUX, QFLAG_TALK);
		quest:SetENpc(CID);
		quest:SetENpc(BARDO);
		quest:SetENpc(ARTHUR);
		quest:SetENpc(TALLOAK);
		quest:SetENpc(VEVINA);
		quest:SetENpc(PFRYMLOEF);
		quest:SetENpc(QUINQUEROL);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(CID, QFLAG_REWARD);
		quest:SetENpc(EBRELNAUX);
		quest:SetENpc(BARDO);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT and classId == FULKE) then
		local accepted = callClientFunction(player, "delegateEvent", player, quest, "processEventStart");
		if (accepted == 1) then
			player:AcceptQuest(quest, true);
		end
	elseif (sequence == SEQ_000 and classId == FULKE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter");
	elseif (sequence == SEQ_000 and classId == QUINQUEROL and player:GetDirector() ~= nil) then
		-- already in the fight (the duty's director is the login director)
	elseif (sequence == SEQ_000 and classId == QUINQUEROL) then
		-- the gas attack, the mist emitter, and the Garleans' return
		callClientFunction(player, "delegateEvent", player, quest, "processEventQuinquerol");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(MIST_EMITTER, 1, 1);
		startGcg102Content(player, quest);
		return;
	elseif (sequence == SEQ_010 and classId == PFRYMLOEF) then
		-- the Echo: 1 sees into his past (Nael and Gaius, gc01g210)
		local echo = callClientFunction(player, "delegateEvent", player, quest, "processEventPfrymloefNQF");
		if (echo == 1) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventPfrymloefNQ");
			quest:StartSequence(SEQ_020);
		end
	elseif (sequence == SEQ_020 and classId == TALLOAK and not quest:GetData():GetFlag(FLAG_ALLAG_ASKED)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventTalloak03");
		quest:GetData():SetFlag(FLAG_ALLAG_ASKED);
	elseif (sequence == SEQ_020 and classId == QUINQUEROL) then
		-- what the Echo showed, and orders to find Cid
		callClientFunction(player, "delegateEvent", player, quest, "processEventQuinquerolNQA");
		quest:StartSequence(SEQ_030);
	elseif (SERPENTS[sequence] ~= nil and SERPENTS[sequence][classId] ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, SERPENTS[sequence][classId]);
	elseif (sequence == SEQ_030 and classId == EBRELNAUX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventEbrelnaux");
		quest:StartSequence(SEQ_040);
	elseif (sequence == SEQ_030 and classId == CID) then
		-- on his linkpearl: talk to someone else first
		callClientFunction(player, "delegateEvent", player, quest, "processEventCid");
	elseif (sequence == SEQ_030 and classId == BARDO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventBardo");
	elseif (sequence == SEQ_040 and classId == EBRELNAUX) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventEbrelnauxAfter");
	elseif (sequence == SEQ_040 and classId == BARDO) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventBardoAfter");
	elseif (sequence == SEQ_040 and classId == CID) then
		-- Meteor, the Allagan structure, and van Darnus
		callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
		callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1, 5);
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(MIST_EMITTER, 1);
		player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
		player:AddSeals(COMPANY, REWARD_SEALS);
		player:EndEvent();
		player:CompleteQuest(quest);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

-- The Garleans' return, a duty entered in place (spawnType 0x16). Its
-- director (QuestDirectorGcg10201) sets you back down among the Serpents
-- once they fall.
function startGcg102Content(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Gcg10201", "SimpleContentGcg10201", "Quest/QuestDirectorGcg10201");
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
