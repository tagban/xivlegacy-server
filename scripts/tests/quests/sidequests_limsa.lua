-- Side quests around Limsa Lominsa, levels 15-20: Winds of Change (Etc3l1),
-- Moonstruck (Etc2l1) and Seashells by the Seashore (Etc1l9).
--
-- Quest-hook legs only (the `walkthrough` bridge). The fights run on the
-- content substrate (SimpleContent<Name> and its SimpleQuestBattle
-- director, see scripts/lua/questbattle.lua); the legs after them are
-- seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/etc/).
local ZANTHAEL     = 1000351
local BIBIRAKA     = 1001511
local ARTHURIOUX   = 1000133
local JGHONAKO     = 1000342
local SUNDHIMAL    = 1000349
local GERT         = 1500004
local KOPELYORPEL  = 1001577
local CAVE_TRIGGER = 1090603
local INAIROH      = 1001307
local ROAD_TRIGGER = 1090605
local FUPEPE       = 1001301
local SHELLS       = { 1080063, 1080064, 1080065, 1080066 }

describe("Winds of Change (Etc3l1)", function()
    it("offer: Zanthael's warrants", function()
        local w = walkthrough.start("Etc3l1", 65535)
        w:stateChange(65535):expectEnpc(ZANTHAEL, QFLAG_TALK)
        w:talk(ZANTHAEL):expectDelegate("processEventZanthaelStart"):answer(1)
    end)

    it("SEQ_000: five warrants for five knights", function()
        local w = walkthrough.start("Etc3l1", 0)
        w:onStart():expectStartSequence(0)
        w:stateChange(0):expectEnpc(BIBIRAKA, QFLAG_TALK)
        w:expectMarkers(11074401, 11074402, 11074403, 11074404, 11074405)
        w:talk(ZANTHAEL):expectDelegate("processEvent000"):ack()
        w:talk(BIBIRAKA):expectDelegate("processEventBibiraka"):ack():expectFlagSet(0)
        w:talk(BIBIRAKA):expectDelegate("processEventBibiraka01"):ack()
        w:talk(ARTHURIOUX):expectDelegate("processEventArthurioux"):ack():expectFlagSet(1)
        w:talk(JGHONAKO):expectDelegate("processEventJGhonako"):ack():expectFlagSet(2)
        w:talk(SUNDHIMAL):expectDelegate("processEventSundhimal"):ack():expectFlagSet(3)
        w:talk(GERT):expectDelegate("processEventGert"):ack():expectFlagSet(4)
            :expectStartSequence(1)
    end)

    it("SEQ_001: Zanthael sends you to the caves", function()
        local w = walkthrough.start("Etc3l1", 1)
        w:stateChange(1):expectEnpc(ZANTHAEL, QFLAG_TALK)
        w:talk(ZANTHAEL):expectDelegate("processEvent000_1"):ack():expectStartSequence(5)
    end)

    it("SEQ_005: the depression west of Camp Bearded Rock starts the fight", function()
        local w = walkthrough.start("Etc3l1", 5)
        w:stateChange(5):expectEnpc(CAVE_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11074407)
        w:talk(ZANTHAEL):expectDelegate("processEvent005"):ack()
        w:push(CAVE_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_007: Kopel Yorpel and his party", function()
        local w = walkthrough.start("Etc3l1", 7)
        w:stateChange(7):expectEnpc(KOPELYORPEL, QFLAG_TALK)
        w:talk(KOPELYORPEL):expectDelegate("processEventKopelyorpel"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Zanthael's reward", function()
        local w = walkthrough.start("Etc3l1", 10)
        w:stateChange(10):expectEnpc(ZANTHAEL, QFLAG_REWARD)
        w:talk(ZANTHAEL):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(7500)
            :expectExp(500)
            :expectCompleted(110744)
    end)
end)

describe("Moonstruck (Etc2l1)", function()
    it("offer: I'nairoh and Dalamud", function()
        local w = walkthrough.start("Etc2l1", 65535)
        w:stateChange(65535):expectEnpc(INAIROH, QFLAG_TALK)
        w:talk(INAIROH):expectDelegate("processEventI_NairohStart"):answer(1)
    end)

    it("SEQ_000: the road to Bloodshore starts the fight", function()
        local w = walkthrough.start("Etc2l1", 0)
        w:stateChange(0):expectEnpc(ROAD_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11064401)
        w:talk(INAIROH):expectDelegate("followEvent005"):ack()
        w:push(ROAD_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: what I'nairoh saw", function()
        local w = walkthrough.start("Etc2l1", 10)
        w:stateChange(10):expectEnpc(INAIROH, QFLAG_REWARD)
        w:talk(INAIROH):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(1280)
            :expectCompleted(110644)
    end)
end)

describe("Seashells by the Seashore (Etc1l9)", function()
    it("offer: Fupepe wants Bloodshore's shells", function()
        local w = walkthrough.start("Etc1l9", 65535)
        w:stateChange(65535):expectEnpc(FUPEPE, QFLAG_TALK)
        w:talk(FUPEPE):expectDelegate("processEventStart"):answer(1)
    end)

    it("SEQ_000: four shells on the beach", function()
        local w = walkthrough.start("Etc1l9", 0)
        w:stateChange(0):expectEnpc(SHELLS[1], QFLAG_TALK)
        w:expectMarkers(11064201)
        w:talk(FUPEPE):expectDelegate("processEventFree"):ack()
        w:talk(SHELLS[1]):expectFlagSet(0)
        w:talk(SHELLS[1]):expectDelegate("shell"):ack()
        w:talk(SHELLS[2]):expectFlagSet(1)
        w:talk(SHELLS[3]):expectFlagSet(2)
        w:talk(SHELLS[4]):expectFlagSet(3):expectStartSequence(10)
    end)

    it("SEQ_010: Fupepe's treasure", function()
        local w = walkthrough.start("Etc1l9", 10)
        w:stateChange(10):expectEnpc(FUPEPE, QFLAG_REWARD)
        w:expectMarkers(11064202)
        w:talk(FUPEPE):expectDelegate("processEventClear"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectCompleted(110642)
    end)
end)
