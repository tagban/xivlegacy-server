-- Side quests, levels 21-30: There Might Be Blood (Etc3u2), Disorganized
-- Crime (Etc3g2), Shot Through the Heart (Etc3l2), Hunting the Hunters
-- (Etc2g3) and Losing One's Thread (Etc2g5).
--
-- Quest-hook legs only (the `walkthrough` bridge). The fights run on the
-- content substrate (SimpleContent<Name> and its SimpleQuestBattle
-- director, see scripts/lua/questbattle.lua); the legs after them are
-- seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/etc/).
local GUNNULF          = 1001256
local RYCHARDE         = 1001718
local PATH_TRIGGER     = 1090608
local BIDDY            = 1000737
local COLBERT          = 1001692
local BRYCE            = 1001690
local CKEPAGA          = 1001691
local RAYA_O_SENNA     = 1001570
local STUMP_TRIGGER    = 1090609
local MYNADAEG         = 1000130
local MALIN            = 1001634
local BEACH_TRIGGER    = 1090610
local ODHINEK          = 1000829
local CLEARING_TRIGGER = 1090606
local HONGA_VUNGA      = 1000429
local HOLLOW_TRIGGER   = 1090607

describe("There Might Be Blood (Etc3u2)", function()
    it("offer: Gunnulf and the game at the Platinum Mirage", function()
        local w = walkthrough.start("Etc3u2", 65535)
        w:stateChange(65535):expectEnpc(GUNNULF, QFLAG_TALK)
        w:talk(GUNNULF):expectDelegate("processEventStart"):answer(1)
    end)

    it("SEQ_000: the path into Little Ala Mhigo starts the fight", function()
        local w = walkthrough.start("Etc3u2", 0)
        w:stateChange(0):expectEnpc(PATH_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11072701)
        w:talk(GUNNULF):expectDelegate("processEventStartAfter"):ack()
        w:push(PATH_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_005: Rycharde, and the Echo", function()
        local w = walkthrough.start("Etc3u2", 5)
        w:stateChange(5):expectEnpc(RYCHARDE, QFLAG_TALK)
        w:expectMarkers(11072702)
        w:talk(RYCHARDE):expectDelegate("processEventRycharde"):answer(2)
        w:talk(RYCHARDE):expectDelegate("processEventRycharde"):answer(1)
            :expectDelegate("processEventNqetc3u2"):ack()
            :expectStartSequence(10)
    end)

    it("SEQ_010: Gunnulf's reward", function()
        local w = walkthrough.start("Etc3u2", 10)
        w:stateChange(10):expectEnpc(GUNNULF, QFLAG_REWARD)
        w:expectMarkers(11072703)
        w:talk(RYCHARDE):expectDelegate("processEventRychardeFree"):ack()
        w:talk(GUNNULF):expectDelegate("processEventClear"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(10000)
            :expectCompleted(110727)
    end)
end)

describe("Disorganized Crime (Etc3g2)", function()
    it("offer: Biddy and the thefts at Lifemend Stump", function()
        local w = walkthrough.start("Etc3g2", 65535)
        w:stateChange(65535):expectEnpc(BIDDY, QFLAG_TALK)
        w:talk(BIDDY):expectDelegate("processEventBiddyStart"):answer(1)
    end)

    it("SEQ_000: the stump starts the fight", function()
        local w = walkthrough.start("Etc3g2", 0)
        w:stateChange(0):expectEnpc(STUMP_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11073601)
        w:talk(BIDDY):expectDelegate("processEvent_000_01"):ack()
        w:push(STUMP_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_005: the Redbelly Wasps parley", function()
        local w = walkthrough.start("Etc3g2", 5)
        w:stateChange(5):expectEnpc(COLBERT, QFLAG_TALK)
        w:expectMarkers(11073602)
        w:talk(BRYCE):expectDelegate("processEvent_010_01"):ack()
        w:talk(CKEPAGA):expectDelegate("processEvent_010_02"):ack()
        w:talk(COLBERT):expectDelegate("processEvent_010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Raya-O-Senna at the den, and the Echo", function()
        local w = walkthrough.start("Etc3g2", 10)
        w:stateChange(10):expectEnpc(RAYA_O_SENNA, QFLAG_TALK)
        w:expectMarkers(11073603)
        w:talk(RAYA_O_SENNA):expectDelegate("processEvent_015"):answer(2):expectFlagSet(0)
        w:talk(RAYA_O_SENNA):expectDelegate("processEvent_015_2"):answer(1)
            :expectDelegate("processEvent_020"):ack()
            :expectStartSequence(15)
    end)

    it("SEQ_015: Biddy's reward", function()
        local w = walkthrough.start("Etc3g2", 15)
        w:stateChange(15):expectEnpc(BIDDY, QFLAG_REWARD)
        w:expectMarkers(11073604)
        w:talk(COLBERT):expectDelegate("processEvent_010_3"):ack()
        w:talk(BIDDY):expectDelegate("processEvent_030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(10000)
            :expectCompleted(110736)
    end)
end)

describe("Shot Through the Heart (Etc3l2)", function()
    it("offer: Mynadaeg and the Braveheart", function()
        local w = walkthrough.start("Etc3l2", 65535)
        w:stateChange(65535):expectEnpc(MYNADAEG, QFLAG_TALK)
        w:talk(MYNADAEG):expectDelegate("processEventMynadaegStart"):answer(1)
    end)

    it("SEQ_000: the beach starts the fight", function()
        local w = walkthrough.start("Etc3l2", 0)
        w:stateChange(0):expectEnpc(BEACH_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11074501)
        w:talk(MYNADAEG):expectDelegate("processEvent000"):ack()
        w:push(BEACH_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_005/SEQ_007: Malin's holster, then her confession and the Echo", function()
        local w = walkthrough.start("Etc3l2", 5)
        w:stateChange(5):expectEnpc(MALIN, QFLAG_TALK)
        w:expectMarkers(11074502)
        w:talk(MALIN):expectDelegate("processEvent010"):ack():expectStartSequence(7)
        local w2 = walkthrough.start("Etc3l2", 7)
        w2:stateChange(7):expectEnpc(MALIN, QFLAG_TALK)
        w2:talk(MALIN):expectDelegate("processEvent010_2"):answer(2)
        w2:talk(MALIN):expectDelegate("processEvent010_2"):answer(1)
            :expectDelegate("processEvent010_3"):ack()
            :expectStartSequence(10)
    end)

    it("SEQ_010: Mynadaeg's reward", function()
        local w = walkthrough.start("Etc3l2", 10)
        w:stateChange(10):expectEnpc(MYNADAEG, QFLAG_REWARD)
        w:expectMarkers(11074503)
        w:talk(MYNADAEG):expectDelegate("processEvent015"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(10000)
            :expectCompleted(110745)
    end)
end)

describe("Hunting the Hunters (Etc2g3)", function()
    it("offer: O'dhinek's Ixal", function()
        local w = walkthrough.start("Etc2g3", 65535)
        w:stateChange(65535):expectEnpc(ODHINEK, QFLAG_TALK)
        w:talk(ODHINEK):expectDelegate("processEventODhinekStart"):answer(1)
    end)

    it("SEQ_000: the clearing near Quarrymill starts the fight", function()
        local w = walkthrough.start("Etc2g3", 0)
        w:stateChange(0):expectEnpc(CLEARING_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11066701)
        w:talk(ODHINEK):expectDelegate("processEvent000"):ack()
        w:push(CLEARING_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: O'dhinek's reward", function()
        local w = walkthrough.start("Etc2g3", 10)
        w:stateChange(10):expectEnpc(ODHINEK, QFLAG_REWARD)
        w:expectMarkers(11066702)
        w:talk(ODHINEK):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(1751)
            :expectCompleted(110667)
    end)
end)

describe("Losing One's Thread (Etc2g5)", function()
    it("offer: Honga Vunga's needle box", function()
        local w = walkthrough.start("Etc2g5", 65535)
        w:stateChange(65535):expectEnpc(HONGA_VUNGA, QFLAG_TALK)
        w:talk(HONGA_VUNGA):expectDelegate("processEventHONGAVUNGAStart"):answer(1)
    end)

    it("SEQ_000: the hollow east of Camp Tranquil starts the fight", function()
        local w = walkthrough.start("Etc2g5", 0)
        w:stateChange(0):expectEnpc(HOLLOW_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11066901)
        w:talk(HONGA_VUNGA):expectDelegate("processEvent000"):ack()
        w:push(HOLLOW_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: the needle box comes home", function()
        local w = walkthrough.start("Etc2g5", 10)
        w:stateChange(10):expectEnpc(HONGA_VUNGA, QFLAG_REWARD)
        w:expectMarkers(11066902)
        w:talk(HONGA_VUNGA):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(1500)
            :expectCompleted(110669)
    end)
end)
