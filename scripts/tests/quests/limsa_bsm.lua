-- Blacksmiths' Guild quests at Naldiq & Vymelli's: Bsm200, Bsm300, Bsm306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Each case seeds the
-- sequence it walks; crafted pieces are put in the bag with `give`.

-- Actor class ids (from scripts/lua/quests/bsm/*.lua).
local BODENOLF      = 1000144
local MIMIDOA       = 1000176
local IOFA          = 1000135
local CARRILAUT     = 1000062
local MZIMZIZI      = 1000061
local PFYNHAEMR     = 1000060
local SOSOZE        = 1000265
local HIHINE        = 1000267
local GAUTZELIN     = 1000365
local LINETTE       = 1000861
local ZSSAPA_CIRCLE = 1091140
local CAVEIN_CIRCLE = 1091141
local FERRY_CIRCLE  = 1091142

local GRAMOPHONE_CASE = 11000004
local TREMBLER        = 11000005
local WINDWHEEL       = 11000022
local EARPLUG_MOLD    = 11000050
local RUBBER          = 11000052

describe("An Ear for Quality (Bsm200)", function()
    it("offer: Bodenolf signs you on and sends you up to Mimidoa", function()
        local w = walkthrough.start("Bsm200", 65535)

        w:stateChange(65535):expectEnpc(BODENOLF, QFLAG_TALK)
        w:talk(BODENOLF):expectDelegate("processEventBodenolfStart"):answer(1)
    end)

    it("SEQ_000: the forge's chatter, then Mimidoa's test", function()
        local w = walkthrough.start("Bsm200", 0)
        w:expectMarkers(11032001)

        w:stateChange(0)
            :expectEnpc(MIMIDOA, QFLAG_TALK)
            :expectEnpc(BODENOLF, 0)
        w:talk(CARRILAUT):expectDelegate("processEvent005_3"):ack()
        w:talk(SOSOZE):expectDelegate("processEvent005_8"):ack()
        w:talk(BODENOLF):expectDelegate("processEvent005"):answer(2)
        w:talk(MIMIDOA):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_000: Bodenolf sends you up again", function()
        local w = walkthrough.start("Bsm200", 0)

        w:talk(BODENOLF):expectDelegate("processEvent005"):answer(1)
    end)

    it("SEQ_010: no gramophone case yet", function()
        local w = walkthrough.start("Bsm200", 10)
        w:expectMarkers(11032002)

        w:stateChange(10):expectEnpc(MIMIDOA, QFLAG_TALK)
        w:talk(MIMIDOA):expectDelegate("processEvent007_2"):ack():expectNoRemoveItem()
        w:talk(PFYNHAEMR):expectDelegate("processEvent010_7"):ack()
    end)

    it("SEQ_010: the gramophone case, and on to the trembler", function()
        local w = walkthrough.start("Bsm200", 10)

        w:give(GRAMOPHONE_CASE)
        w:talk(MIMIDOA):expectDelegate("processEventS010_1"):ack()
            :expectRemoveItem(GRAMOPHONE_CASE, 1)
            :expectStartSequence(15)
    end)

    it("SEQ_015: Iofa's recipe, then his reminder", function()
        local w = walkthrough.start("Bsm200", 15)
        w:expectMarkers(11032003)

        w:stateChange(15)
            :expectEnpc(IOFA, QFLAG_TALK)
            :expectEnpc(MIMIDOA, QFLAG_REWARD)
        w:talk(IOFA):expectDelegate("processEventS015_1"):ack():expectFlagSet(0)
        w:talk(IOFA):expectDelegate("processEvent018_1"):ack()
        w:talk(MIMIDOA):expectDelegate("processEventS010_7"):ack():expectNoRemoveItem()
    end)

    it("SEQ_015: the trembler, and payment", function()
        local w = walkthrough.start("Bsm200", 15)

        w:give(TREMBLER)
        w:talk(MIMIDOA):expectDelegate("processEvent020"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectRemoveItem(TREMBLER, 1)
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110320)
    end)
end)

describe("Song of the Sirens (Bsm300)", function()
    it("offer: Bodenolf says Mimidoa needs a hand", function()
        local w = walkthrough.start("Bsm300", 65535)

        w:stateChange(65535):expectEnpc(BODENOLF, QFLAG_TALK)
        w:talk(BODENOLF):expectDelegate("processEventBodenolfStart"):answer(1)
    end)

    it("SEQ_000: the forge's chatter, then Mimidoa's errand", function()
        local w = walkthrough.start("Bsm300", 0)

        w:stateChange(0):expectEnpc(MIMIDOA, QFLAG_TALK)
        w:talk(PFYNHAEMR):expectDelegate("processEvent001_7_1"):ack()
        w:talk(GAUTZELIN):expectDelegate("processEvent001_11"):ack()
        w:talk(MIMIDOA):expectDelegate("processEvent003"):ack():expectStartSequence(3)
    end)

    it("SEQ_003: Linette refuses, Mimidoa calls", function()
        local w = walkthrough.start("Bsm300", 3)

        w:stateChange(3):expectEnpc(LINETTE, QFLAG_TALK)
        w:talk(MIMIDOA):expectDelegate("processEvent003_10"):ack()
        w:talk(LINETTE):expectDelegate("processEvent004_1"):ack()
            :expectDelegate("processEvent006"):ack()
            :expectStartSequence(6)
    end)

    it("SEQ_006: Z'ssapa and the cave-in", function()
        local w = walkthrough.start("Bsm300", 6)
        w:expectMarkers(11032101)

        w:stateChange(6):expectEnpc(ZSSAPA_CIRCLE, QFLAG_PUSH)
        w:talk(LINETTE):expectDelegate("processEvent004_2"):ack()
        w:push(ZSSAPA_CIRCLE):expectDelegate("processEvent007"):ack()
            :expectDelegate("processEvent010"):ack()
            :expectStartSequence(9)
    end)

    it("SEQ_009: the trapped miner, and the ore", function()
        local w = walkthrough.start("Bsm300", 9)
        w:expectMarkers(11032102)

        w:stateChange(9):expectEnpc(CAVEIN_CIRCLE, QFLAG_PUSH)
        w:push(CAVEIN_CIRCLE):expectDelegate("processEvent009"):ack()
            :expectDelegate("processEvent020"):ack()
            :expectStartSequence(15)
    end)

    it("SEQ_015: the ore to Mimidoa, the windwheel to deliver", function()
        local w = walkthrough.start("Bsm300", 15)

        w:stateChange(15):expectEnpc(MIMIDOA, QFLAG_TALK)
        w:talk(CARRILAUT):expectDelegate("processEvent010_3"):ack()
        w:talk(MIMIDOA):expectDelegate("processEvent015"):ack()
            :expectAddItem(WINDWHEEL, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: the ferry captain and the sirens' waters", function()
        local w = walkthrough.start("Bsm300", 20)
        w:expectMarkers(11032103)

        w:give(WINDWHEEL)
        w:stateChange(20):expectEnpc(FERRY_CIRCLE, QFLAG_PUSH)
        w:push(FERRY_CIRCLE):expectDelegate("processEvent030"):ack()
            :expectRemoveItem(WINDWHEEL, 1)
            :expectStartSequence(30)
    end)

    it("SEQ_030: the melody, and payment", function()
        local w = walkthrough.start("Bsm300", 30)

        w:stateChange(30):expectEnpc(MIMIDOA, QFLAG_REWARD)
        w:talk(HIHINE):expectDelegate("processEvent030_9"):ack()
        w:talk(MIMIDOA):expectDelegate("processEvent040"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110321)
    end)
end)

describe("The Sound of Silence (Bsm306)", function()
    it("offer: Bodenolf has more siren work", function()
        local w = walkthrough.start("Bsm306", 65535)

        w:stateChange(65535):expectEnpc(BODENOLF, QFLAG_TALK)
        w:talk(BODENOLF):expectDelegate("processEventBodenolfStart"):answer(1)
    end)

    it("SEQ_000: the forge's quarrel, then Mimidoa's rubber", function()
        local w = walkthrough.start("Bsm306", 0)

        w:stateChange(0):expectEnpc(MIMIDOA, QFLAG_TALK)
        w:talk(IOFA):expectDelegate("processEvent003_5_1"):ack()
        w:talk(MZIMZIZI):expectDelegate("processEvent003_4"):ack()
        w:talk(MIMIDOA):expectDelegate("processEvent005"):ack()
            :expectAddItem(RUBBER, 1)
            :expectStartSequence(5)
    end)

    it("SEQ_005: no mold yet", function()
        local w = walkthrough.start("Bsm306", 5)
        w:expectMarkers(11032201)

        w:stateChange(5):expectEnpc(MIMIDOA, QFLAG_TALK)
        w:talk(MIMIDOA):expectDelegate("processEvent005_6"):ack():expectNoRemoveItem()
    end)

    it("SEQ_005: the mold, Hope's Bourn, and back at the forge", function()
        local w = walkthrough.start("Bsm306", 5)

        w:give(EARPLUG_MOLD)
        w:give(RUBBER)
        w:talk(MIMIDOA):expectDelegate("processEvent010"):ack()
            :expectDelegate("processEvent020"):ack()
            :expectDelegate("processEvent030"):ack()
            :expectRemoveItem(EARPLUG_MOLD, 1)
            :expectRemoveItem(RUBBER, 1)
            :expectStartSequence(30)
    end)

    it("SEQ_030: the forge's word, the gramophone, and payment", function()
        local w = walkthrough.start("Bsm306", 30)
        w:expectMarkers(11032205)

        w:stateChange(30):expectEnpc(MIMIDOA, QFLAG_REWARD)
        w:talk(SOSOZE):expectDelegate("processEvent030_8"):ack()
        w:talk(MIMIDOA):expectDelegate("processEvent040"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110322)
    end)
end)
