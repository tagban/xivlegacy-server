require ("global")
require ("quest")
require ("modifiers")

--[[

Quest Script

Name: 	The House Always Wins
Code: 	Pgl200
Id: 	110060
Prereq: Level 20, Pugilist

]]

-- Sequence Numbers
SEQ_000	= 0;   -- Talk to Titinin.
SEQ_005	= 5;   -- Head to the GSM guild and talk to Esperaunce 3 times.
SEQ_010	= 10;  -- Pick up Esperaunce's scattered coins, then speak to him.
SEQ_015	= 15;  -- Head to the ADV guild and talk to the Wise Miser. Journal Data 3: Set to 1 if talked to Titinin.
SEQ_025	= 25;  -- Head to the PGL guild entrence and talk to Lady Lewena. Journal Data 4: Set to 1 if talked to Titinin.
SEQ_030	= 30;  -- Head to GLA guild and fight on the bloodsands (content Pgl20002). Journal Data 5: Set to 1 once you win the fight.
SEQ_035	= 35;  -- Return to Titinin.

-- Actor Class Ids
ENPC_GAGARUNA 		= 1000862;
ENPC_TITININ 		= 1000934;
ENPC_NAIDA_ZAMAIDA	= 1000955;
ENPC_SINGLETON		= 1001445;
ENPC_TRIGGER_GSM	= 1090058;
ENPC_TRIGGER_PGL	= 1090042;
ENPC_PRIVAREA_EXIT	= 1290002;

TEXT_LEAVING_AREA	= 34109; -- "You are about to leave the area."

-- Esperaunce's dropped gil: five "???" glints on the Lapidaries floor
-- (seed 194, private area 5 of zone 209).
ENPC_COINS = { 1080014, 1080015, 1080016, 1080019, 1080020 };
COIN_FLAG_BASE = 0; -- flags 0-4: coin n picked up

-- PGL Actors
ENPC_MELISIE		= 1001009;
ENPC_GUNNULF		= 1001256;
ENPC_SHAMANI 		= 1001012;
ENPC_HALSTEIN		= 1001007;
ENPC_HEIBERT		= 1001257;
ENPC_IPAGHLO		= 1001260;

-- GSM Actors
ENPC_SULTRY_STRUMPET 	= 1000952;
ENPC_BEAUTEOUS_BEAUTY 	= 1000953;
ENPC_ESPERAUNCE			= 1000954;

-- Quest Markers
MRKR_TITININ		= 11006001;
MRKR_OBJECTIVE		= 11006002;
MRKR_ESPERAUNCE1	= 11006003;
MRKR_ESPERAUNCE2	= 11006004;
MRKR_NAIDA_ZAMADIA	= 11006005;
MRKR_OBJECTIVE2		= 11006006;
MRKR_SINGLETON		= 11006007;
MRKR_TITININ2		= 11006008;

-- Quest Details
ITEM_PLATINUM_LEDGER  = 11000134;
ITEM_KINGOFPLOTS_GIL  = 11000097;
ITEM_WISEMISER_GIL    = 11000098;
ITEM_LEWENA_GIL  	  = 11000099;
COUNTER_005 = 0;
COUNTER_015 = 1;
COUNTER_025 = 2;
COUNTER_030 = 3;

