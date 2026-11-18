-- Pugilists' Guild: "Two Sides to Every Chip" (Pgl306).
--
-- Quest-hook legs only (the `walkthrough` bridge). The thaumaturge on the
-- plateau runs on the content substrate (SimpleContentPgl30601, directed by
-- QuestDirectorPgl30601); the leg after it is seeded at SEQ_035.

-- Actor class ids (from scripts/lua/quests/pgl/pgl306.lua).
local GAGARUNA   = 1000862
local TITININ    = 1000934
local ENTRANCE   = 1090654
local HURREY     = 1090655
local HANDMAIDEN = 1090656
local PLATEAU    = 1090657

describe("Two Sides to Every Chip (Pgl306)", function()
    it("offer: Titinin's failed collector", function()
        local w = walkthrough.start("Pgl306", 65535)
        w:stateChange(65535):expectEnpc(GAGARUNA, QFLAG_TALK)
        w:talk(GAGARUNA):expectDelegate("processEventGagarunaStart"):answer(1)
    end)

    it("SEQ_010: the Mirage entrance", function()
        local w = walkthrough.start("Pgl306", 10)
        w:stateChange(10):expectEnpc(ENTRANCE, QFLAG_PUSH)
        w:expectMarkers(11006201)
        w:talk(GAGARUNA):expectDelegate("processEvent010_2"):ack()
        w:talk(TITININ):expectDelegate("processEvent010_9"):ack()
        w:push(ENTRANCE):expectDelegate("processEvent020"):ack():expectStartSequence(20)
    end)

    it("SEQ_020: the Echo on Hurrey, and the handmaiden's", function()
        local w = walkthrough.start("Pgl306", 20)
        w:stateChange(20):expectEnpc(HURREY, QFLAG_PUSH):expectEnpc(HANDMAIDEN, QFLAG_PUSH)
        w:expectMarkers(11006202)
        w:push(HANDMAIDEN):expectDelegate("processEvent040"):answer(1)
        w:expectSequence(20)
        w:push(HURREY):expectDelegate("processEvent030"):answer(0)
        w:expectSequence(20)
        w:push(HURREY):expectDelegate("processEvent030"):answer(1):expectStartSequence(30)
    end)

    it("SEQ_030: Lady Lewena on the plateau, into the fight", function()
        local w = walkthrough.start("Pgl306", 30)
        w:stateChange(30):expectEnpc(PLATEAU, QFLAG_PUSH)
        w:expectMarkers(11006203)
        w:push(PLATEAU):expectDelegate("processEvent050"):ack()
            :expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_035: the order of condemnation bought off", function()
        local w = walkthrough.start("Pgl306", 35)
        w:stateChange(35):expectEnpc(PLATEAU, QFLAG_PUSH)
        w:push(PLATEAU):expectDelegate("processEvent060"):ack():expectStartSequence(60)
    end)

    it("SEQ_060: Titinin hears the report", function()
        local w = walkthrough.start("Pgl306", 60)
        w:stateChange(60):expectEnpc(TITININ, QFLAG_TALK)
        w:expectMarkers(11006205)
        w:talk(GAGARUNA):expectDelegate("processEvent070_2"):ack()
        w:talk(TITININ):expectDelegate("processEvent070"):ack():expectStartSequence(70)
    end)

    it("SEQ_070: Gagaruna's tribute", function()
        local w = walkthrough.start("Pgl306", 70)
        w:stateChange(70):expectEnpc(GAGARUNA, QFLAG_REWARD)
        w:expectMarkers(11006206)
        w:talk(GAGARUNA):expectDelegate("processEvent080"):ack()
            :expectDelegate("processEvent090"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(3600)
            :expectGil(36000)
            :expectCompleted(110062)
    end)
end)
