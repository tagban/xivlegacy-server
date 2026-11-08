-- Conjurers' Guild: "The Call of Nature" (Cnj306).
--
-- Quest-hook legs only (the `walkthrough` bridge). The dreadwolves in the
-- Echo run on the content substrate (SimpleContentCnj30602, directed by
-- QuestDirectorCnj30602); the leg after it is seeded at SEQ_055.

-- Actor class ids (from scripts/lua/quests/cnj/cnj306.lua).
local SOILEINE     = 1000234
local HETZKIN      = 1000460
local INGRAM       = 1000372
local AMBERSCALE   = 1090651
local EMERALD_MOSS = 1090658

describe("The Call of Nature (Cnj306)", function()
    it("offer: Soileine asks you to test your potential", function()
        local w = walkthrough.start("Cnj306", 65535)
        w:stateChange(65535):expectEnpc(SOILEINE, QFLAG_TALK)
        w:talk(SOILEINE):expectDelegate("processEventSoileineStart"):answer(1)
    end)

    it("SEQ_000: Brother Ingram teaches you to listen", function()
        local w = walkthrough.start("Cnj306", 0)
        w:stateChange(0):expectEnpc(INGRAM, QFLAG_TALK):expectEnpc(SOILEINE, QFLAG_NONE)
        w:expectMarkers(11026201)
        w:talk(SOILEINE):expectDelegate("processEvent005_2"):ack()
        w:talk(HETZKIN):expectDelegate("processEvent005_3"):ack()
        w:talk(INGRAM):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Morys at Amberscale Rock asks you to Ishgard", function()
        local w = walkthrough.start("Cnj306", 10)
        w:stateChange(10):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:expectMarkers(11026202)
        w:talk(INGRAM):expectDelegate("processEvent010_2"):ack()
        w:talk(SOILEINE):expectDelegate("processEvent010_3"):ack()
        -- Turning him down leaves him waiting.
        w:push(AMBERSCALE):expectDelegate("processEvent020"):ack()
            :expectDelegate("processEvent025"):answer(0)
        w:expectSequence(10)
        w:push(AMBERSCALE):expectDelegate("processEvent020"):ack()
            :expectDelegate("processEvent025"):answer(1):expectStartSequence(20)
    end)

    it("SEQ_020: setting out from Camp Emerald Moss", function()
        local w = walkthrough.start("Cnj306", 20)
        w:stateChange(20):expectEnpc(EMERALD_MOSS, QFLAG_PUSH)
        w:expectMarkers(11026203)
        w:push(EMERALD_MOSS):expectDelegate("processEvent030"):ack():expectStartSequence(30)
    end)

    it("SEQ_030: Morys fallen among the elementals", function()
        local w = walkthrough.start("Cnj306", 30)
        w:stateChange(30):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:expectMarkers(11026204)
        w:talk(SOILEINE):expectDelegate("processEvent030_2"):ack()
        w:talk(INGRAM):expectDelegate("processEvent030_3"):ack()
        w:talk(HETZKIN):expectDelegate("processEvent070_2"):ack()
        w:push(AMBERSCALE):expectDelegate("processEvent040"):ack():expectStartSequence(40)
    end)

    it("SEQ_040: the Echo on Morys", function()
        local w = walkthrough.start("Cnj306", 40)
        w:stateChange(40):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:expectMarkers(11026205)
        -- Turning the Echo down leaves him lying there.
        w:push(AMBERSCALE):expectDelegate("processEvent045"):answer(0)
        w:expectSequence(40)
        w:push(AMBERSCALE):expectDelegate("processEvent045"):answer(1)
            :expectDelegate("processEvent050"):ack():expectStartSequence(50)
    end)

    it("SEQ_050: the dreadwolves and the boy, into the fight", function()
        local w = walkthrough.start("Cnj306", 50)
        w:stateChange(50):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:expectMarkers(11026206)
        w:push(AMBERSCALE):expectDelegate("processEvent060"):ack()
            :expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_055: the boy taken by the wood", function()
        local w = walkthrough.start("Cnj306", 55)
        w:stateChange(55):expectEnpc(AMBERSCALE, QFLAG_PUSH)
        w:push(AMBERSCALE):expectDelegate("processEvent070"):ack():expectStartSequence(60)
    end)

    it("SEQ_060: Brother Ingram swears you to secrecy", function()
        local w = walkthrough.start("Cnj306", 60)
        w:stateChange(60):expectEnpc(INGRAM, QFLAG_TALK)
        w:expectMarkers(11026208)
        w:talk(SOILEINE):expectDelegate("processEvent070_5"):ack()
        w:talk(INGRAM):expectDelegate("processEvent080"):ack():expectStartSequence(70)
    end)

    it("SEQ_070: Soileine's reward", function()
        local w = walkthrough.start("Cnj306", 70)
        w:stateChange(70):expectEnpc(SOILEINE, QFLAG_REWARD)
        w:expectMarkers(11026209)
        w:talk(SOILEINE):expectDelegate("processEvent095"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(3600)
            :expectGil(36000)
            :expectCompleted(110262)
    end)
end)
