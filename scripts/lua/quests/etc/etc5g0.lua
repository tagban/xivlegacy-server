require ("global")
require ("quest")

--[[

Quest Script

Name:   Waste Not Want Not
Code:   Etc5g0
Id:     110828
Prereq: Level 1 on any class.  Second MSQ completed. (110002 Man0l1 / 110006 Man0g1 / 110010 Man0u1)
Notes:  Rewards 200 gil

]]

-- Rewards (the client's reward table; EXP from its row, or the level-band estimate)
REWARD_EXP			= 200;

-- Sequence Numbers
SEQ_000 = 0;  -- Talk to Pfarahr.
SEQ_001 = 1;  -- Return to V'korolon.

-- Actor Class Ids
VKOROLON                = 1000458;
PFARAHR                 = 1001707;

-- Quest Item
ITEM_WELL_WORN_BAG      = 11000224;

-- Quest Markers
MRKR_PFARAHR            = 11082001;
MRKR_VKOROLON           = 11082002;

function onStart(player, quest)
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(VKOROLON, QFLAG_TALK);
	end

    if (sequence == SEQ_000) then
        quest:SetENpc(VKOROLON);
        quest:SetENpc(PFARAHR, QFLAG_TALK);
    elseif (sequence == SEQ_001) then 
        quest:SetENpc(VKOROLON, QFLAG_TALK);
        quest:SetENpc(PFARAHR);
    end
end

function onTalk(player, quest, npc)
    local sequence = quest:getSequence();
    local classId = npc:GetActorClassId();
    
	if (sequence == SEQ_ACCEPT) then
		local questAccepted = callClientFunction(player, "delegateEvent", player, quest, "processEventVKOROLONStart");
		if (questAccepted == 1) then
			player:AcceptQuest(quest);
            quest:StartSequence(SEQ_000);
            wait(2);
            attentionMessage(player, 25246, ITEM_WELL_WORN_BAG, 1);
            
		end
		player:EndEvent();
		return;
    elseif (sequence == SEQ_000) then
        if (classId == VKOROLON) then
            callClientFunction(player, "delegateEvent", player, quest, "processEvent_000_1");
        elseif (classId == PFARAHR) then
            callClientFunction(player, "delegateEvent", player, quest, "processEvent_010");
            quest:StartSequence(SEQ_001);
        end
       
    elseif (sequence == SEQ_001) then
        if (classId == VKOROLON) then
            callClientFunction(player, "delegateEvent", player, quest, "processEvent_020");
            callClientFunction(player, "delegateEvent", player, quest, "sqrwa", REWARD_EXP, 1, 1);
            player:AddExp(REWARD_EXP, player.charaWork.parameterSave.state_mainSkill[0], 0);
            player:CompleteQuest(quest);
        elseif (classId == PFARAHR) then
            callClientFunction(player, "delegateEvent", player, quest, "processEvent_010_1");
        end  
    end
    player:EndEvent()
	quest:UpdateENPCs();
end

function getJournalInformation(player, quest)
    local sequence = quest:getSequence();    
    if (sequence == SEQ_000) then
        return ITEM_WELL_WORN_BAG;
    end
end

function getJournalMapMarkerList(player, quest)
    local sequence = quest:getSequence();
    
    if (sequence == SEQ_000) then
        return MRKR_PFARAHR;
    elseif (sequence == SEQ_001) then
        return MRKR_VKOROLON;
    end    
end