-- Lady Lewena cheers from the stands (literal lines: the quest's text ids
-- don't render through SendGameMessage on this server).
LEWENA_CHEERS = {
	"Yes! Yes! Do not stop!",
	"More! Give it all you've got!",
	"There! There! Finish this!",
	"Victimize! Victimize! Victimiiize!",
	"Concussive Blow! Concussive Blooow!",
	"Pummel! Pummel! Pummeeel!",
	"Haymaker! Haymaker! Haymakeeer!",
	"Pounce! Pounce! Pooounce!",
};

function onStart(player, quest)	
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
	-- Titinin takes the ledger and the three purses back.
	local keyItems = player:GetItemPackage(INVENTORY_KEYITEMS);
	for _, item in ipairs({ ITEM_PLATINUM_LEDGER, ITEM_KINGOFPLOTS_GIL, ITEM_WISEMISER_GIL, ITEM_LEWENA_GIL }) do
		keyItems:RemoveItem(item, 1);
	end
end

function giveKeyItem(player, item)
	player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(item, 1, 1);
	player:SendGameMessage(GetWorldMaster(), 25246, MESSAGE_TYPE_SYSTEM, item, 1);
end

function onStateChange(player, quest, sequence)	
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(ENPC_GAGARUNA, QFLAG_TALK);
	elseif (sequence == SEQ_000) then
		quest:SetENpc(ENPC_TITININ, QFLAG_TALK);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_MELISIE);
		quest:SetENpc(ENPC_GUNNULF);
		quest:SetENpc(ENPC_SHAMANI);
		quest:SetENpc(ENPC_HALSTEIN);
		quest:SetENpc(ENPC_HEIBERT);
		quest:SetENpc(ENPC_IPAGHLO);
	elseif (sequence == SEQ_005) then
		quest:SetENpc(ENPC_TITININ);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_SULTRY_STRUMPET);
		quest:SetENpc(ENPC_BEAUTEOUS_BEAUTY);
		quest:SetENpc(ENPC_ESPERAUNCE, QFLAG_TALK);
		quest:SetENpc(ENPC_TRIGGER_GSM, QFLAG_NONE, false, true);
		quest:SetENpc(ENPC_PRIVAREA_EXIT, QFLAG_NONE, false, true);
	elseif (sequence == SEQ_010) then
		local data = quest:GetData();
		local allPicked = coinsPicked(data) >= #ENPC_COINS;
		quest:SetENpc(ENPC_SULTRY_STRUMPET);
		quest:SetENpc(ENPC_BEAUTEOUS_BEAUTY);
		quest:SetENpc(ENPC_ESPERAUNCE, allPicked and QFLAG_TALK or QFLAG_NONE);
		for i, classId in ipairs(ENPC_COINS) do
			-- Picked ones stay registered (no icon) so a touch after
			-- re-entry reaches pickUpCoin, which hides them again.
			if (data:GetFlag(COIN_FLAG_BASE + i - 1)) then
				quest:SetENpc(classId, QFLAG_NONE);
			else
				quest:SetENpc(classId, QFLAG_TALK);
			end
		end
		-- The door stays open in case the player steps out mid-search.
		quest:SetENpc(ENPC_TRIGGER_GSM, QFLAG_NONE, false, true);
		quest:SetENpc(ENPC_PRIVAREA_EXIT, QFLAG_NONE, false, true);
	elseif (sequence == SEQ_015) then
		quest:SetENpc(ENPC_TITININ);
		quest:SetENpc(ENPC_NAIDA_ZAMAIDA, QFLAG_TALK);
		quest:SetENpc(ENPC_GAGARUNA);
	elseif (sequence == SEQ_025) then
		quest:SetENpc(ENPC_TITININ);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_TRIGGER_PGL, QFLAG_PUSH, false, true);
	elseif (sequence == SEQ_030) then
		quest:SetENpc(ENPC_TITININ);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_SINGLETON, QFLAG_TALK);
	elseif (sequence == SEQ_035) then
		quest:SetENpc(ENPC_TITININ, QFLAG_REWARD);
		quest:SetENpc(ENPC_GAGARUNA);
		quest:SetENpc(ENPC_MELISIE);
		quest:SetENpc(ENPC_GUNNULF);
		quest:SetENpc(ENPC_SHAMANI);
		quest:SetENpc(ENPC_HALSTEIN);
		quest:SetENpc(ENPC_HEIBERT);
		quest:SetENpc(ENPC_IPAGHLO);
	end				
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();
    
	-- Offer the quest
	if (npcClassId == ENPC_GAGARUNA and seq == SEQ_ACCEPT) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventGagarunaStart");
		if (questAccepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;	
	-- Quest Progress
	elseif (seq == SEQ_000) then
        if (npcClassId == ENPC_TITININ) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010");
			giveKeyItem(player, ITEM_PLATINUM_LEDGER);
			quest:StartSequence(SEQ_005);
		elseif (npcClassId == ENPC_GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_2");
		elseif (npcClassId == ENPC_IPAGHLO) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_3");
		elseif (npcClassId == ENPC_HALSTEIN) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_4");
		elseif (npcClassId == ENPC_MELISIE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_5");
		elseif (npcClassId == ENPC_HEIBERT) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_6");
		elseif (npcClassId == ENPC_GUNNULF) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_7");
		elseif (npcClassId == ENPC_SHAMANI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent005_8");
		end	
	elseif (seq == SEQ_005) then
		if (npcClassId == ENPC_ESPERAUNCE) then
			local talkCount = data:IncCounter(COUNTER_005);
			if (talkCount == 1) then
				player:SendGameMessage(quest, 117, MESSAGE_TYPE_SYSTEM);
			elseif (talkCount == 2) then
				player:SendGameMessage(quest, 118, MESSAGE_TYPE_SYSTEM);
			elseif (talkCount >= 3) then
				-- He "drops" the sale's gil and leaves it for you to pick up.
				callClientFunction(player, "delegateEvent", player, quest, "processEvent020");
				quest:StartSequence(SEQ_010);
			end
		elseif (npcClassId == ENPC_TITININ) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_2");
		elseif (npcClassId == ENPC_GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_3");
		elseif (npcClassId == ENPC_SULTRY_STRUMPET) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_4");
		elseif (npcClassId == ENPC_BEAUTEOUS_BEAUTY) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent010_5");
		end
	elseif (seq == SEQ_010) then 
		local coin = coinIndex(npcClassId);
		if (coin ~= nil) then
			pickUpCoin(player, quest, npc, coin);
			player:EndEvent();
			return;
		elseif (npcClassId == ENPC_ESPERAUNCE) then
			if (coinsPicked(data) < #ENPC_COINS) then
				-- "Which part of 'tidy it up' did you not understand?"
				callClientFunction(player, "delegateEvent", player, quest, "processEvent020_2");
			else
				callClientFunction(player, "delegateEvent", player, quest, "processEvent030");
				quest:StartSequence(SEQ_015);
				giveKeyItem(player, ITEM_KINGOFPLOTS_GIL);
				player:EndEvent();
				-- pgl20030 ends on an after-warp fade.
				GetWorldManager():WarpToPublicArea(player);
				return;
			end
		elseif (npcClassId == ENPC_SULTRY_STRUMPET) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_3");
		elseif (npcClassId == ENPC_BEAUTEOUS_BEAUTY) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent020_4");
		end
	elseif (seq == SEQ_015) then
		if (npcClassId == ENPC_NAIDA_ZAMAIDA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040");
			quest:StartSequence(SEQ_025);
			giveKeyItem(player, ITEM_WISEMISER_GIL);
		elseif (npcClassId == ENPC_TITININ) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030_2");
			data:SetCounter(COUNTER_015, 1);
		elseif (npcClassId == ENPC_GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent030_3");
		end
	elseif (seq == SEQ_025) then
		if (npcClassId == ENPC_PUSH_PGL) then
		elseif (npcClassId == ENPC_TITININ) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_2");
			data:SetCounter(COUNTER_025, 1);
		elseif (npcClassId == ENPC_GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent040_3");
		end
	elseif (seq == SEQ_030) then
		if (npcClassId == ENPC_SINGLETON) then
			local enterDuty = callClientFunction(player, "delegateEvent", player, quest, "processEvent050_4");
			if (enterDuty == 1) then
				startPgl200Coliseum(player, quest);
				return;
			end
		elseif (npcClassId == ENPC_TITININ) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_2");
		elseif (npcClassId == ENPC_GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050_3");
		end
	elseif (seq == SEQ_035) then
		if (npcClassId == ENPC_TITININ) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent070");			
            callClientFunction(player, "delegateEvent", player, quest, "sqrwa", 200, 2)
			player:CompleteQuest(quest);
		elseif (npcClassId == ENPC_GAGARUNA) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_2");
		elseif (npcClassId == ENPC_IPAGHLO) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_3");
		elseif (npcClassId == ENPC_HALSTEIN) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_4");
		elseif (npcClassId == ENPC_MELISIE) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_5");
		elseif (npcClassId == ENPC_HEIBERT) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_6");
		elseif (npcClassId == ENPC_GUNNULF) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_7");
		elseif (npcClassId == ENPC_SHAMANI) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent060_8");
		end
	end
	
	quest:UpdateENPCs();	
	player:EndEvent();
end

function coinIndex(classId)
	for i, id in ipairs(ENPC_COINS) do
		if (id == classId) then
			return i;
		end
	end
	return nil;
end

-- The four counters are all spoken for (journal data), so the coins count
-- themselves from their flags.
function coinsPicked(data)
	local picked = 0;
	for i = 1, #ENPC_COINS do
		if (data:GetFlag(COIN_FLAG_BASE + i - 1)) then
			picked = picked + 1;
		end
	end
	return picked;
end

function pickUpCoin(player, quest, npc, coin)
	local data = quest:GetData();
	local flag = COIN_FLAG_BASE + coin - 1;
	if (data:GetFlag(flag)) then
		-- Picked before the player last left the shop: re-entry streams
		-- the glint back, so a touch tidies it away again.
		player:HideActor(npc.Id);
		return;
	end
	data:SetFlag(flag);
	local picked = coinsPicked(data);
	player:HideActor(npc.Id);
	player:SendMessage(0x20, "", string.format("You gather up a handful of fallen gil. (%d/%d)", picked, #ENPC_COINS));
	if (picked >= #ENPC_COINS) then
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
	end
	quest:UpdateENPCs();
end

-- The bloodsands match (content Pgl20002, QuestDirectorPgl20002): the man0u1
-- arena entry, at the same spot. Win, and the director plays Lady Lewena's
-- payment; lose, and Singleton will let you try again.
function startPgl200Coliseum(player, quest)
	local contentArea = player.CurrentArea:CreateContentArea(player, "/Area/PrivateArea/Content/PrivateAreaMasterSimpleContent", "Pgl20002", "SimpleContentPgl20002", "Quest/QuestDirectorPgl20002", 209);
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
	GetWorldManager():DoZoneChangeContent(player, contentArea, -209.9, 192.0, 146.4, 0.8, 16);
end

-- QuestDirectorPgl20002, after a win (a loss never signals the director).
function finishPgl200Coliseum(player, quest, actor)
	local data = quest:GetData();
	kickEventContinue(player, actor, "noticeEvent", "noticeEvent");
	-- pgl20060: Lady Lewena pays up. It ends on an after-warp fade.
	callClientFunction(player, "delegateEvent", player, quest, "processEvent060");
	data:SetCounter(COUNTER_030, 1);
	quest:StartSequence(SEQ_035);
	giveKeyItem(player, ITEM_LEWENA_GIL);
	player:EndEvent();
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -192.0, 194.5, 193.785, 3.0);
end

-- SimpleContentPgl20002, on a loss. The content ends it itself: the
-- director runs in its own Lua state and can't see what happened.
function losePgl200Coliseum(player)
	player:SendMessage(0x20, "", "You are defeated.");
	player:SetMod(modifiersGlobal.MinimumHpLock, 0);
	player:GetZone():ContentFinished();
	-- Back to Singleton for another try.
	GetWorldManager():DoZoneChange(player, 209, nil, 0, 15, -192.0, 194.5, 184.0, 3.0);
end

function onPush(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
	local data = quest:GetData();
	
	if (npcClassId == ENPC_PRIVAREA_EXIT and (seq == SEQ_005 or seq == SEQ_010)) then
		-- The exit's two circles fire on the way out: "caution" at 50 yalms
		-- warns, "exit" at 60 leaves the shop.
		player:EndEvent();
		if (eventName == "caution") then
			player:SendGameMessage(player, GetWorldMaster(), TEXT_LEAVING_AREA, 0x20);
		elseif (eventName == "exit") then
			GetWorldManager():WarpToPublicArea(player);
		end
	elseif (seq == SEQ_005 or seq == SEQ_010) then
		player:EndEvent();
		if (npcClassId == ENPC_TRIGGER_GSM) then
			-- Down on the shop floor, facing Esperaunce.
			GetWorldManager():WarpToPrivateArea(player, "PrivateAreaMasterPast", 5, -124.0, 200.2, 266.3, 0.0);
		end
	elseif (seq == SEQ_025) then
		if (npcClassId == ENPC_TRIGGER_PGL) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent050");
			quest:StartSequence(SEQ_030);
			player:EndEvent();
		end
	end
	
end

function getJournalInformation(player, quest)
	local data = quest:GetData();
	return 0, data:GetCounter(COUNTER_015), data:GetCounter(COUNTER_025), data:GetCounter(COUNTER_030);
end

function getJournalMapMarkerList(player, quest)
    local seq = quest:getSequence();
	local data = quest:GetData();	
    
    if (seq == SEQ_000) then
		return MRKR_TITININ;
    elseif (seq == SEQ_005) then
        return MRKR_ESPERAUNCE1;
	elseif (seq == SEQ_010) then
		return MRKR_OBJECTIVE;
	elseif (seq == SEQ_015) then		
		if (data:GetCounter(COUNTER_015) == 1) then
			return MRKR_NAIDA_ZAMADIA;
		end
	elseif (seq == SEQ_025) then
		if (data:GetCounter(COUNTER_025) == 1) then
			return MRKR_OBJECTIVE2;
		end
	elseif (seq == SEQ_030) then
		return MRKR_SINGLETON;		
	elseif (seq == SEQ_035) then
		return MRKR_TITININ2;
    end
	
	return;
end