--[[

PopulaceCompanyGLPublisher Script

xtx_gcRank for GC Rank values

Functions:

talkOutsider()                              - Dialog for no affiliated with GC.  Seems to always read Maelstrom?
talkOfferWelcome(unk1)                      - Errors
askCompanyLeve()                            - Errors
askLeveDetail(unk1, unk2, unk3, unk4, unk5, unk6, unk7, unk8)                             - Errors

eventGLDifficulty()                         - Difficulty window, returns player choice
eventGLStart(leveName, difficulty, unk1)    - leveName from xtx_guildleve

talkAfterOffer()
talkOfferLimit()

finishTalkTurn()                                            - Resets NPC target/facing

eventGLPlay(leveName, guardianFavor, favorCost, difficulty) - Menu for active levequest
eventGLShinpu(guardianFavor, favorCost)                     - Menu to accept favor buff.  evenGLPlay() calls it
eventGLThanks()                                             - Errors

eventGLReward(                      -- Leve reward screen
    guildleveId, 
    clearTime, 
    missionBonus, 
    difficultyBonus, 
    factionNumber, 
    factionBonus, 
    factionCredit, 
    glRewardItem, 
    glRewardNumber, 
    glRewardSubItem, 
    glRewardSubNumber, 
    difficulty
)


--]]

require ("global")

function init(npc)
	return false, false, 0, 0;	
end

gcOfficer = { 
[1500222] = 1, -- Storm Sergeant Hammil 
[1500223] = 1, -- Storm Sergeant Sternn 
[1500224] = 2, -- Serpent Sergeant Cordwyk 
[1500225] = 2, -- Serpent Sergeant Lodall  
[1500226] = 3, -- Flame Sergeant Byrne  
[1500227] = 3, -- Flame Sergeant Dalvag
}

-- A member of the officer's company is offered the company's leves one at
-- a time (askLeveDetail is the same journal card the levemete shows). An
-- accepted leve goes to the journal and is started at its camp aetheryte,
-- like a regional leve (AetheryteParent.lua). Others get talkOutsider.
function onEventStarted(player, npc, triggerName)

	local gc = gcOfficer[npc:GetActorClassId()];
	if (gc == nil or player:GetGC() ~= gc) then
		callClientFunction(player, "talkOutsider");
		callClientFunction(player, "finishTalkTurn");
		player:EndEvent();
		return;
	end

	callClientFunction(player, "talkOfferWelcome", 0);
	local offers = GetCompanyLeveOffers(gc);
	if (callClientFunction(player, "askCompanyLeve") == 1) then
		for i = 1, #offers do
			local leveId = offers[i];
			local accepted = callClientFunction(player, "askLeveDetail", leveId, 0, 0, 0, 0, 0, 0, false);
			if (accepted == true) then
				player:AddGuildleve(leveId);
				callClientFunction(player, "talkAfterOffer");
				break;
			elseif (accepted == nil) then
				break;
			end
		end
	end

	callClientFunction(player, "finishTalkTurn");
	player:EndEvent();
end
