-- Weavers' Guild quests at Sunsilk Tapestries: Wvr200, Wvr300, Wvr306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Each case seeds the
-- sequence it walks; crafted pieces are put in the bag with `give`.

-- Actor class ids (from scripts/lua/quests/wvr/*.lua).
local DEAUSTIE         = 1000293
local LOHWAEB          = 1000644
local MARGARETE        = 1000645
local RINH_MAIMHOV     = 1000646
local CAHERNAUT        = 1000915
local ASPIPI           = 1000916
local GLOIUCEN         = 1000917
local CHUCHUMU         = 1000905
local CHUCHUMU_MINES   = 1000906
local SOILEINE         = 1000234
local THELDRY          = 1000379
local BAZAAR_CIRCLE    = 1091160
local GOLD_COURT       = 1091161

local RED_HOOD         = 11000054
local RIPPED_HOOD      = 11000055
local GLOVES           = 11000056
local SPIDER_SILK      = 11000057
local MIDNIGHT_SLIPPERS = 11000139

describe("Hoodwinked (Wvr200)", function()
    it("offer: Deaustie signs you on", function()
        local w = walkthrough.start("Wvr200", 65535)

        w:stateChange(65535):expectEnpc(DEAUSTIE, QFLAG_TALK)
        w:talk(DEAUSTIE):expectDelegate("processEventDeaustieStart"):answer(1)
    end)

    it("SEQ_000: the weavers' chatter, then Chuchumu at the Golden Bazaar", function()
        local w = walkthrough.start("Wvr200", 0)

        w:stateChange(0):expectEnpc(BAZAAR_CIRCLE, QFLAG_PUSH)
        w:expectMarkers(11040001)
        w:talk(DEAUSTIE):expectDelegate("processEvent005_2"):ack()
        w:talk(GLOIUCEN):expectDelegate("processEvent005_8"):ack()
        w:push(BAZAAR_CIRCLE):expectDelegate("processEvent010"):ack()
            :expectStartSequence(10)
    end)

    it("SEQ_010: Deaustie hands over the ripped hood", function()
        local w = walkthrough.start("Wvr200", 10)

        w:stateChange(10):expectEnpc(DEAUSTIE, QFLAG_TALK)
        w:expectMarkers(11040003)
        w:talk(DEAUSTIE):expectDelegate("processEvent010_2"):ack()
            :expectAddItem(RIPPED_HOOD, 1)
            :expectStartSequence(12)
    end)

    it("SEQ_012: no mended hood yet", function()
        local w = walkthrough.start("Wvr200", 12)

        w:stateChange(12):expectEnpc(BAZAAR_CIRCLE, QFLAG_PUSH)
        w:expectMarkers(11040002)
        w:talk(DEAUSTIE):expectDelegate("processEvent012_2"):ack()
        w:talk(MARGARETE):expectDelegate("processEvent020_3"):ack()
        w:push(BAZAAR_CIRCLE):expectNoRemoveItem()
    end)

    it("SEQ_012: the mended hood, and Lady Ouvielle", function()
        local w = walkthrough.start("Wvr200", 12)

        w:give(RED_HOOD)
        w:push(BAZAAR_CIRCLE):expectDelegate("processEvent020"):ack()
            :expectRemoveItem(RED_HOOD, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: payment at Sunsilk", function()
        local w = walkthrough.start("Wvr200", 20)

        w:stateChange(20):expectEnpc(DEAUSTIE, QFLAG_REWARD)
        w:talk(ASPIPI):expectDelegate("processEvent020_6"):ack()
        w:talk(DEAUSTIE):expectDelegate("processEvent030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110400)
    end)
end)

describe("Dance the Night Away (Wvr300)", function()
    it("offer: Deaustie asks for a hand with the ball's orders", function()
        local w = walkthrough.start("Wvr300", 65535)

        w:stateChange(65535):expectEnpc(DEAUSTIE, QFLAG_TALK)
        w:talk(DEAUSTIE):expectDelegate("processEventDeaustieStart"):answer(1)
    end)

    it("SEQ_000: the weavers' chatter, then Chuchumu's wish", function()
        local w = walkthrough.start("Wvr300", 0)

        w:stateChange(0):expectEnpc(CHUCHUMU, QFLAG_TALK)
        w:expectMarkers(11040101)
        w:talk(DEAUSTIE):expectDelegate("processEvent010_2"):ack()
        w:talk(CAHERNAUT):expectDelegate("processEvent010_6"):ack()
        w:talk(CHUCHUMU):expectDelegate("processEvent012"):ack():expectStartSequence(12)
    end)

    it("SEQ_012: Soileine points you to the Ebony Stalls", function()
        local w = walkthrough.start("Wvr300", 12)

        w:stateChange(12):expectEnpc(SOILEINE, QFLAG_TALK)
        w:talk(CHUCHUMU):expectDelegate("processEvent012_1"):ack()
        w:talk(DEAUSTIE):expectDelegate("processEvent012_2"):ack()
        w:talk(SOILEINE):expectDelegate("processEvent015"):ack():expectStartSequence(15)
    end)

    it("SEQ_015/018: Theldry and the midnight slippers", function()
        local w = walkthrough.start("Wvr300", 15)

        w:stateChange(15):expectEnpc(THELDRY, QFLAG_TALK)
        w:talk(DEAUSTIE):expectDelegate("processEvent015_2"):ack()
        w:talk(THELDRY):expectDelegate("processEvent018"):ack():expectStartSequence(18)
        w:stateChange(18):expectEnpc(THELDRY, QFLAG_TALK)
        w:talk(THELDRY):expectDelegate("processEvent019"):ack()
            :expectAddItem(MIDNIGHT_SLIPPERS, 1)
            :expectStartSequence(19)
    end)

    it("SEQ_019: the slippers to Chuchumu", function()
        local w = walkthrough.start("Wvr300", 19)

        w:stateChange(19):expectEnpc(CHUCHUMU, QFLAG_TALK)
        w:expectMarkers(11040102)
        w:give(MIDNIGHT_SLIPPERS)
        w:talk(CHUCHUMU):expectDelegate("processEvent020"):ack()
            :expectRemoveItem(MIDNIGHT_SLIPPERS, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: payment from Deaustie", function()
        local w = walkthrough.start("Wvr300", 20)

        w:stateChange(20):expectEnpc(DEAUSTIE, QFLAG_REWARD)
        w:talk(DEAUSTIE):expectDelegate("processEvent030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110401)
    end)
end)

describe("A Fruitful Murder (Wvr306)", function()
    it("offer: Deaustie wants ten pairs of gloves", function()
        local w = walkthrough.start("Wvr306", 65535)

        w:stateChange(65535):expectEnpc(DEAUSTIE, QFLAG_TALK)
        w:talk(DEAUSTIE):expectDelegate("processEventDeaustieStart"):answer(1)
    end)

    it("SEQ_000: Chuchumu on the spider silk", function()
        local w = walkthrough.start("Wvr306", 0)

        w:stateChange(0):expectEnpc(CHUCHUMU, QFLAG_TALK)
        w:talk(LOHWAEB):expectDelegate("processEvent005_3"):ack()
        w:talk(CHUCHUMU):expectDelegate("processEvent008"):ack():expectStartSequence(8)
    end)

    it("SEQ_008: Chuchumu caught in the webs at Copperbell", function()
        local w = walkthrough.start("Wvr306", 8)

        w:stateChange(8):expectEnpc(CHUCHUMU_MINES, QFLAG_TALK)
        w:talk(CHUCHUMU):expectDelegate("processEvent008_2"):ack()
        w:talk(CHUCHUMU_MINES):expectDelegate("processEventS002_1"):ack():expectStartSequence(9)
    end)

    it("SEQ_009: a strand of silk at a time", function()
        local w = walkthrough.start("Wvr306", 9)

        w:talk(CHUCHUMU_MINES):expectDelegate("processEventS001_1"):ack()
            :expectAddItem(SPIDER_SILK, 1)
        w:talk(CHUCHUMU_MINES):expectDelegate("processEventS003_1"):ack()
    end)

    it("SEQ_009: ten pairs made, Chuchumu heads home", function()
        local w = walkthrough.start("Wvr306", 9)

        w:give(GLOVES, 10)
        w:talk(CHUCHUMU_MINES):expectDelegate("processEventS004_1"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: not enough gloves yet", function()
        local w = walkthrough.start("Wvr306", 10)

        w:stateChange(10):expectEnpc(DEAUSTIE, QFLAG_TALK)
        w:expectMarkers(11040201)
        w:give(GLOVES, 9)
        w:talk(DEAUSTIE):expectDelegate("processEvent005_2"):ack():expectNoRemoveItem()
    end)

    it("SEQ_010: the gloves, and the prince", function()
        local w = walkthrough.start("Wvr306", 10)

        w:give(GLOVES, 10)
        w:talk(DEAUSTIE):expectDelegate("processEvent010"):ack()
            :expectRemoveItem(GLOVES, 10)
            :expectStartSequence(20)
    end)

    it("SEQ_020: the Gold Court", function()
        local w = walkthrough.start("Wvr306", 20)

        w:stateChange(20):expectEnpc(GOLD_COURT, QFLAG_PUSH)
        w:expectMarkers(11040202)
        w:talk(DEAUSTIE):expectDelegate("processEvent010_2"):ack()
        w:push(GOLD_COURT):expectDelegate("processEvent020"):ack():expectStartSequence(30)
    end)

    it("SEQ_030: the Sunsilk Troupe's secret, and payment", function()
        local w = walkthrough.start("Wvr306", 30)

        w:stateChange(30):expectEnpc(DEAUSTIE, QFLAG_REWARD)
        w:talk(LOHWAEB):expectDelegate("processEvent020_2"):ack()
        w:talk(DEAUSTIE):expectDelegate("processEvent030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110402)
    end)
end)
