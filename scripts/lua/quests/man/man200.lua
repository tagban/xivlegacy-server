require ("global")
require ("quest")

--[[

Quest Script

Name: 	Fade to White
Code: 	Man200
Id: 	110013
Prereq: Man2l0, Man2g0 or Man2u0 (110004, 110008, 110012). Level 18, any class.

]]

-- Sequence Numbers
SEQ_000	= 0;  	-- Go to the event door
SEQ_005	= 5;  	-- Talk to Minfilia to use the echo on her.
SEQ_010	= 10;  	-- Talk to Minfilia to join the Path of the Twelve.
SEQ_020	= 20;  	-- Path companion selection sequence.
SEQ_025	= 25;  	-- Wait for the linkpearl message.
SEQ_027	= 27;	-- Pray return to the Waking Sands

-- Quest Actors
MINFILIA				= 1000843;
TATARU					= 1001046;
SATZFLOH				= 1001228;
PERCEVAINS				= 1001229;
UNA_TAYUUN				= 1001230;
ROUGH_SPOKEN_FELLOW		= 1001274;
RED_SHOED_RASCAL		= 1001275;
ABSTRACTED_GLADIATOR	= 1001276;
CHAPEAUED_CHAP			= 1001277;
BARRATROUS_BUCCANEER	= 1001278;
SOFTHEARTED_SEPTUAGEN	= 1001279;
INDIGO_EYED_ARCHER		= 1001280;
LOAM_SCENETED_LADY		= 1001281;
UNCOMFORTABLE_BRUTE		= 1001282;
SAHJA_ZHWAN				= 1001373;
NENEKANI				= 1001374;
GODFREY					= 1001375;
FENANA					= 1001376;
NONORU					= 1001377;
SERANELIEN				= 1001378;

SNPC_START				= 1070001;
SNPC_END				= 1070166;

MARKET_ENTRENCE			= 1090265;
EVENT_DOOR_EXIT			= 1090160;
EVENT_DOOR_OFFICE_W		= 1090161;
EVENT_DOOR_OFFICE_E		= 1090162;

MOMODI					= 1000841;

-- Quest Markers
MRKR_STEP1				= 11001301;
MRKR_STEP2				= 11001302;
MRKR_STEP3				= 11001303;
MRKR_STEP4				= 11001304;
MRKR_STEP5				= 11001305;
MRKR_STEP6				= 11001306;

-- Quest Flags
FLAG_VISITED			= 0;
FLAG_TALKED_TATARU		= 1;
FLAG_DUTY_COMPLETE		= 2;

-- Other
MIN_TATARU_WAIT_TIME 	= 20;

