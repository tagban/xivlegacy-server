require ("global")
require ("quest")

--[[

Quest Script

Name: 	Golden Sacrifices
Code: 	Man1u0
Id: 	110011
Prereq: Court in the Sands (Man0u1 - 110010), Level 8

Rebuilt from the client's own man1u0 script, journal and dialogue sheets:
one sequence per journal step. Every cutscene that ends with
startFadeInCutSceneAfterWarp is followed by a warp, or the client waits on
the loading screen.

]]

-- Sequence Numbers
SEQ_000	= 0;  	-- Hear the rumors at the Quicksand; Momodi has work.
SEQ_005	= 5;  	-- Ask Gagaruna at the Platinum Mirage.
SEQ_010	= 10;  	-- Go through the door at the foot of the stairs.
SEQ_015	= 15;  	-- Speak to Thancred in Paradise (echo).
SEQ_020	= 20;  	-- Talk to Momodi on the LS.
SEQ_025	= 25;	-- Find F'lhaminn through Deaustie at Sunsilk Tapestries.
SEQ_030	= 30;	-- Go to F'lhaminn's rehearsal spot.
SEQ_035	= 35;	-- Talk to Ascilia (echo).
SEQ_040	= 40;	-- Talk to Momodi on the LS.
SEQ_045	= 45;	-- Visit Yayake at Arrzaneth Ossuary.
SEQ_050	= 50;	-- Find someone else among the thaumaturges: the funeral.
SEQ_055	= 55;	-- Speak to Niellefresne at the funeral.
SEQ_060	= 60;	-- Seek out Mumuepo.
SEQ_065	= 65;	-- Talk to Momodi on the LS.
SEQ_070	= 70;	-- Return to Momodi at the Quicksand.

-- Actor Class Ids
MOMODI						= 1000841;
GAGARUNA					= 1000862;
DEAUSTIE					= 1000293;
YAYAKE						= 1000846;

-- Platinum Mirage, then Paradise (PrivateAreaMasterPast 5)
MIRAGE_STAIRS_TRIGGER		= 1090286;
THANCRED					= 1000948;
NIELLEFRESNE				= 1000037;
GREINFARR					= 1000039;
CORGUEVAIS					= 1001054;

-- F'lhaminn's rehearsal spot in Central Thanalan (PrivateAreaMasterPast 0)
REHEARSAL_TRIGGER			= 1090287;
FLHAMINN					= 1000842;
ASCILIA						= 1000042;

-- Arrzaneth Ossuary: the funeral, then Mumuepo. The trigger stands in
-- front of the guild counter; each Ossuary scene leaves you a few steps
-- back from it (OSSUARY_HALL), so the next step starts by walking up.
OSSUARY_TRIGGER				= 1090288;

-- Warp spots: zone, private area type (nil = none), x, y, z, rotation
QUICKSAND					= {175, nil, -75.242, 195.009, 74.572, -0.046};
PARADISE					= {175, 5, -127.4, 200.0, -153.4, 3.14};
MIRAGE_LOBBY				= {175, nil, -182.6, 190.1, 112.2, 0.0};
REHEARSAL_ECHO				= {170, 0, 262.1, 216.34, -868.5, 0.0};
REHEARSAL_SPOT				= {170, nil, 262.1, 216.34, -868.5, 0.0};
OSSUARY_HALL				= {209, nil, -292.9, 206.1, 207.0, 0.0};

-- Msg packs for the Npc LS (Momodi)
NPCLS_MSGS = {
	{73, 74},				-- SEQ_020: F'lhaminn came by the Quicksand
	{114, 115, 116, 117},	-- SEQ_040: the thaumaturges and the Ossuary
	{160}					-- SEQ_065: come to the Quicksand
};
MOMODI_DISPLAY_ID = 1500014;

