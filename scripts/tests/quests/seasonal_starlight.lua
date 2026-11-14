-- Starlight Celebration: "Winter Is Not Coming" (Spl0i3) and "Gone with the
-- Snow" (Spl0i4). Quest-hook legs only; the walkthrough player owns no
-- items, so the Ice Shard turn-in is walked down its "not enough" branch
-- (the full turn-in is client-tested).

-- Actor class ids (from scripts/lua/quests/spl/starlight.lua).
local NINIPU       = 1001824
local HASTRIDIE    = 1001825
local WYSSKOEN     = 1001826
local WALDOMAR     = 1001827
local FATHER_FROST = 1200265
local SPOT_A       = 1090990
local SPOT_B       = 1090991
local SPOT_C       = 1090992
local HAMLET_GATE  = 1090993

describe("Winter Is Not Coming (Spl0i3)", function()
    it("offer: any of the three Black Rabbit Traders reps", function()
        local w = walkthrough.start("Spl0i3", 65535)
        w:stateChange(65535):expectEnpc(NINIPU, QFLAG_TALK)
            :expectEnpc(HASTRIDIE, QFLAG_TALK):expectEnpc(WYSSKOEN, QFLAG_TALK)
        w:talk(NINIPU):expectDelegate("processEventRimStart"):answer(1)
        w:talk(HASTRIDIE):expectDelegate("processEventGriStart"):answer(0)
        w:talk(WYSSKOEN):expectDelegate("processEventUldStart"):answer(1)
    end)

    it("SEQ_000: the rep asks for the Ice Shards", function()
        local w = walkthrough.start("Spl0i3", 0)
        w:stateChange(0):expectEnpc(HASTRIDIE, QFLAG_REWARD)
        -- "No" to handing them over
        w:talk(HASTRIDIE):expectDelegate("processEventStartAfter"):answer(2)
            :expectDelegate("processEventXmasitemNo"):ack()
        -- "Yes", but the player holds no shards
        w:talk(NINIPU):expectDelegate("processEventStartAfter"):answer(1)
            :expectDelegate("processEventXmasitemNg"):ack()
        w:expectSequence(0)
    end)

    it("SEQ_001: Waldomar explains Winter's Knell", function()
        local w = walkthrough.start("Spl0i3", 1)
        w:stateChange(1):expectEnpc(WALDOMAR, QFLAG_TALK)
        w:talk(WYSSKOEN):expectDelegate("processEventXmasitemAfter"):ack()
        w:talk(WALDOMAR):expectDelegate("processEventXmas04"):ack():expectStartSequence(2)
    end)

    it("SEQ_002: five snowballs at Father Frost", function()
        local w = walkthrough.start("Spl0i3", 2)
        w:stateChange(2):expectEnpc(FATHER_FROST, QFLAG_TALK)
        w:talk(WALDOMAR):expectDelegate("processEventXmas04After"):ack()
        -- a talk throws one too (the client rejects /snowball)
        w:talk(FATHER_FROST):expectDelegate("processEventSnowMan"):ack()
            :expectDelegate("processEventSnowManOk"):ack()
        for _ = 1, 3 do
            w:emote(FATHER_FROST, "emoteDefault1"):expectDelegate("processEventSnowMan"):ack()
                :expectDelegate("processEventSnowManOk"):ack()
        end
        w:expectSequence(2)
        w:emote(FATHER_FROST, "emoteDefault1"):expectDelegate("processEventSnowMan"):ack()
            :expectStartSequence(3)
    end)

    it("SEQ_003: Waldomar's present", function()
        local w = walkthrough.start("Spl0i3", 3)
        w:stateChange(3):expectEnpc(WALDOMAR, QFLAG_REWARD)
        w:talk(WALDOMAR):expectDelegate("processEventClear"):ack()
            :expectDelegate("sqrwa"):ack():expectCompleted(110801)
    end)
end)

describe("Gone with the Snow (Spl0i4)", function()
    it("offer: Waldomar", function()
        local w = walkthrough.start("Spl0i4", 65535)
        w:stateChange(65535):expectEnpc(WALDOMAR, QFLAG_TALK)
        w:talk(WALDOMAR):expectDelegate("processEventStart"):answer(1)
    end)

    it("SEQ_000: three hollows, then the hamlet's edge", function()
        local w = walkthrough.start("Spl0i4", 0)
        w:stateChange(0):expectEnpc(SPOT_A, QFLAG_PUSH):expectEnpc(SPOT_B, QFLAG_PUSH)
            :expectEnpc(SPOT_C, QFLAG_PUSH):expectNoEnpc(HAMLET_GATE)
        w:talk(WALDOMAR):expectDelegate("processEvent04"):ack()
        w:talk(NINIPU):expectDelegate("processEventHin"):ack()
        w:push(SPOT_A):expectDelegate("processEventA"):ack():expectFlagSet(0)
        w:push(SPOT_B):expectDelegate("processEventB"):ack():expectFlagSet(1)
        w:push(SPOT_C):expectDelegate("processEventC"):ack():expectFlagSet(2)
        w:stateChange(0):expectEnpc(HAMLET_GATE, QFLAG_PUSH)
        w:push(HAMLET_GATE):expectDelegate("processEventNQ"):ack():expectStartSequence(1)
    end)

    it("SEQ_001: the Heart of Winter back to Waldomar", function()
        local w = walkthrough.start("Spl0i4", 1)
        w:stateChange(1):expectEnpc(WALDOMAR, QFLAG_REWARD)
        w:talk(WALDOMAR):expectDelegate("processEventClear"):ack()
            :expectDelegate("sqrwa"):ack():expectCompleted(110802)
    end)
end)
