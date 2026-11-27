-- Quest steps that wait for an emote: the right emote moves the step, any
-- other emote does nothing for the quest. (The server only asks a quest
-- about an emote at an NPC whose emote events that quest turned on; these
-- specs cover each script's own step check.)

-- Souls Gone Wild (Man0g1) SEQ_050: the BTN guild kids each want one emote.
-- Each kid's actor class has a single emote condition (emoteDefault1), so
-- the client only sends it for that kid's emote: Aunille beckon (108),
-- Nicollaux clap (107), Sansa bow (105), Powle cheer (106), Ryd surprised
-- (101), Elyn lookout (122).
local AUNILLE   = 1000410
local NICOLLAUX = 1000409
local SANSA     = 1000239
local POWLE     = 1000238
local RYD       = 1000412
local ELYN      = 1000411

describe("Souls Gone Wild (Man0g1) - the kids' emotes", function()
    it("SEQ_050: each kid's emote, then the dance finale", function()
        local w = walkthrough.start("Man0g1", 50)
        w:emote(AUNILLE, "emoteDefault1"):expectDelegate("processEvent142_1"):ack()
            :expectFlagSet(1)
        -- the same kid again: already done, nothing moves
        w:emote(AUNILLE, "emoteDefault1"):expectNoProgress()
        w:emote(NICOLLAUX, "emoteDefault1"):expectDelegate("processEvent142_2"):ack()
        w:emote(SANSA, "emoteDefault1"):expectDelegate("processEvent142_3"):ack()
        w:emote(POWLE, "emoteDefault1"):expectDelegate("processEvent142_4"):ack()
        w:emote(RYD, "emoteDefault1"):expectDelegate("processEvent142_5"):ack()
        w:emote(ELYN, "emoteDefault1"):expectDelegate("processEvent142_6"):ack()
            :expectDelegate("processEvent150"):ack():expectStartSequence(55)
    end)

    it("SEQ_055: the emote flags stay set, and an emote no longer replays the finale", function()
        local w = walkthrough.start("Man0g1", 50)
        for _, kid in ipairs({AUNILLE, NICOLLAUX, SANSA, POWLE, RYD}) do
            w:emote(kid, "emoteDefault1"):ack()
        end
        w:emote(ELYN, "emoteDefault1"):ack():ack():expectSequence(55)
        -- Before the fix this replayed processEvent150 and StartSequence(55)
        -- plus the warp into the past, for any emote event at all.
        w:emote(SANSA, "emoteDefault1"):expectNoProgress()
        w:emote(1500199, "emoteDefault1"):expectNoProgress() -- a company officer's salute
        w:expectSequence(55)
    end)
end)

-- Bombard Backlash (Spl102): the 2012 Bombards carry two emote conditions,
-- /dance (111, emoteDefault1) and the fire dance (156, emoteDefault2). The
-- Firedancers teach the fire dance, and only it banishes a Bombard.
local BOMBARD_2012 = 2201611
local KING_2012    = 2201612
local FLAG_PENDING_FST      = 1 -- FLAG_PENDING + Gridania (city 1)
local FLAG_KING_PENDING_FST = 4 -- FLAG_KING_PENDING + Gridania

describe("Bombard Backlash (Spl102) - the fire dance", function()
    it("a plain /dance at a Bombard does nothing for the quest", function()
        local w = walkthrough.start("Spl102", 0)
        w:emote(BOMBARD_2012, "emoteDefault1"):expectNoProgress()
        w:emote(KING_2012, "emoteDefault1"):expectNoProgress()
        w:emote(KING_2012, "emoteDefault1"):expectNoProgress()
        w:emote(KING_2012, "emoteDefault1"):expectNoProgress()
    end)

    it("the fire dance bursts a Bombard; a King takes three", function()
        local w = walkthrough.start("Spl102", 0)
        w:emote(BOMBARD_2012, "emoteDefault2"):expectFlagSet(FLAG_PENDING_FST)
        w:emote(KING_2012, "emoteDefault2")
        w:emote(KING_2012, "emoteDefault2")
        w:emote(KING_2012, "emoteDefault2"):expectFlagSet(FLAG_KING_PENDING_FST)
    end)
end)