-- Quest Markers
MRKR_MOMODI				= 11001101;
MRKR_GAGARUNA			= 11001102;
MRKR_MIRAGE_DOOR		= 11001103;
MRKR_THANCRED			= 11001104;
MRKR_DEAUSTIE			= 11001105;
MRKR_REHEARSAL			= 11001106;
MRKR_ASCILIA			= 11001108;
MRKR_YAYAKE				= 11001109;
MRKR_FUNERAL			= 11001110;
MRKR_NIELLEFRESNE		= 11001111;
MRKR_MUMUEPO			= 11001112;
MRKR_MOMODI_END			= 11001113;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(MOMODI, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(MOMODI, QFLAG_TALK);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(GAGARUNA, QFLAG_TALK);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(MIRAGE_STAIRS_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(GAGARUNA);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(THANCRED, QFLAG_TALK);
		quest:SetENpc(NIELLEFRESNE);
		quest:SetENpc(GREINFARR);
		quest:SetENpc(CORGUEVAIS);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(GAGARUNA);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(DEAUSTIE, QFLAG_TALK);
		quest:SetENpc(GAGARUNA);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(REHEARSAL_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(DEAUSTIE);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_035) then
		quest:SetENpc(ASCILIA, QFLAG_TALK);
		quest:SetENpc(FLHAMINN);
	elseif (sequence == SEQ_045) then
		quest:SetENpc(YAYAKE, QFLAG_TALK);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_050) then
		quest:SetENpc(OSSUARY_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(MOMODI);
	elseif (sequence == SEQ_055) then
		quest:SetENpc(NIELLEFRESNE, QFLAG_TALK);
		quest:SetENpc(YAYAKE);
	elseif (sequence == SEQ_060) then
		quest:SetENpc(OSSUARY_TRIGGER, QFLAG_PUSH, false, true);
		quest:SetENpc(NIELLEFRESNE);
	elseif (sequence == SEQ_065) then
		quest:SetENpc(YAYAKE);
	elseif (sequence == SEQ_070) then
		quest:SetENpc(MOMODI, QFLAG_REWARD);
		quest:SetENpc(YAYAKE);
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
			warpTo(player, QUICKSAND);
			return;
		end
	elseif (sequence == SEQ_000) then
		if (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			player:EndEvent();
			quest:StartSequence(SEQ_005);
			warpTo(player, QUICKSAND);
			return;
		end
	elseif (sequence == SEQ_005) then
		if (classId == GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015");
			quest:StartSequence(SEQ_010);
		elseif (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		end
	elseif (sequence == SEQ_010) then
		if (classId == GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent015_2");
		elseif (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		end
	elseif (sequence == SEQ_015) then
		if (classId == THANCRED) then
			-- Thancred's wager; a Mirage hand shows you out
			callClientFunction(player, "delegateEvent", player, quest, "processEvent021");
			player:EndEvent();
			quest:NewNpcLsMsg(1);
			quest:StartSequence(SEQ_020);
			warpTo(player, MIRAGE_LOBBY);
			return;
		elseif (classId == GREINFARR) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2");
		elseif (classId == CORGUEVAIS) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_6");
		elseif (classId == NIELLEFRESNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_7");
		end
	elseif (sequence == SEQ_020) then
		if (classId == GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8");
		end
	elseif (sequence == SEQ_025) then
		if (classId == DEAUSTIE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent028");
			quest:StartSequence(SEQ_030);
		elseif (classId == GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8");
		elseif (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent025_2");
		end
	elseif (sequence == SEQ_030) then
		if (classId == DEAUSTIE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent028_2");
		elseif (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent025_2");
		end
	elseif (sequence == SEQ_035) then
		if (classId == ASCILIA) then
			-- Corguevais's coin, Ascilia's grief, F'lhaminn's favor
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			player:EndEvent();
			quest:NewNpcLsMsg(1);
			quest:StartSequence(SEQ_040);
			warpTo(player, REHEARSAL_SPOT);
			return;
		elseif (classId == FLHAMINN) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2");
		end
	elseif (sequence == SEQ_045) then
		if (classId == YAYAKE) then
			-- Yayake, then Mumuepo divines who sent you
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
			player:EndEvent();
			quest:StartSequence(SEQ_050);
			warpTo(player, OSSUARY_HALL);
			return;
		elseif (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent055_2");
		end
	elseif (sequence == SEQ_050) then
		if (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent055_2");
		end
	elseif (sequence == SEQ_055) then
		if (classId == NIELLEFRESNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080");
			quest:StartSequence(SEQ_060);
		elseif (classId == YAYAKE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent070_4");
		end
	elseif (sequence == SEQ_060) then
		if (classId == NIELLEFRESNE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent080_2");
		end
	elseif (sequence == SEQ_065) then
		if (classId == YAYAKE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent090_2");
		end
	elseif (sequence == SEQ_070) then
		if (classId == MOMODI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent100");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 300, 1, 1, 2);
			-- Completion reward from the client's quest reward sheet: 300 EXP + 15,000 gil.
			player:AddExp(300, player.charaWork.parameterSave.state_mainSkill[0], 0);
			player:AddGil(15000);
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		elseif (classId == YAYAKE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent090_2");
		end
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onPush(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_010 and classId == MIRAGE_STAIRS_TRIGGER) then
		-- Qoqoba stops you outside Paradise; the argument within
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
		player:EndEvent();
		quest:StartSequence(SEQ_015);
		warpTo(player, PARADISE);
		return;
	elseif (sequence == SEQ_030 and classId == REHEARSAL_TRIGGER) then
		-- The twins at F'lhaminn's rehearsal, then F'lhaminn; Ascilia
		-- waits in the echo the second scene warps to.
		callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
		callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
		player:EndEvent();
		quest:StartSequence(SEQ_035);
		warpTo(player, REHEARSAL_ECHO);
		return;
	elseif (sequence == SEQ_050 and classId == OSSUARY_TRIGGER) then
		-- Warburton's funeral
		callClientFunction(player, "delegateEvent", player, quest, "processEvent070");
		player:EndEvent();
		quest:StartSequence(SEQ_055);
		warpTo(player, OSSUARY_HALL);
		return;
	elseif (sequence == SEQ_060 and classId == OSSUARY_TRIGGER) then
		-- Mumuepo and Corguevais
		callClientFunction(player, "delegateEvent", player, quest, "processEvent090");
		player:EndEvent();
		quest:NewNpcLsMsg(1);
		quest:StartSequence(SEQ_065);
		warpTo(player, OSSUARY_HALL);
		return;
	end

	player:EndEvent();
	quest:UpdateENPCs();
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:getSequence();
	local msgPack;

	if (from == 1) then
		if (sequence == SEQ_020 or sequence == SEQ_025) then
			msgPack = 1;
		elseif (sequence == SEQ_040 or sequence == SEQ_045) then
			msgPack = 2;
		elseif (sequence == SEQ_065 or sequence == SEQ_070) then
			msgPack = 3;
		end
		if (msgPack == nil) then
			player:EndEvent();
			return;
		end

		player:SendGameMessageLocalizedDisplayName(quest, NPCLS_MSGS[msgPack][msgStep], MESSAGE_TYPE_NPC_LINKSHELL, MOMODI_DISPLAY_ID);
		if (msgStep >= #NPCLS_MSGS[msgPack]) then
			quest:EndOfNpcLsMsgs();
		else
			quest:ReadNpcLsMsg();
		end

		if (sequence == SEQ_020) then
			quest:StartSequenceForNpcLs(SEQ_025);
		elseif (sequence == SEQ_040) then
			quest:StartSequenceForNpcLs(SEQ_045);
		elseif (sequence == SEQ_065) then
			quest:StartSequenceForNpcLs(SEQ_070);
		end
	end

	player:EndEvent();
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:getSequence();

	if (sequence == SEQ_000) then
		return MRKR_MOMODI;
	elseif (sequence == SEQ_005) then
		return MRKR_GAGARUNA;
	elseif (sequence == SEQ_010) then
		return MRKR_MIRAGE_DOOR;
	elseif (sequence == SEQ_015) then
		return MRKR_THANCRED;
	elseif (sequence == SEQ_025) then
		return MRKR_DEAUSTIE;
	elseif (sequence == SEQ_030) then
		return MRKR_REHEARSAL;
	elseif (sequence == SEQ_035) then
		return MRKR_ASCILIA;
	elseif (sequence == SEQ_045) then
		return MRKR_YAYAKE;
	elseif (sequence == SEQ_050) then
		return MRKR_FUNERAL;
	elseif (sequence == SEQ_055) then
		return MRKR_NIELLEFRESNE;
	elseif (sequence == SEQ_060) then
		return MRKR_MUMUEPO;
	elseif (sequence == SEQ_070) then
		return MRKR_MOMODI_END;
	end
end

function warpTo(player, spot)
	GetWorldManager():DoZoneChange(player, spot[1], spot[2] and "PrivateAreaMasterPast" or nil, spot[2] or 0, 15, spot[3], spot[4], spot[5], spot[6]);
end
