require ("global")
require ("quest")
require ("quests/spl/starlight")

--[[

Quest Script

Name: 	Gone with the Snow
Code: 	Spl0i4
Id: 	110802
Prereq: none. Seasonal: Heavensturn, after the Starlight Celebration
        (settings/events.toml).

The morning after Winter's Knell, Father Frost is gone, and with him the
Heart of Winter, an Ala Mhigan relic. Waldomar asks you to search
Hyrstmill. Three hollows in the ground (no meltwater, then something like a
giant footprint, then a trail) lead to the hamlet's edge, where the ice
elemental that slept in the gem speaks to you before going home to the
Twelveswood. Bring Waldomar the dulled gem; he gives you a Dragon Kabuto
and sends you to Black Rabbit Traders, whose reps each give one more
(quests/spl/starlight.lua, starlightRepTalk).

]]

SEQ_000	= 0;	-- Search Hyrstmill for clues.
SEQ_001	= 1;	-- Bring the Heart of Winter to Waldomar.

FLAG_SPOT_A	= 0;
FLAG_SPOT_B	= 1;
FLAG_SPOT_C	= 2;

local S = STARLIGHT;

-- each spot: its flag and the line the client says there
local SPOTS = {
	[S.SPOT_A] = {flag = FLAG_SPOT_A, event = "processEventA"},
	[S.SPOT_B] = {flag = FLAG_SPOT_B, event = "processEventB"},
	[S.SPOT_C] = {flag = FLAG_SPOT_C, event = "processEventC"},
};

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
	player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(S.HEART_OF_WINTER, 1);
end

local function allSpotsFound(data)
	return data:GetFlag(FLAG_SPOT_A) and data:GetFlag(FLAG_SPOT_B) and data:GetFlag(FLAG_SPOT_C);
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		quest:SetENpc(S.WALDOMAR, QFLAG_TALK);
		return;
	end
	local data = quest:GetData();
	if (sequence == SEQ_000) then
		quest:SetENpc(S.WALDOMAR);
		for id, spot in pairs(SPOTS) do
			if (not data:GetFlag(spot.flag)) then
				quest:SetENpc(id, QFLAG_PUSH, false, true);
			end
		end
		if (allSpotsFound(data)) then
			quest:SetENpc(S.HAMLET_GATE, QFLAG_PUSH, false, true);
		end
	elseif (sequence == SEQ_001) then
		quest:SetENpc(S.WALDOMAR, QFLAG_REWARD);
	end
	-- the reps hint while it runs
	for rep in pairs(S.REPS) do
		quest:SetENpc(rep);
	end
end

function onTalk(player, quest, npc, eventName)
	local classId = npc:GetActorClassId();
	local seq = quest:GetSequence();

	if (seq == SEQ_ACCEPT) then
		if (classId == S.WALDOMAR and IsSeasonalQuestOpen(SPL0I4_ID)) then
			-- 0 adds Waldomar's tears for a stranger (no Spl0i3)
			local helped = player:IsQuestCompleted(SPL0I3_ID) and 1 or 0;
			local a, b = callClientFunction(player, "delegateEvent", player, quest, "processEventStart", helped);
			if (a == 1 or b == 1) then
				player:AcceptQuest(quest);
			end
		end
		player:EndEvent();
		return;
	end

	local rep = S.REPS[classId];
	if (rep ~= nil) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventHin", rep.spl0i4, 1);
	elseif (classId == S.WALDOMAR) then
		if (seq == SEQ_000) then
			callClientFunction(player, "delegateEvent", player, quest, "processEvent04");
		elseif (seq == SEQ_001) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", S.SPL0I4_EXP, 1, 1);
			player:GetItemPackage(INVENTORY_NORMAL):AddItem(S.SPL0I4_REWARD, 1, 1);
			player:CompleteQuest(quest);
		end
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function onPush(player, quest, npc, eventName)
	local classId = npc:GetActorClassId();
	if (quest:GetSequence() ~= SEQ_000) then
		player:EndEvent();
		return;
	end
	local data = quest:GetData();
	local spot = SPOTS[classId];
	if (spot ~= nil and not data:GetFlag(spot.flag)) then
		callClientFunction(player, "delegateEvent", player, quest, spot.event);
		data:SetFlag(spot.flag);
	elseif (classId == S.HAMLET_GATE and allSpotsFound(data)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventNQ");
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(S.HEART_OF_WINTER, 1, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_001);
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function getJournalInformation(player, quest)
	return 0, 0, 0, 0, 0;
end

function getJournalMapMarkerList(player, quest)
end
