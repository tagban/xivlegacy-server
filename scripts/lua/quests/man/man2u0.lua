require ("global")
require ("quest")

--[[

Quest Script

Name: 	Calamity Cometh
Code: 	Man2u0
Id: 	110012
Prereq: Golden Sacrifices (Man1u0 - 110011), Level 13

Rebuilt from the client's own man2u0 script, journal and dialogue sheets.
The minemite battle after the coach ride is a duty this server can't run
yet, so it is skipped: walking onto the battlefield plays its closing
scene. Every cutscene that ends with startFadeInCutSceneAfterWarp is
followed by its own warp: two such scenes back to back with one warp
after them leave the player unable to move.

]]

-- Sequence Numbers
SEQ_000	= 0;  	-- Ask after the city guard at the chocobo stables.
SEQ_005	= 5;  	-- The minemites (battle skipped): onto the battlefield.
SEQ_010	= 10;  	-- Visit F'lhaminn at the Phrontistery.
SEQ_015	= 15;  	-- Find her sickroom (echo).
SEQ_020	= 20;  	-- Leave the Phrontistery.
SEQ_025	= 25;	-- Talk to Momodi on the LS.
SEQ_030	= 30;	-- Go to Camp Black Brush.
SEQ_035	= 35;	-- Follow Thancred to Arrzaneth Ossuary.
SEQ_040	= 40;	-- Speak to Thancred at the Ossuary.
SEQ_045	= 45;	-- Speak to Momodi.

-- Actor Class Ids
MOMODI						= 1000841;
RURURAJI					= 1000840;

-- Where the coach caught Corguevais, outside Ul'dah's north wall
BATTLEFIELD_TRIGGER			= 1090292;

-- Frondale's Phrontistery and the sickroom (PrivateAreaMasterPast 5). The
-- sickroom scene returns you to the hall spot you arrived at, a few steps
-- short of the trigger.
PHRONTISTERY_TRIGGER		= 1090289;
FLHAMINN					= 1000842;
NIELLEFRESNE				= 1000037;
GREINFARR					= 1000039;

-- Camp Black Brush and Arrzaneth Ossuary
BLACKBRUSH_TRIGGER			= 1090290;
OSSUARY_PLAZA_TRIGGER		= 1090291;
THANCRED					= 1000948;

-- Warp spots: zone, private area type (nil = none), x, y, z, rotation
BATTLEFIELD					= {175, nil, -147.0, 205.0, -163.0, 1.57};
PHRONTISTERY_DOOR			= {209, nil, -212.0, 229.6, 284.0, 0.6};
SICKROOM					= {209, 5, -218.0, 229.5, 306.0, 0.6};
OSSUARY_PLAZA				= {209, nil, -258.0, 202.0, 203.0, 0.8};
QUICKSAND					= {175, nil, -75.242, 195.009, 74.572, -0.046};

-- Msg pack for the Npc LS (Momodi)
NPCLS_MSGS = {
	{72, 73}				-- SEQ_025: an exile near Camp Black Brush
};
MOMODI_DISPLAY_ID = 1500014;

