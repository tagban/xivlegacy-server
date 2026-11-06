-- Side quests around Gridania, levels 10-20: Proceed with Caution (Etc1g0),
-- Playing with Fire (Etc1g1) and Scrubbing the Soul (Etc3g1).
--
-- Quest-hook legs only (the `walkthrough` bridge). The fights run on the
-- content substrate (SimpleContent<Name> and its SimpleQuestBattle
-- director, see scripts/lua/questbattle.lua); the legs after them are
-- seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/etc/).
local MESTONNAUX   = 1001103
local BIDDY        = 1000737
local TATAGOI      = 1001080
local ALAIRE       = 1000831
local NUALA        = 1000681
local NELLAURE     = 1000821
local BARDO        = 1001580
local YAYATU       = 1001581
local TREE_TRIGGER = 1090604
local SANDRE       = 1001102
local WATCHERS     = { 1080067, 1080068, 1080069 }
local MAROILE      = 1000512
local HEARTHS      = { 1080070, 1080071, 1080072 }

describe("Scrubbing the Soul (Etc3g1)", function()
    it("offer: Mestonnaux and the rite of cleansing", function()
        local w = walkthrough.start("Etc3g1", 65535)
        w:stateChange(65535):expectEnpc(MESTONNAUX, QFLAG_TALK)
        w:talk(MESTONNAUX):expectDelegate("processEventMestonnauxStart"):answer(1)
    end)

    it("SEQ_000: word of the rite for five guilds", function()
        local w = walkthrough.start("Etc3g1", 0)
        w:stateChange(0):expectEnpc(BIDDY, QFLAG_TALK)
        w:expectMarkers(11073501, 11073502, 11073503, 11073504, 11073505)
        w:talk(MESTONNAUX):expectDelegate("processEvent000_2"):ack()
        w:talk(BIDDY):expectDelegate("processEventBiddy"):ack():expectFlagSet(0)
        w:talk(BIDDY):expectDelegate("processEventBiddy_2"):ack()
        w:talk(TATAGOI):expectDelegate("processEventTatagoi"):ack():expectFlagSet(1)
        w:talk(ALAIRE):expectDelegate("processEventAraire"):ack():expectFlagSet(2)
        w:talk(NUALA):expectDelegate("processEventNuala"):ack():expectFlagSet(3)
        w:talk(NELLAURE):expectDelegate("processEventNellaure"):ack():expectFlagSet(4)
            :expectStartSequence(5)
    end)

    it("SEQ_005: Nuala's message sends you to the tree", function()
        local w = walkthrough.start("Etc3g1", 5)
        w:stateChange(5):expectEnpc(MESTONNAUX, QFLAG_TALK)
        w:expectMarkers(11073506)
        w:talk(MESTONNAUX):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: the glade south of Camp Bentbranch starts the fight", function()
        local w = walkthrough.start("Etc3g1", 10)
        w:stateChange(10):expectEnpc(TREE_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11073507)
        w:talk(MESTONNAUX):expectDelegate("processEvent010_2"):ack()
        w:push(TREE_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_015: Bardo and Yayatu", function()
        local w = walkthrough.start("Etc3g1", 15)
        w:stateChange(15):expectEnpc(BARDO, QFLAG_TALK)
        w:talk(YAYATU):expectDelegate("processEventYayatu"):ack()
        w:talk(BARDO):expectDelegate("processEvent015"):ack():expectStartSequence(20)
    end)

    it("SEQ_020: Mestonnaux's reward", function()
        local w = walkthrough.start("Etc3g1", 20)
        w:stateChange(20):expectEnpc(MESTONNAUX, QFLAG_REWARD)
        w:talk(MESTONNAUX):expectDelegate("processEvent020"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(7500)
            :expectExp(500)
            :expectCompleted(110735)
    end)
end)

describe("Proceed with Caution (Etc1g0)", function()
    it("offer: Sandre's ceruleum", function()
        local w = walkthrough.start("Etc1g0", 65535)
        w:stateChange(65535):expectEnpc(SANDRE, QFLAG_TALK)
        w:talk(SANDRE):expectDelegate("processEventSandreStart"):answer(1)
    end)

    it("SEQ_000: three Watchers fueled", function()
        local w = walkthrough.start("Etc1g0", 0)
        w:onStart():expectStartSequence(0)
        w:stateChange(0):expectEnpc(WATCHERS[1], QFLAG_TALK)
        w:expectMarkers(11065401, 11065402, 11065403)
        w:talk(SANDRE):expectDelegate("processEvent000"):ack()
        w:talk(WATCHERS[1]):expectFlagSet(0)
        w:talk(WATCHERS[2]):expectFlagSet(1)
        w:talk(WATCHERS[3]):expectFlagSet(2):expectStartSequence(10)
    end)

    it("SEQ_010: Sandre's shoes", function()
        local w = walkthrough.start("Etc1g0", 10)
        w:stateChange(10):expectEnpc(SANDRE, QFLAG_REWARD)
        w:expectMarkers(11065404)
        w:talk(SANDRE):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(300)
            :expectCompleted(110654)
    end)
end)

describe("Playing with Fire (Etc1g1)", function()
    it("offer: Maroile's heated gallipot", function()
        local w = walkthrough.start("Etc1g1", 65535)
        w:stateChange(65535):expectEnpc(MAROILE, QFLAG_TALK)
        w:talk(MAROILE):expectDelegate("processEventMaroileStart"):answer(1)
    end)

    it("SEQ_000: three hearths lit", function()
        local w = walkthrough.start("Etc1g1", 0)
        w:stateChange(0):expectEnpc(HEARTHS[1], QFLAG_TALK)
        w:expectMarkers(11065501, 11065502, 11065503)
        w:talk(MAROILE):expectDelegate("processEvent000"):ack()
        w:talk(HEARTHS[2]):expectFlagSet(1)
        w:expectMarkers(11065501, 11065503)
        w:talk(HEARTHS[1]):expectFlagSet(0)
        w:talk(HEARTHS[3]):expectFlagSet(2):expectStartSequence(10)
    end)

    it("SEQ_010: Maroile frees the elemental", function()
        local w = walkthrough.start("Etc1g1", 10)
        w:stateChange(10):expectEnpc(MAROILE, QFLAG_REWARD)
        w:talk(MAROILE):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(500)
            :expectCompleted(110655)
    end)
end)
