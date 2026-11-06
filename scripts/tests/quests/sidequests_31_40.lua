-- Side quests, levels 31-40: To Deskunk A Beer (Etc2g4), Clasping to Hope
-- (Etc1u7) and Traumaturgy (Etc1u8).
--
-- Quest-hook legs only (the `walkthrough` bridge). The fights run on the
-- content substrate (SimpleContent<Name> and its SimpleQuestBattle
-- director, see scripts/lua/questbattle.lua); the legs after them are
-- seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/etc/).
local LEFWYNE       = 1001396
local KNIGHT        = 1000571
local GLADE_TRIGGER = 1090613
local TOTONO        = 1001143
local FLATS_TRIGGER = 1090611
local MESA_TRIGGER  = 1090612

describe("To Deskunk A Beer (Etc2g4)", function()
    it("offer: Lefwyne and Fafajon's brew", function()
        local w = walkthrough.start("Etc2g4", 65535)
        w:stateChange(65535):expectEnpc(LEFWYNE, QFLAG_TALK)
        w:talk(LEFWYNE):expectDelegate("processEventLefwyneStart"):answer(1)
    end)

    it("SEQ_000: the knight at Owl's Nest", function()
        local w = walkthrough.start("Etc2g4", 0)
        w:stateChange(0):expectEnpc(KNIGHT, QFLAG_TALK)
        w:expectMarkers(11066801)
        w:talk(LEFWYNE):expectDelegate("processEvent_000"):ack()
        w:talk(KNIGHT):expectDelegate("processEvent_010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Lefwyne wants sourleaf nectar", function()
        local w = walkthrough.start("Etc2g4", 10)
        w:stateChange(10):expectEnpc(LEFWYNE, QFLAG_TALK)
        w:expectMarkers(11066802)
        w:talk(KNIGHT):expectDelegate("processEvent_010_1"):ack()
        w:talk(LEFWYNE):expectDelegate("processEvent_020"):ack():expectStartSequence(15)
    end)

    it("SEQ_015: the glade east of Humblehearth starts the fight", function()
        local w = walkthrough.start("Etc2g4", 15)
        w:stateChange(15):expectEnpc(GLADE_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11066803)
        w:talk(LEFWYNE):expectDelegate("processEvent_020_1"):ack()
        w:push(GLADE_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_020: the nectar, and the reward", function()
        local w = walkthrough.start("Etc2g4", 20)
        w:stateChange(20):expectEnpc(LEFWYNE, QFLAG_REWARD)
        w:expectMarkers(11066802)
        w:talk(LEFWYNE):expectDelegate("processEvent_030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(14000)
            :expectCompleted(110668)
    end)
end)

describe("Clasping to Hope (Etc1u7)", function()
    it("offer: Prelate Totono and the captive novice", function()
        local w = walkthrough.start("Etc1u7", 65535)
        w:stateChange(65535):expectEnpc(TOTONO, QFLAG_TALK)
        w:talk(TOTONO):expectDelegate("processEventTotonoStart"):answer(1)
    end)

    it("SEQ_000: the flats near Halatali start the fight", function()
        local w = walkthrough.start("Etc1u7", 0)
        w:stateChange(0):expectEnpc(FLATS_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11068201)
        w:talk(TOTONO):expectDelegate("followEvent005"):ack()
        w:push(FLATS_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: Theda's clasp, and the reward", function()
        local w = walkthrough.start("Etc1u7", 10)
        w:stateChange(10):expectEnpc(TOTONO, QFLAG_REWARD)
        w:expectMarkers(11068202)
        w:talk(TOTONO):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(2500)
            :expectCompleted(110682)
    end)
end)

describe("Traumaturgy (Etc1u8)", function()
    it("offer: Theda's precious ring", function()
        local w = walkthrough.start("Etc1u8", 65535)
        w:stateChange(65535):expectEnpc(TOTONO, QFLAG_TALK)
        w:talk(TOTONO):expectDelegate("processEventTotonoStart"):answer(1)
    end)

    it("SEQ_000: below the mesa northeast of Halatali starts the fight", function()
        local w = walkthrough.start("Etc1u8", 0)
        w:stateChange(0):expectEnpc(MESA_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11068301)
        w:talk(TOTONO):expectDelegate("followEvent005"):ack()
        w:push(MESA_TRIGGER):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_010: the ring, and the reward", function()
        local w = walkthrough.start("Etc1u8", 10)
        w:stateChange(10):expectEnpc(TOTONO, QFLAG_REWARD)
        w:expectMarkers(11068302)
        w:talk(TOTONO):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(2500)
            :expectCompleted(110683)
    end)
end)
