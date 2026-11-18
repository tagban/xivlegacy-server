require ("global")
require ("quest")

--[[

Quest Script

Name: 	Till Sea Swallows All
Code: 	Com0l7
Id: 	111407
Prereq: Com0l6 complete, level 25; not sworn to any Grand Company.

Official enlistment. Storm Lieutenant Guincum asks a recruit to swear sole
allegiance to the Maelstrom: doing so ends any recruit standing with
the other companies and makes you a Private Third Class (rank 11), with the
company's full shop, chocobo stables and promotions open to you. He then
offers an overview of a member's duties. Done in that one talk.

]]

SEQ_000					= 0;

GUINCUM					= 1500199;
COMPANY					= 1;
RANK_PRIVATE_THIRD		= 11;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(GUINCUM, QFLAG_TALK);
	end
end

function onTalk(player, quest, npc)
	if (quest:getSequence() == SEQ_ACCEPT and npc:GetActorClassId() == GUINCUM) then
		local sworn = callClientFunction(player, "delegateEvent", player, quest, "processEventGuincamStart");
		if (sworn == 1) then
			player:AcceptQuest(quest, true);
			player:JoinGC(COMPANY);
			player:SetGCRank(COMPANY, RANK_PRIVATE_THIRD);
			callClientFunction(player, "delegateEvent", player, quest, "processEventGuincamEnd");
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
