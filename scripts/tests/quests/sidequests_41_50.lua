-- Side quests, levels 41-50: Carving a Name (Etc2l5) and A Light in the
-- Dark (Etc200).
--
-- Quest-hook legs only (the `walkthrough` bridge). The kobold kill that
-- hands over the strongbox key (onKillBNpc) and the way in and out of
-- Cutter's Cry (dungeon.lua) need the live server; the legs after them are
-- seeded at their sequences.

-- Actor class ids (from scripts/lua/quests/etc/).
local SIZHA             = 1001805
local STRONGBOX_TRIGGER = 1090614
local SIBOLD            = 1001932
local ENTRY_TRIGGER     = 1090615
local TOMB_TRIGGER      = 1090616

describe("Carving a Name (Etc2l5)", function()
    it("offer: Sizha Epocan's commission", function()
        local w = walkthrough.start("Etc2l5", 65535)
        w:stateChange(65535):expectEnpc(SIZHA, QFLAG_TALK)
        w:talk(SIZHA):expectDelegate("processEventStart"):answer(1)
    end)

    it("SEQ_000: the kobolds have the key", function()
        local w = walkthrough.start("Etc2l5", 0)
        w:stateChange(0):expectEnpc(SIZHA, QFLAG_NONE)
        w:expectMarkers(11064801)
        w:talk(SIZHA):expectDelegate("processEventStartAfter"):ack()
    end)

    it("SEQ_005: the strongbox opens with the key", function()
        local w = walkthrough.start("Etc2l5", 5)
        w:stateChange(5):expectEnpc(STRONGBOX_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11064802)
        w:talk(SIZHA):expectDelegate("processEventStartAfter"):ack()
        w:push(STRONGBOX_TRIGGER):expectStartSequence(10)
    end)

    it("SEQ_010: the marble, and the reward", function()
        local w = walkthrough.start("Etc2l5", 10)
        w:stateChange(10):expectEnpc(SIZHA, QFLAG_REWARD)
        w:expectMarkers(11064803)
        w:talk(SIZHA):expectDelegate("processEventClear"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(3500)
            :expectCompleted(110648)
    end)
end)

describe("A Light in the Dark (Etc200)", function()
    it("offer: Sibold the Stoic's bouquet", function()
        local w = walkthrough.start("Etc200", 65535)
        w:stateChange(65535):expectEnpc(SIBOLD, QFLAG_TALK)
        w:talk(SIBOLD):expectDelegate("processEventSIBOLDStart"):answer(1)
    end)

    it("SEQ_000: Cutter's Cry and the resting place", function()
        local w = walkthrough.start("Etc200", 0)
        w:stateChange(0):expectEnpc(ENTRY_TRIGGER, QFLAG_PUSH)
            :expectEnpc(TOMB_TRIGGER, QFLAG_PUSH)
        w:expectMarkers(11081801)
        w:talk(SIBOLD):expectDelegate("processEvent000"):ack()
    end)

    it("SEQ_005: Sibold's story, and the reward", function()
        local w = walkthrough.start("Etc200", 5)
        w:stateChange(5):expectEnpc(SIBOLD, QFLAG_REWARD)
        w:expectMarkers(11081802)
        w:talk(SIBOLD):expectDelegate("processEvent010"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectExp(3500)
            :expectCompleted(110818)
    end)
end)