-- Quest Markers
MRKR_RURURAJI			= 11001201;
MRKR_PHRONTISTERY		= 11001202;
MRKR_BATTLEFIELD		= 11001203;
MRKR_OSSUARY			= 11001206;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(MOMODI, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(RURURAJI, QFLAG_TALK);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(BATTLEFIELD_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(PHRONTISTERY_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(NIELLEFRESNE, QFLAG_TALK);
		quest:SetENpc(FLHAMINN);
		quest:SetENpc(GREINFARR);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(PHRONTISTERY_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(BLACKBRUSH_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_035) then
		quest:SetENpc(OSSUARY_PLAZA_TRIGGER, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_040) then
		quest:SetENpc(THANCRED, QFLAG_TALK);
	elseif (sequence == SEQ_045) then
		quest:SetENpc(MOMODI, QFLAG_REWARD);
	end
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_ACCEPT) then
		if (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventMomodiStart");
			player:EndEvent();
			player:AcceptQuest(quest, true);
			return;
		end
	elseif (sequence == SEQ_000) then
		if (classId == RURURAJI) then
			-- The coach after Corguevais, and the minemites he calls up
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005");
			player:EndEvent();
			quest:StartSequence(SEQ_005);
			warpTo(player, BATTLEFIELD);
			return;
		elseif (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		end
	elseif (sequence == SEQ_015) then
		if (classId == NIELLEFRESNE) then
			-- Corguevais the spy? A threat worse than the Empire? Find Thancred.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			player:EndEvent();
			quest:StartSequence(SEQ_020);
			warpTo(player, PHRONTISTERY_DOOR);
			return;
		end
	elseif (sequence == SEQ_030) then
		if (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2");
		end
	elseif (sequence == SEQ_040) then
		if (classId == THANCRED) then
			-- Niellefresne's murder in the Echo, the meteors, and waking in
			-- Ul'dah with Momodi.
			callClientFunction(player, "delegateEvent", player, quest, "processEvent085");
			player:EndEvent();
			quest:StartSequence(SEQ_045);
			warpTo(player, QUICKSAND);
			return;
		end
	elseif (sequence == SEQ_045) then
		if (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 500, 1, 1, 2);
			-- Completion reward from the client's quest reward sheet: 500 EXP + 30,000 gil.
			player:AddExp(500, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(30000);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_005 and classId == BATTLEFIELD_TRIGGER) then
		-- The minemites beaten; F'lhaminn hurt and taken to the Phrontistery
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		player:EndEvent();
		quest:StartSequence(SEQ_010);
		warpTo(player, PHRONTISTERY_DOOR);
		return;
	elseif (sequence == SEQ_010 and classId == PHRONTISTERY_TRIGGER) then
		-- Damielliot greets you, then excuses himself
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		player:EndEvent();
		quest:StartSequence(SEQ_015);
		warpTo(player, SICKROOM);
		return;
	elseif (sequence == SEQ_020 and classId == PHRONTISTERY_TRIGGER) then
		-- Damielliot collapses in the corridor
		callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
		quest:NewNpcLsMsg(1);
		quest:StartSequence(SEQ_025);
	elseif (sequence == SEQ_030 and classId == BLACKBRUSH_TRIGGER) then
		-- Qoqoba, and Greinfarr with the captured Thancred
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		quest:StartSequence(SEQ_035);
	elseif (sequence == SEQ_035 and classId == OSSUARY_PLAZA_TRIGGER) then
		-- Thancred and F'lhaminn find Niellefresne dying in the crypt
		callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
		player:EndEvent();
		quest:StartSequence(SEQ_040);
		warpTo(player, OSSUARY_PLAZA);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:getSequence();

	if (from == 1 and (sequence == SEQ_025 or sequence == SEQ_030)) then
		player:SendGameMessageLocalizedDisplayName(quest, NPCLS_MSGS[1][msgStep], MESSAGE_TYPE_NPC_LINKSHELL, MOMODI_DISPLAY_ID);
		if (msgStep >= #NPCLS_MSGS[1]) then
			quest:EndOfNpcLsMsgs();
		else
			quest:ReadNpcLsMsg();
		end
		if (sequence == SEQ_025) then
			quest:StartSequenceForNpcLs(SEQ_030);
		end
	end

	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:getSequence();

	if (sequence == SEQ_000) then
		return MRKR_RURURAJI;
	elseif (sequence == SEQ_005) then
		return MRKR_BATTLEFIELD;
	elseif (sequence == SEQ_010 or sequence == SEQ_020) then
		return MRKR_PHRONTISTERY;
	elseif (sequence == SEQ_035 or sequence == SEQ_040) then
		return MRKR_OSSUARY;
	end
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], spot[2] and "PrivateAreaMasterPast" or nil, spot[2] or 0, 15, spot[3], spot[4], spot[5], spot[6]);
end