function onStart(player, quest)	
	quest:StartSequence(SEQ_000);
	-- Accepting at the market entrance already played the arrival scene.
	quest:GetData():SetFlag(FLAG_VISITED);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	-- Offered at the Ul'dah market entrance once any nation's level 13
	-- quest is done and the player is level 18: walking in accepts it.
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(MARKET_ENTRENCE, QFLAG_PUSH, false, true);
		return;
	end

	local data = quest:GetData();
	quest:SetTimeUpdate(false);
	
	-- Sequence changing ENpcs
	if (sequence == SEQ_000) then
		quest:SetENpc(EVENT_DOOR_OFFICE_W, QFLAG_PUSH, false, true);
		quest:SetENpc(TATARU);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(MINFILIA, QFLAG_TALK);
		quest:SetENpc(EVENT_DOOR_OFFICE_W, QFLAG_PUSH, false, true);
		quest:SetENpc(EVENT_DOOR_OFFICE_E, QFLAG_NONE, false, true);
		quest:SetENpc(TATARU);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(MINFILIA, QFLAG_TALK);
		quest:SetENpc(EVENT_DOOR_OFFICE_W, QFLAG_PUSH, false, true);
		quest:SetENpc(EVENT_DOOR_OFFICE_E, QFLAG_NONE, false, true);
		quest:SetENpc(TATARU);
	elseif (sequence == SEQ_020) then
		quest:SetENpc(TATARU, QFLAG_TALK);
		quest:SetENpc(MINFILIA);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(TATARU);
		quest:GetData():SetTimeNow();
		quest:SetTimeUpdate(true);
	elseif (sequence == SEQ_027) then
		-- Tataru introduces your Path companion, then you name them and
		-- she gives the reward. No companion actor is placed: the client's
		-- own scenes draw the companion from the saved choice.
		if (quest:GetData():GetFlag(FLAG_DUTY_COMPLETE)) then
			quest:SetENpc(TATARU, QFLAG_REWARD);
		else
			quest:SetENpc(TATARU, QFLAG_TALK);
		end
	end
	
	-- All the other ENpcs in the Waking Sands
	quest:SetENpc(MARKET_ENTRENCE, QFLAG_NONE, false, true);
	quest:SetENpc(EVENT_DOOR_EXIT, QFLAG_PUSH, false, true);
	quest:SetENpc(SATZFLOH);
	quest:SetENpc(PERCEVAINS);
	quest:SetENpc(UNA_TAYUUN);
	quest:SetENpc(ROUGH_SPOKEN_FELLOW);
	quest:SetENpc(RED_SHOED_RASCAL);
	quest:SetENpc(ABSTRACTED_GLADIATOR);
	quest:SetENpc(CHAPEAUED_CHAP);
	quest:SetENpc(BARRATROUS_BUCCANEER);
	quest:SetENpc(SOFTHEARTED_SEPTUAGEN);
	quest:SetENpc(INDIGO_EYED_ARCHER);
	quest:SetENpc(LOAM_SCENETED_LADY);
	quest:SetENpc(UNCOMFORTABLE_BRUTE);
	quest:SetENpc(SAHJA_ZHWAN);
	quest:SetENpc(NENEKANI);
	quest:SetENpc(GODFREY);
	quest:SetENpc(FENANA);
	quest:SetENpc(NONORU);
	quest:SetENpc(SERANELIEN);
	
end

