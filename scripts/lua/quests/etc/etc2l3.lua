require ("global")
require ("quest")

--[[

Quest Script

Name: 	A Misty Past
Code: 	Etc2l3
Id: 	110646
Prereq: Level 17, Any Class

F'ongho waits at the mouth of Shposhae in Lower La Noscea. The ??? that
holds the Mistbeard insignia ring is inside: from the north spur of the
top floor (map 5,2) go down one level; it is at map (4,4) of that floor
(Gamer Escape, "A Misty Past"). Class 1091001 is a "???" (name 4000257)
standing in the open dungeon, zone 235. Back at the entrance F'ongho
asks which monster you saw; the answer is Shearing Sheridan.

]]

-- Rewards (the client's reward table; EXP from its row, or the level-band estimate)
REWARD_EXP			= 500;

-- Sequence Numbers
SEQ_000	= 0;  -- Talk to the ??? in Shposhae.
SEQ_005	= 5;  -- Talk to F'ongho and think about what NM you saw.
SEQ_010	= 10; -- Talk to F'ongho and tell her what it was.

-- Actor Class Ids
QUEST_OBJECTIVE	= 1091001;	-- the ??? in Shposhae (was Ryssfloh's class)
FONGHO 			= 1000367;

-- Quest Markers
MRKR_OBJECTIVE	= 11064601;
MRKR_FONGHO		= 11064602;

-- Quest Misc
RING_ITEMID 	= 11000228;

function onStart(player, quest)	
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)	
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(FONGHO, QFLAG_TALK);
	end

	if (sequence == SEQ_000) then
        quest:SetENpc(FONGHO);
		quest:SetENpc(QUEST_OBJECTIVE, QFLAG_TALK);
	elseif (sequence == SEQ_005) then	
		quest:SetENpc(QUEST_OBJECTIVE);
		quest:SetENpc(FONGHO, QFLAG_TALK);
	elseif (sequence == SEQ_010) then
		quest:SetENpc(FONGHO, QFLAG_REWARD);
	end	
end

function onTalk(player, quest, npc, eventName)
	local npcClassId = npc.GetActorClassId();
	local seq = quest:GetSequence();
    
	-- Offer the quest
	if (npcClassId == FONGHO and not player:HasQuest(quest)) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventFONGHOStart");
		if (questAccepted == 1) then
			player:AcceptQuest(quest);
		end
		player:EndEvent();
		return;
	end
	
	-- Quest Progress
	if (seq == SEQ_000) then
        if (npcClassId == FONGHO) then
            callClientFunction(player, "delegateEvent", player, quest, "processEvent_000");
		elseif (npcClassId == QUEST_OBJECTIVE) then
			player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(RING_ITEMID, 1, 1);
			attentionMessage(player, 25246, RING_ITEMID, 1); -- You obtain <item>
			quest:StartSequence(SEQ_005);
		end
	elseif (seq == SEQ_005) then
		if (npcClassId == FONGHO) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent_015");
			quest:StartSequence(SEQ_010);
		end
	elseif (seq == SEQ_010) then
		--Quest Complete
		if (npcClassId == FONGHO) then
			local monsterChoice = callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
			
			if (monsterChoice == 1) then
				callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
				player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
				player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(RING_ITEMID, 1);
				player:CompleteQuest(quest);
			end
		end
	end
	
	quest:UpdateENPCs();	
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return quest:GetSequence() > SEQ_000 and 1 or 0;
end

function getJournalMapMarkerList(player, quest)
    local sequence = quest:getSequence();
    
    if (sequence == SEQ_000) then
		return MRKR_OBJECTIVE;
    elseif (sequence == SEQ_005) then
        return MRKR_FONGHO;
    elseif (sequence == SEQ_010) then
        return MRKR_FONGHO;
    end
end