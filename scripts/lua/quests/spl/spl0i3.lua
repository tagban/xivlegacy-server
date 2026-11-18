require ("global")
require ("quest")
require ("quests/spl/starlight")

--[[

Quest Script

Name: 	Winter Is Not Coming
Code: 	Spl0i3
Id: 	110801
Prereq: none. Seasonal: the Starlight Celebration (settings/events.toml).

A Black Rabbit Traders rep (Ninipu in Limsa Lominsa, Hastridie in
Gridania, Wysskoen in Ul'dah) is helping the conjurers stage Winter's
Knell, an Ala Mhigan festival that calls the winter by building a giant of
snow. Bring the rep 30 Ice Shards; the conjurers' receptacle turns them
into five ensorcelled snowballs. In Hyrstmill, Waldomar explains the
ritual: target Father Frost and throw the snowballs at him (the Snowball
emote; the 1.23b client rejects /snowball, so talking to him throws one
too). Waldomar thanks you with the reindeer outfit.

The counts and rewards are in quests/spl/starlight.lua.

]]

SEQ_000	= 0;	-- Bring the rep the Ice Shards.
SEQ_001	= 1;	-- Talk to Waldomar in Hyrstmill.
SEQ_002	= 2;	-- Throw the snowballs at Father Frost.
SEQ_003	= 3;	-- Report to Waldomar.

COUNTER_THROWN = 0;	-- snowballs thrown at Father Frost

local S = STARLIGHT;

function onStart(player, quest)
	quest:StartSequence(SEQ_000);
end

function onFinish(player, quest)
	-- abandoned or done: the snowballs go either way
	player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(S.SNOWBALL, 1);
end

function onStateChange(player, quest, sequence)
	if (sequence == SEQ_ACCEPT) then
		for rep in pairs(S.REPS) do
			quest:SetENpc(rep, QFLAG_TALK);
		end
		return;
	end

	-- the reps answer for the quest all the way through
	for rep in pairs(S.REPS) do
		quest:SetENpc(rep, (sequence == SEQ_000) and QFLAG_REWARD or QFLAG_NONE);
	end
	if (sequence == SEQ_001) then
		quest:SetENpc(S.WALDOMAR, QFLAG_TALK);
	elseif (sequence == SEQ_002) then
		quest:SetENpc(S.WALDOMAR);
		quest:SetENpc(S.FATHER_FROST, QFLAG_TALK, true, false, true);
	elseif (sequence == SEQ_003) then
		quest:SetENpc(S.WALDOMAR, QFLAG_REWARD);
		quest:SetENpc(S.FATHER_FROST, QFLAG_NONE, true, false, true);
	end
end

function onTalk(player, quest, npc, eventName)
	local classId = npc:GetActorClassId();
	local seq = quest:GetSequence();
	local rep = S.REPS[classId];

	if (seq == SEQ_ACCEPT) then
		if (rep ~= nil and IsSeasonalQuestOpen(SPL0I3_ID)) then
			if (callClientFunction(player, "delegateEvent", player, quest, rep.offer) == 1) then
				player:AcceptQuest(quest);
			end
		end
		player:EndEvent();
		return;
	end

	if (rep ~= nil) then
		if (seq == SEQ_000) then
			turnInShards(player, quest, rep.spl0i3);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventXmasitemAfter", rep.spl0i3);
		end
	elseif (classId == S.WALDOMAR) then
		if (seq == SEQ_001) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventXmas04");
			quest:StartSequence(SEQ_002);
		elseif (seq == SEQ_002) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventXmas04After");
		elseif (seq == SEQ_003) then
			callClientFunction(player, "delegateEvent", player, quest, "processEventClear");
			callClientFunction(player, "delegateEvent", player, quest, "sqrwa", S.SPL0I3_EXP, 1, 1);
			for _, item in ipairs(S.SPL0I3_REWARDS) do
				player:GetItemPackage(INVENTORY_NORMAL):AddItem(item, 1, 1);
			end
			player:CompleteQuest(quest);
		end
	elseif (classId == S.FATHER_FROST) then
		if (seq == SEQ_002) then
			-- the client won't take /snowball (see onEmote): a talk throws too
			throwSnowball(player, quest);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventSnowMandefo");
		end
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

-- The rep asks whether to hand over the shards (1 yes, 2 no); a yes is
-- checked against the player's crystals here.
function turnInShards(player, quest, city)
	local answer = callClientFunction(player, "delegateEvent", player, quest, "processEventStartAfter", city);
	local crystals = player:GetItemPackage(INVENTORY_CURRENCY);
	if (answer ~= 1) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventXmasitemNo", city);
	elseif (not crystals:HasItem(S.ICE_SHARD, S.ICE_SHARDS_NEEDED)) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventXmasitemNg", city);
	else
		crystals:RemoveItem(S.ICE_SHARD, S.ICE_SHARDS_NEEDED);
		callClientFunction(player, "delegateEvent", player, quest, "processEventXmasitem", city);
		player:GetItemPackage(INVENTORY_KEYITEMS):AddItem(S.SNOWBALL, 1, 1);
		quest:StartSequence(SEQ_001);
	end
end

-- A snowball at Father Frost: the Snowball emote (Father Frost's emote
-- condition), or a talk, since the 1.23b client rejects /snowball.
function onEmote(player, quest, npc, eventName)
	if (npc:GetActorClassId() == S.FATHER_FROST) then
		if (quest:GetSequence() == SEQ_002) then
			throwSnowball(player, quest);
		else
			callClientFunction(player, "delegateEvent", player, quest, "processEventSnowMandefo2");
		end
	end
	quest:UpdateENPCs();
	player:EndEvent();
end

function throwSnowball(player, quest)
	local left = S.SNOWBALLS - quest:GetData():IncCounter(COUNTER_THROWN);
	callClientFunction(player, "delegateEvent", player, quest, "processEventSnowMan");
	if (left > 0) then
		callClientFunction(player, "delegateEvent", player, quest, "processEventSnowManOk", left);
	else
		player:GetItemPackage(INVENTORY_KEYITEMS):RemoveItem(S.SNOWBALL, 1);
		attentionMessage(player, 25225, quest:GetQuestId()); -- Objectives complete!
		quest:StartSequence(SEQ_003);
	end
end
