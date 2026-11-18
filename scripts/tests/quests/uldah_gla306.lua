-- Gladiators' Guild: "Thrill of the Fight" (Gla306).
--
-- Quest-hook legs only (the `walkthrough` bridge). The two bouts (the
-- tourney, SimpleContentGla30601, and the Echo rematch,
-- SimpleContentGla30602) run on the content substrate; the legs after them
-- are seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/gla/gla306.lua).
local LULUTSU      = 1000863
local GALEREN      = 1000963
local JAJANZO      = 1000654
local YOYOBINA     = 1000927
local CHALLENGER   = 1000601
local PIKEMAN      = 1001978
local SHAMAN       = 1001981
local ARENA_DOORS  = 1090500
local BAZAAR_CROWD = 1090517

describe("Thrill of the Fight (Gla306)", function()
    it("offer: Lulutsu calls your debut", function()
        local w = walkthrough.start("Gla306", 65535)

        w:stateChange(65535):expectEnpc(LULUTSU, QFLAG_TALK)
        w:talk(LULUTSU):expectDelegate("processEventLulutsuStart"):answer(1)
    end)

    it("SEQ_000/003: Yoyobina, the other gladiators, and the call to the sands", function()
        local w = walkthrough.start("Gla306", 0)

        w:stateChange(0):expectEnpc(YOYOBINA, QFLAG_TALK)
        w:expectMarkers(11008203)
        w:talk(LULUTSU):expectDelegate("processEvent000_1"):ack()
        w:talk(YOYOBINA):expectDelegate("processEvent003"):ack():expectStartSequence(3)

        w:stateChange(3):expectEnpc(YOYOBINA, QFLAG_TALK)
        w:talk(JAJANZO):expectDelegate("processEvent003_3"):ack()
        w:talk(GALEREN):expectDelegate("processEvent003_10"):ack()
        w:talk(YOYOBINA):expectDelegate("processEvent005"):answer(1):expectStartSequence(5)
    end)

    it("SEQ_005: through the doors into the tourney bout", function()
        local w = walkthrough.start("Gla306", 5)

        w:stateChange(5):expectEnpc(ARENA_DOORS, QFLAG_PUSH)
        w:expectMarkers(11008201)
        w:push(ARENA_DOORS):expectDelegate("processEvent010"):ack()
            :expectStartSequence(10)
            :expectCreateContentArea()
            :expectZoneChangeContent()
    end)

    it("SEQ_010: after a lost bout, Yoyobina's word and another try", function()
        local w = walkthrough.start("Gla306", 10)

        w:stateChange(10)
            :expectEnpc(YOYOBINA, QFLAG_TALK)
            :expectEnpc(ARENA_DOORS, QFLAG_PUSH)
        w:talk(LULUTSU):expectDelegate("processEvent003_12"):ack()
        w:talk(YOYOBINA):expectDelegate("processEvent020_999"):ack():expectStartSequence(5)
    end)

    it("SEQ_020/023: the Lalafell, and the Echo rematch", function()
        local w = walkthrough.start("Gla306", 20)

        w:stateChange(20):expectEnpc(YOYOBINA, QFLAG_TALK)
        w:talk(CHALLENGER):expectDelegate("processEvent020_4"):ack()
        w:talk(PIKEMAN):expectDelegate("processEvent020_2"):ack()
        w:talk(YOYOBINA):expectDelegate("processEvent023"):ack():expectStartSequence(23)

        w:stateChange(23):expectEnpc(CHALLENGER, QFLAG_TALK)
        w:talk(YOYOBINA):expectDelegate("processEvent023_2"):ack()
        w:talk(CHALLENGER):expectDelegate("processEvent024"):answer(1)
            :expectStartSequence(24)
            :expectCreateContentArea()
            :expectZoneChangeContent()
    end)

    it("SEQ_025/030: the report, then his match from the stands", function()
        local w = walkthrough.start("Gla306", 25)

        w:stateChange(25):expectEnpc(YOYOBINA, QFLAG_TALK)
        w:talk(YOYOBINA):expectDelegate("processEvent030"):ack():expectStartSequence(30)

        w:stateChange(30):expectEnpc(ARENA_DOORS, QFLAG_PUSH)
        w:expectMarkers(11008205)
        w:push(ARENA_DOORS):expectDelegate("processEvent040"):ack():expectStartSequence(40)
    end)

    it("SEQ_040/045: the Echo at the Silver Bazaar", function()
        local w = walkthrough.start("Gla306", 40)

        w:stateChange(40):expectEnpc(CHALLENGER, QFLAG_TALK)
        w:talk(YOYOBINA):expectDelegate("processEvent040_2"):ack()
        w:talk(CHALLENGER):expectDelegate("processEvent045"):answer(1):expectStartSequence(45)

        w:stateChange(45):expectEnpc(BAZAAR_CROWD, QFLAG_PUSH)
        w:expectMarkers(11008206)
        w:talk(SHAMAN):expectDelegate("processEvent045_5"):ack()
        w:push(BAZAAR_CROWD):expectDelegate("processEvent050"):ack():expectStartSequence(50)
    end)

    it("SEQ_050: Lulutsu's reward", function()
        local w = walkthrough.start("Gla306", 50)

        w:stateChange(50):expectEnpc(LULUTSU, QFLAG_REWARD)
        w:talk(JAJANZO):expectDelegate("processEvent050_3"):ack()
        w:talk(LULUTSU):expectDelegate("processEvent055"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectCompleted(110082)
    end)
end)