function onTalk(player, quest, npc)
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();

	if (sequence == SEQ_000) then
		if (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		end
	elseif (sequence == SEQ_005) then
		if (classId == MINFILIA) then
			callClientFunction(player, "delegateEvent", player, quest, "pE20", "???", 1, 1, 1, player:GetInitialTown());
			quest:StartSequence(SEQ_010);
		elseif (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent000_2");
		end
	elseif (sequence == SEQ_010) then
		if (classId == MINFILIA) then
			local didJoinPoT = callClientFunction(player, "delegateEvent", player, quest, "pE25", "???", 1, 1, 1, player:GetInitialTown());
			if (didJoinPoT == 1) then
				player:EndEvent();
				GetWorldManager():WarpToPosition(player, -142.75, 1, -160, -1.6);			
				quest:StartSequence(SEQ_020);
				return;
			end
		elseif (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2");
		end
	elseif (sequence == SEQ_020) then
		if (classId == TATARU) then
			-- Selecting a Path Companion
			local sNpcActorClassId, sNpcPersonality = callClientFunction(player, "delegateEvent", player, quest, "processSnpcSelect", "???", 1, 1, 1, player:GetInitialTown());			
			-- NOTE: Meteor upstream used the C-style `!=` inequality
			-- operator here, which isn't valid Lua. Corrected to `~=`.
			if (sNpcActorClassId ~= -1 and sNpcPersonality ~= -1) then
				player:SetSNpc("???", sNpcActorClassId, sNpcPersonality);
				player:AddNpcLs(6);
				quest:StartSequence(SEQ_025);
			end
			player:EndEvent();
			return;
		end
	elseif (sequence == SEQ_025) then
		if (classId == TATARU) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2");
			quest:NewNpcLsMsg(6);
		end
	elseif (sequence == SEQ_027) then
		if (classId == TATARU) then
			if (not quest:GetData():GetFlag(FLAG_DUTY_COMPLETE)) then
				meetPathCompanion(player, quest);
			else
				namePathCompanion(player, quest);
			end
			return;
		end
	end
	
	-- Other ENpcs
	if (sequence < SEQ_010) then
		seq000_onTalkOtherNpcs(player, quest, npc);
	else
		seq010_onTalkOtherNpcs(player, quest, npc);
	end
	
	-- Regardless of sequence
	if (classId == EVENT_DOOR_OFFICE) then
	elseif (classId == EVENT_DOOR_EXIT) then
	elseif (classId == NONORU) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_8");
	elseif (classId == CHAPEAUED_CHAP) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_9");
	elseif (classId == ROUGH_SPOKEN_FELLOW) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_10");
	elseif (classId == SATZFLOH) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_18");
	elseif (classId == PERCEVAINS) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_19");
	elseif (classId == UNA_TAYUUN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_20");
	end
	
	player:EndEvent();
	quest:UpdateENPCs();
end

function seq000_onTalkOtherNpcs(player, quest, npc)
	local classId = npc:GetActorClassId();
	
	if (classId == SERANELIEN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_3");
	elseif (classId == SAHJA_ZHWAN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_4");
	elseif (classId == NENEKANI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_5");
	elseif (classId == GODFREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_6");
	elseif (classId == FENANA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_7");
	elseif (classId == LOAM_SCENETED_LADY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_11");
	elseif (classId == SOFTHEARTED_SEPTUAGEN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_12");
	elseif (classId == INDIGO_EYED_ARCHER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_13");
	elseif (classId == BARRATROUS_BUCCANEER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_14");
	elseif (classId == UNCOMFORTABLE_BRUTE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_15");
	elseif (classId == RED_SHOED_RASCAL) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_16");
	elseif (classId == ABSTRACTED_GLADIATOR) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent000_17");		
	end
end

function seq010_onTalkOtherNpcs(player, quest, npc)
	local classId = npc:GetActorClassId();
	
	if (classId == SERANELIEN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3");
	elseif (classId == SAHJA_ZHWAN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4");
	elseif (classId == NENEKANI) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_5");
	elseif (classId == GODFREY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_6");
	elseif (classId == FENANA) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_7");
	elseif (classId == LOAM_SCENETED_LADY) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_8");
	elseif (classId == SOFTHEARTED_SEPTUAGEN) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_9");
	elseif (classId == INDIGO_EYED_ARCHER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_10");
	elseif (classId == BARRATROUS_BUCCANEER) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_11");
	elseif (classId == UNCOMFORTABLE_BRUTE) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_12");
	elseif (classId == RED_SHOED_RASCAL) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_13");
	elseif (classId == ABSTRACTED_GLADIATOR) then
		callClientFunction(player, "delegateEvent", player, quest, "processEvent020_14");
	end
end

function onPush(player, quest, npc)
	local data = quest:GetData();
	local sequence = quest:getSequence();
	local classId = npc:GetActorClassId();
	
	if (classId == MARKET_ENTRENCE) then
		if (sequence == SEQ_ACCEPT) then
			callClientFunction(player, "delegateEvent", player, quest, "pE00", "???", 1, 1, 1, player:GetInitialTown());
			player:EndEvent();
			player:AcceptQuest(quest, true);
			GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", 0, 15, -205.25, 0, -160, 1.55);
			return;
		elseif (sequence == SEQ_000 and not data:GetFlag(FLAG_VISITED)) then
			data:SetFlag(FLAG_VISITED);
			callClientFunction(player, "delegateEvent", player, quest, "pE00", "???", 1, 1, 1, player:GetInitialTown());
		elseif (sequence == SEQ_000 and not data:GetFlag(FLAG_VISITED)) then
		end
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", 0, 15, -205.25, 0, -160, 1.55);
		return;
	end
	
	if (classId == EVENT_DOOR_EXIT) then
		player:EndEvent();
		GetWorldManager():DoZoneChange(player, 175, nil, 0, 15, -216.52, 190, 30.5, 2.32);
	elseif (classId == EVENT_DOOR_OFFICE_W) then
		if (sequence == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "pE10", "???", 1, 1, 1, player:GetInitialTown());
			quest:StartSequence(SEQ_005);			
		end
		player:EndEvent();
		GetWorldManager():WarpToPosition(player, -126.2, 1.2, -160, 1.6);
		return;
	elseif (classId == EVENT_DOOR_OFFICE_E) then
		player:EndEvent();
		GetWorldManager():WarpToPosition(player, -142.75, 1, -160, -1.6);
		return;
	end
	
	player:EndEvent();
	quest:UpdateENPCs();
end

function onTimeUpdate(player, quest, currentTime)
	local seqStartTime = quest:GetData():GetTime();
	local sequence = quest:getSequence();
	
	if (sequence == SEQ_025) then
		if (currentTime - seqStartTime > MIN_TATARU_WAIT_TIME) then
			quest:SetTimeUpdate(false);
			quest:NewNpcLsMsg(6);
		end
	end	
end

function onNpcLS(player, quest, from, msgStep)
	local sequence = quest:getSequence();
	
	if (from == 6) then
		player:SendGameMessageLocalizedDisplayName(quest, 435, MESSAGE_TYPE_NPC_LINKSHELL, 1500054);
		quest:EndOfNpcLsMsgs();
		quest:StartSequence(SEQ_027);		
	end
	
	player:EndEvent();
end

function getJournalInformation(player, quest)
	if (quest:GetData():GetFlag(FLAG_DUTY_COMPLETE)) then
		return 1, 0, 0, 0, 0, player:GetSNpcNickname();
	end
end

function getJournalMapMarkerList(player, quest)
	local sequence = quest:getSequence();
	
	if (sequence == SEQ_000) then
		return MRKR_STEP1;
	elseif (sequence == SEQ_005) then
		return MRKR_STEP2;
	elseif (sequence == SEQ_010) then
		return MRKR_STEP3;
	elseif (sequence == SEQ_020) then
		return MRKR_STEP4;
	elseif (sequence == SEQ_025) then
		return MRKR_STEP5;
	elseif (sequence == SEQ_027) then
		return MRKR_STEP6;
	end	
end

-- The naming duty, played with the client's own scenes in the Waking Sands:
-- the duty prompt, then Tataru's introduction (pE050, a cutscene that
-- fades in after a warp, so a warp in place follows it).
function meetPathCompanion(player, quest)
	local result = callClientFunction(player, "delegateEvent", player, quest, "contentsJoinAskInBasaClass");
	if (result == 1) then
		callClientFunction(player, "delegateEvent", player, quest, "pE050", player:GetSNpcNickname(), player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown());
		player:EndEvent();
		quest:GetData():SetFlag(FLAG_DUTY_COMPLETE);
		quest:UpdateENPCs();
		GetWorldManager():DoZoneChange(player, 181, "PrivateAreaMasterPast", 0, 15, player.positionX, player.positionY, player.positionZ, player.rotation);
		return;
	end
	player:EndEvent();
end

-- Name the companion (pEN), hear them answer (pE055), the closing scene
-- with their new name (pE060), and the reward.
function namePathCompanion(player, quest)
	-- pEN answers with the typed name, or a negative number when the box
	-- was left empty; then the companion keeps the name they have.
	local name = callClientFunction(player, "delegateEvent", player, quest, "pEN", player:GetSNpcPersonality());
	if (type(name) == "string" and name ~= "") then
		player:SetSNpc(name, SNPC_START - 1 + player:GetSNpcSkin(), player:GetSNpcPersonality());
	else
		name = player:GetSNpcNickname();
	end
	callClientFunction(player, "delegateEvent", player, quest, "pE055", name, player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown());
	callClientFunction(player, "delegateEvent", player, quest, "pE060", name, player:GetSNpcSkin(), player:GetSNpcPersonality(), player:GetSNpcCoordinate(), player:GetInitialTown());
	-- Completion reward from the client's quest reward sheet: 50 EXP + 45,000 gil.
	callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 50, 1, 1, 2);
	player:AddExp(50, player.charaWork.parameterSave.state_mainSkill[0], 0);
	player:AddGil(45000);
	player:EndEvent();
	player:CompleteQuest(quest);
end