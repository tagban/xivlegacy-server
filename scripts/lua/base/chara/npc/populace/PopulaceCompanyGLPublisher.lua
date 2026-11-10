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

-- `npc` is the officer's actor class id. The value after the base class's
-- four is the client's work.townId (initForEvent): 1 Limsa Lominsa,
-- 2 Gridania, 3 Ul'dah, the same numbers as the companies.
function init(npc)
	return false, false, 0, 0, gcOfficer[npc] or 0;
end

gcOfficer = { 
[1500222] = 1, -- Storm Sergeant Hammil 
[1500223] = 1, -- Storm Sergeant Sternn 
[1500224] = 2, -- Serpent Sergeant Cordwyk 
[1500225] = 2, -- Serpent Sergeant Lodall  
[1500226] = 3, -- Flame Sergeant Byrne  
[1500227] = 3, -- Flame Sergeant Dalvag
}

-- Leve allowances shown in the welcome; the levemete shows the same
-- number (PopulaceGuildlevePublisher.lua). Allowances aren't tracked yet.
LEVE_ALLOWANCES = 0x29;

-- A member of the officer's company is offered "the mission currently
-- available": one of the company's leves at this officer's camp. As the
-- officer says, the duty begins the moment it is accepted: difficulty,
-- confirm, and the leve starts (crate::leve::battle). Others get
-- talkOutsider.
function onEventStarted(player, npc, triggerName)

	local gc = gcOfficer[npc:GetActorClassId()];
	if (gc == nil or player:GetGC() ~= gc) then
		callClientFunction(player, "talkOutsider");
		callClientFunction(player, "finishTalkTurn");
		player:EndEvent();
		return;
	end

	callClientFunction(player, "talkOfferWelcome", LEVE_ALLOWANCES);
	if (callClientFunction(player, "askCompanyLeve") == 1) then
		local leveId = GetCompanyLeveOffer(gc, npc:GetZoneID());
		if (leveId == nil) then
			player:SendMessage(0x20, "", "There are no company leves available here right now.");
		elseif (player:GetGuildleve() ~= nil) then
			player:SendMessage(0x20, "", "You are already on a levequest.");
		else
			::DETAIL::
			local accepted = callClientFunction(player, "askLeveDetail", leveId, 0, 0, 0, 0, 0, 0, false);
			if (accepted == true) then
				::DIFFICULTY::
				local difficulty = callClientFunction(player, "eventGLDifficulty", leveId);
				if (difficulty == nil) then goto DETAIL; end
				if (callClientFunction(player, "eventGLStart", leveId, difficulty, 0) == nil) then
					goto DIFFICULTY;
				end
				player:AddGuildleve(leveId);
				player:StartGuildleve(leveId, difficulty);
				callClientFunction(player, "talkAfterOffer");
			end
		end
	end

	callClientFunction(player, "finishTalkTurn");
	player:EndEvent();
end
