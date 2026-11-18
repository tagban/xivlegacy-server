require ("global")
require ("quest")

--[[

Quest Script

Name: 	By Fire Reborn
Code: 	Com0u7
Id: 	111807
Prereq: Com0u6 complete, level 25; not sworn to any Grand Company.

Official enlistment. Flame Lieutenant Aubrey asks a recruit to swear sole
allegiance to the Immortal Flames: doing so ends any recruit standing with
the other companies and makes you a Private Third Class (rank 11), with the
company's full shop, chocobo stables and promotions open to you. He then
offers an overview of a member's duties. Done in that one talk.

]]

SEQ_000					= 0;

AUBREY					= 1500198;
COMPANY					= 3;
RANK_PRIVATE_THIRD		= 11;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(AUBREY, QFLAG_TALK);
	end
end

function onTalk(player, quest, npc)
	if (quest:getSequence() == SEQ_ACCEPT and npc:GetActorClassId() == AUBREY) then
		local sworn = callClientFunction(player, "delegateEvent", player, quest, "processEventAubreyStart");
		if (sworn == 1) then
			player:AcceptQuest(quest, true);
			player:JoinGC(COMPANY);
			player:SetGCRank(COMPANY, RANK_PRIVATE_THIRD);
			callClientFunction(player, "delegateEvent", player, quest, "processEventAubreyEnd");
			player:EndEvent();
			player:CompleteQuest(quest);
			return;
		end
	end
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
