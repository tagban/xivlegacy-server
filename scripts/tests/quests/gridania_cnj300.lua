-- Conjurers' Guild: "Good Knight, Sweet Dreams" (Cnj300).
--
-- Quest-hook legs only (the `walkthrough` bridge). The elementals at
-- Amberscale Rock run on the content substrate (SimpleContentCnj30001,
-- directed by QuestDirectorCnj30001); the leg after it is seeded at SEQ_017.

-- Actor class ids (from scripts/lua/quests/cnj/cnj300.lua).
local SOILEINE       = 1000234
local HETZKIN        = 1000460
local YUHELMERIC     = 1000370
local LIFEMEND_STUMP = 1090650
local AMBERSCALE     = 1090651
local KNIGHT         = 1090652
local FOREST_EDGE    = 1090653

describe("Good Knight, Sweet Dreams (Cnj300)", function()
    it("offer: Soileine sends you to scout the wood", function()
        local w = walkthrough.start("Cnj300", 65535)
        w:stateChange(65535):expectEnpc(SOILEINE, QFLAG_TALK)
        w:talk(SOILEINE):expectDelegate("processEventSoileineStart"):answer(1)
    end)

    it("SEQ_005: Morys at Lifemend Stump", function()
        local w = walkthrough.start("Cnj300", 5)
        w:stateChange(5):expectEnpc(LIFEMEND_STUMP, QFLAG_PUSH):expectEnpc(SOILEINE, QFLAG_NONE)
        w:expectMarkers(11026101)
        w:talk(SOILEINE):expectDelegate("processEvent005_2"):ack()
        w:talk(HETZKIN):expectDelegate("processEvent005_3"):ack()
        w:push(LIFEMEND_STUMP):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Soileine points to Amberscale Rock", function()
        local w = walkthrough.start("Cnj300", 10)
        w:stateChange(10):expectEnpc(SOILEINE, QFLAG_TALK)
        w:expectMarkers(11026102)
        w:talk(SOILEINE):expectDelegate("processEvent010_2"):ack():expectStartSequence(15)
    end)

    it("SEQ_015: Morys among the elementals, into the fight", function()
        local w = walkthrough.start("Cnj300", 15)
        w:stateChange(15):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:expectMarkers(11026103)
        w:talk(HETZKIN):expectDelegate("processEvent020_6"):ack()
        w:push(AMBERSCALE):expectDelegate("processEvent015_1"):ack()
            :expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_017: the fallen knight", function()
        local w = walkthrough.start("Cnj300", 17)
        w:stateChange(17):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:push(AMBERSCALE):expectDelegate("processEvent020"):ack():expectStartSequence(20)
    end)

    it("SEQ_020: Soileine and Ingram send you to Owl's Nest", function()
        local w = walkthrough.start("Cnj300", 20)
        w:stateChange(20):expectEnpc(SOILEINE, QFLAG_TALK)
        w:expectMarkers(11026104)
        w:talk(SOILEINE):expectDelegate("processEvent030"):ack():expectStartSequence(30)
    end)

    it("SEQ_030: Ser Yuhelmeric", function()
        local w = walkthrough.start("Cnj300", 30)
        w:stateChange(30):expectEnpc(YUHELMERIC, QFLAG_TALK)
        w:expectMarkers(11026105)
        w:talk(SOILEINE):expectDelegate("processEvent030_2"):ack()
        w:talk(HETZKIN):expectDelegate("processEvent030_3"):ack()
        w:talk(YUHELMERIC):expectDelegate("processEvent040"):ack():expectStartSequence(40)
    end)

    it("SEQ_040: the knight's tale, and the Echo", function()
        local w = walkthrough.start("Cnj300", 40)
        w:stateChange(40):expectEnpc(KNIGHT, QFLAG_PUSH)
        w:expectMarkers(11026106)
        w:talk(YUHELMERIC):expectDelegate("processEvent040_1"):ack()
        -- Turning the Echo down leaves the knight waiting.
        w:push(KNIGHT):expectDelegate("processEvent050"):answer(0)
        w:expectSequence(40)
        w:push(KNIGHT):expectDelegate("processEvent050"):answer(1):expectStartSequence(50)
    end)

    it("SEQ_050: Morys at the forest's edge", function()
        local w = walkthrough.start("Cnj300", 50)
        w:stateChange(50):expectEnpc(FOREST_EDGE, QFLAG_PUSH)
        w:expectMarkers(11026107)
        w:talk(SOILEINE):expectDelegate("processEvent050_2"):ack()
        w:talk(YUHELMERIC):expectDelegate("processEvent050_1"):ack()
        w:push(FOREST_EDGE):expectDelegate("processEvent060"):ack():expectStartSequence(60)
    end)

    it("SEQ_060: Soileine's thanks, and the reward", function()
        local w = walkthrough.start("Cnj300", 60)
        w:stateChange(60):expectEnpc(SOILEINE, QFLAG_REWARD)
        w:expectMarkers(11026108)
        w:talk(SOILEINE):expectDelegate("processEvent070"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(3000)
            :expectGil(30000)
            :expectCompleted(110261)
    end)
end)
