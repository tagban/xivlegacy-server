-- Side quests around Ul'dah, levels 10-20: Best Flower Ever (Etc1u9), The
-- Unheard Horizon (Etc2u0), No Other Dodo Will Do (Etc2u5) and Risky
-- Business (Etc101).
--
-- Quest-hook legs only (the `walkthrough` bridge). The fights run on the
-- content substrate (SimpleContent<Name> and its SimpleQuestBattle
-- director, see scripts/lua/questbattle.lua); the legs after them are
-- seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/etc/).
local SASAPANO        = 1001317
local VALLEY_TRIGGER  = 1090602
local GEGEISSA        = 1001424
local HORIZON_TRIGGER = 1090600
local HILDIE          = 1000787
local DODO_TRIGGER    = 1090601
local AISTAN          = 1001726
local MUTAMIX         = 1001727

describe("Best Flower Ever (Etc1u9)", function()
    it("offer: Sasapano's lost rose", function()
        local w = walkthrough.start("Etc1u9", 65535)
        w:stateChange(65535):expectEnpc(SASAPANO, QFLAG_TALK)
        w:talk(SASAPANO):expectDelegate("processEventSasapanoStart"):answer(1)
    end)

    it("SEQ_000: the valley starts the dodo fight", function()
        local w = walkthrough.start("Etc1u9", 0)
        w:stateChange(0):expectEnpc(VALLEY_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11068401)
        w:talk(SASAPANO):expectDelegate("processEvent000"):ack()
        w:push(VALLEY_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_005: the rose, and the reward", function()
        local w = walkthrough.start("Etc1u9", 5)
        w:stateChange(5):expectEnpc(SASAPANO, QFLAG_REWARD)
        w:talk(SASAPANO):expectDelegate("processEvent005"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(5000)
            :expectCompleted(110684)
    end)
end)

describe("The Unheard Horizon (Etc2u0)", function()
    it("offer: Gegeissa's carrier chocobos", function()
        local w = walkthrough.start("Etc2u0", 65535)
        w:stateChange(65535):expectEnpc(GEGEISSA, QFLAG_TALK)
        w:talk(GEGEISSA):expectDelegate("processEventStart"):answer(1)
    end)

    it("SEQ_000: Camp Horizon's outskirts start the fight", function()
        local w = walkthrough.start("Etc2u0", 0)
        w:stateChange(0):expectEnpc(HORIZON_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11068501)
        w:talk(GEGEISSA):expectDelegate("processEventFree"):ack()
        w:push(HORIZON_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: boasting to Gegeissa", function()
        local w = walkthrough.start("Etc2u0", 10)
        w:stateChange(10):expectEnpc(GEGEISSA, QFLAG_REWARD)
        w:talk(GEGEISSA):expectDelegate("processEventClear"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(1280)
            :expectCompleted(110685)
    end)
end)

describe("No Other Dodo Will Do (Etc2u5)", function()
    it("offer: Hildie's new bow", function()
        local w = walkthrough.start("Etc2u5", 65535)
        w:stateChange(65535):expectEnpc(HILDIE, QFLAG_TALK)
        w:talk(HILDIE):expectDelegate("processEventHildieStart"):answer(1)
    end)

    it("SEQ_000: north of Camp Drybone starts the fight", function()
        local w = walkthrough.start("Etc2u5", 0)
        w:stateChange(0):expectEnpc(DODO_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11069001)
        w:talk(HILDIE):expectDelegate("processEvent_000"):ack()
        w:push(DODO_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: the leather for Hildie", function()
        local w = walkthrough.start("Etc2u5", 10)
        w:stateChange(10):expectEnpc(HILDIE, QFLAG_REWARD)
        w:talk(HILDIE):expectDelegate("processEvent_010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectCompleted(110690)
    end)
end)

describe("Risky Business (Etc101)", function()
    it("offer: Aistan's delivery", function()
        local w = walkthrough.start("Etc101", 65535)
        w:stateChange(65535):expectEnpc(AISTAN, QFLAG_TALK)
        w:talk(AISTAN):expectDelegate("processEventAistanStart"):answer(1)
    end)

    it("SEQ_000: Mutamix takes the dark matter", function()
        local w = walkthrough.start("Etc101", 0)
        w:stateChange(0):expectEnpc(MUTAMIX, QFLAG_REWARD)
        w:expectMarkers(11081101)
        w:talk(AISTAN):expectDelegate("processEvent_000"):ack()
        w:talk(MUTAMIX):expectDelegate("processEvent_005"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(1000)
            :expectCompleted(110811)
    end)
end)
