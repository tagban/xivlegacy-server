-- Leatherworkers' Guild: Tan200, Tan300, Tan306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Class ids come from
-- scripts/lua/quests/tan/*.lua.

local HEREWARD     = 1000231
local ALIXE        = 1000066
local DADALO       = 1000067
local KAIN         = 1000068
local BELI         = 1001077
local MADDELINE    = 1001078
local DYRSTBROD    = 1001079
local LUILDA       = 1001082
local YUHELMERIC   = 1000370
local LALATTA      = 1000368
local LALATTA_GUILD = 1000467
local GYLBART      = 1000978
local STABLES      = 1091108
local ROAD         = 1091109
local CLEARWATER   = 1091110
local LIFEMEND     = 1091111
local GATHERING    = 1091112

local DAMAGED_ARMOR   = 11000044
local REPAIRED_ARMOR  = 11000045
local ARMOR_REMNANTS  = 11000046
local SADDLE          = 11000021
local BIRKIN_BAG      = 11000047
local DAMAGED_BOOTS   = 11000048
local VINTAGE_BOOTS   = 11000049

describe("The Silent Partners (Tan200)", function()
    it("offer: Hereward takes you on", function()
        local w = walkthrough.start("Tan200", 65535)

        w:stateChange(65535):expectEnpc(HEREWARD, QFLAG_TALK)
        w:talk(HEREWARD):expectDelegate("processEventHerewardStart"):answer(1)
    end)

    it("SEQ_000-010: Lalatta at the Ebony Stalls hands over the armor", function()
        local w = walkthrough.start("Tan200", 0)

        w:stateChange(0):expectEnpc(LALATTA, QFLAG_TALK)
        w:talk(BELI):expectDelegate("processEvent005_3"):ack()
        w:talk(LALATTA):expectDelegate("processEvent010"):ack():expectStartSequence(10)
        w:stateChange(10):expectEnpc(LALATTA, QFLAG_TALK)
        w:talk(LALATTA):expectDelegate("processEvent020"):ack()
            :expectAddItem(DAMAGED_ARMOR, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: not repaired yet", function()
        local w = walkthrough.start("Tan200", 20)
        w:give(DAMAGED_ARMOR, 1)

        w:talk(DYRSTBROD):expectDelegate("processEvent020_9"):ack()
        w:talk(LALATTA):expectDelegate("processEvent020_10"):ack():expectNoRemoveItem()
        w:expectSequence(20)
    end)

    it("SEQ_020: the repair handed over, Lalatta leaves the remnants", function()
        local w = walkthrough.start("Tan200", 20)
        w:give(DAMAGED_ARMOR, 1)
        w:give(REPAIRED_ARMOR, 1)

        w:talk(LALATTA)
            :expectRemoveItem(REPAIRED_ARMOR, 1)
            :expectRemoveItem(DAMAGED_ARMOR, 1)
            :expectDelegate("processEvent030"):ack()
            :expectAddItem(ARMOR_REMNANTS, 1)
            :expectStartSequence(30)
    end)

    it("SEQ_030-033: Hereward wants it made anew, and waits for it", function()
        local w = walkthrough.start("Tan200", 30)
        w:give(ARMOR_REMNANTS, 1)

        w:stateChange(30):expectEnpc(HEREWARD, QFLAG_TALK)
        w:talk(HEREWARD):expectDelegate("processEvent033"):ack():expectStartSequence(33)
        w:talk(HEREWARD):expectDelegate("processEvent033_2"):ack():expectNoRemoveItem()
        w:expectSequence(33)
    end)

    it("SEQ_033: the new armor", function()
        local w = walkthrough.start("Tan200", 33)
        w:give(ARMOR_REMNANTS, 1)
        w:give(REPAIRED_ARMOR, 1)

        w:talk(LALATTA):expectDelegate("processEvent033_12"):ack()
        w:talk(HEREWARD)
            :expectRemoveItem(ARMOR_REMNANTS, 1)
            :expectDelegate("processEvent033_3"):ack()
            :expectStartSequence(35)
    end)

    it("SEQ_035: the walk to the stables before Hereward passes it", function()
        local w = walkthrough.start("Tan200", 35)
        w:give(REPAIRED_ARMOR, 1)

        w:stateChange(35)
            :expectEnpc(HEREWARD, QFLAG_TALK)
            :expectEnpc(STABLES, QFLAG_PUSH)
        w:talk(HEREWARD):expectDelegate("processEvent033_4"):ack()
        w:expectSequence(35)
        w:push(STABLES)
        w:talk(HEREWARD):expectDelegate("processEvent037"):ack():expectStartSequence(37)
    end)

    it("SEQ_037: Gylbart takes the armor", function()
        local w = walkthrough.start("Tan200", 37)
        w:give(REPAIRED_ARMOR, 1)

        w:stateChange(37):expectEnpc(GYLBART, QFLAG_TALK)
        w:talk(LALATTA):expectDelegate("processEvent037_2"):ack()
        w:talk(GYLBART):expectDelegate("processEvent040"):ack()
            :expectRemoveItem(REPAIRED_ARMOR, 1)
            :expectStartSequence(40)
    end)

    it("SEQ_040: Hereward's payment", function()
        local w = walkthrough.start("Tan200", 40)

        w:stateChange(40):expectEnpc(HEREWARD, QFLAG_REWARD)
        w:talk(HEREWARD):expectDelegate("processEvent050"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110380)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11038001 },
            { 10, 11038002 },
            { 20, 11038003 },
            { 30, nil },
            { 33, nil },
            { 35, nil },
            { 37, 11038004 },
            { 40, 11038005 },
        }) do
            local w = walkthrough.start("Tan200", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)

describe("Design Imposters (Tan300)", function()
    it("offer: accepting hands you the saddle", function()
        local w = walkthrough.start("Tan300", 65535)

        w:stateChange(65535):expectEnpc(HEREWARD, QFLAG_TALK)
        w:talk(HEREWARD):expectDelegate("processEventHerewardStart"):answer(1)
            :expectAddItem(SADDLE, 1)
    end)

    it("SEQ_000-010: the bandit on the road, then Yuhelmeric", function()
        local w = walkthrough.start("Tan300", 0)
        w:give(SADDLE, 1)

        w:stateChange(0):expectEnpc(ROAD, QFLAG_PUSH)
        w:talk(KAIN):expectDelegate("processEvent005_8"):ack()
        w:push(ROAD):expectDelegate("processEvent010"):ack():expectStartSequence(10)
        w:stateChange(10):expectEnpc(YUHELMERIC, QFLAG_TALK)
        w:talk(YUHELMERIC):expectDelegate("processEvent020"):ack()
            :expectRemoveItem(SADDLE, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020-025: Lalatta's call, and no bag yet at the lake", function()
        local w = walkthrough.start("Tan300", 20)

        w:stateChange(20):expectEnpc(ROAD, QFLAG_PUSH)
        w:push(ROAD):expectDelegate("processEvent025"):ack():expectStartSequence(25)
        w:stateChange(25):expectEnpc(CLEARWATER, QFLAG_PUSH)
        w:talk(MADDELINE):expectDelegate("processEvent025_4"):ack()
        w:push(CLEARWATER):expectNoRemoveItem()
        w:expectSequence(25)
    end)

    it("SEQ_025-030: the bag brought to the lake, and the knights", function()
        local w = walkthrough.start("Tan300", 25)
        w:give(BIRKIN_BAG, 1)

        w:push(CLEARWATER)
            :expectDelegate("processEvent030"):ack()
            :expectNoRemoveItem()
            :expectStartSequence(30)
        w:push(CLEARWATER):expectDelegate("processEvent040"):ack()
            :expectRemoveItem(BIRKIN_BAG, 1)
            :expectStartSequence(40)
    end)

    it("SEQ_040: Hereward's payment", function()
        local w = walkthrough.start("Tan300", 40)

        w:stateChange(40):expectEnpc(HEREWARD, QFLAG_REWARD)
        w:talk(ALIXE):expectDelegate("processEvent040_6"):ack()
        w:talk(HEREWARD):expectDelegate("processEvent050"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110381)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11038101 },
            { 10, 11038102 },
            { 20, nil },
            { 25, 11038103 },
            { 30, 11038104 },
            { 40, 11038105 },
        }) do
            local w = walkthrough.start("Tan300", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)

describe("Head of the Class (Tan306)", function()
    it("offer: Hereward calls the pupils together", function()
        local w = walkthrough.start("Tan306", 65535)

        w:stateChange(65535):expectEnpc(HEREWARD, QFLAG_TALK)
        w:talk(HEREWARD):expectDelegate("processEventHerewardStart"):answer(1)
    end)

    it("SEQ_000-020: the evaluation, and the empty stump", function()
        local w = walkthrough.start("Tan306", 0)

        w:stateChange(0):expectEnpc(GATHERING, QFLAG_PUSH)
        w:talk(DADALO):expectDelegate("processEvent005_5"):ack()
        w:push(GATHERING):expectDelegate("processEvent010"):ack():expectStartSequence(10)
        w:stateChange(10):expectEnpc(LIFEMEND, QFLAG_PUSH)
        w:talk(LUILDA):expectDelegate("processEvent010_5"):ack()
        w:push(LIFEMEND):expectDelegate("processEvent020"):ack():expectStartSequence(20)
    end)

    it("SEQ_020: the pupil gives up the boots", function()
        local w = walkthrough.start("Tan306", 20)

        w:stateChange(20):expectEnpc(GATHERING, QFLAG_PUSH)
        w:push(GATHERING):expectDelegate("processEvent023"):ack()
            :expectDelegate("processEvent025"):ack()
            :expectAddItem(DAMAGED_BOOTS, 1)
            :expectStartSequence(27)
    end)

    it("SEQ_027: boots not mended yet", function()
        local w = walkthrough.start("Tan306", 27)
        w:give(DAMAGED_BOOTS, 1)

        w:stateChange(27):expectEnpc(MADDELINE, QFLAG_TALK)
        w:talk(BELI):expectDelegate("processEvent027_5"):ack()
        w:talk(MADDELINE):expectDelegate("processEvent027_4"):ack():expectNoRemoveItem()
        w:expectSequence(27)
    end)

    it("SEQ_027-030: the boots mended and shown to Hereward", function()
        local w = walkthrough.start("Tan306", 27)
        w:give(DAMAGED_BOOTS, 1)
        w:give(VINTAGE_BOOTS, 1)

        w:talk(MADDELINE):expectDelegate("processEvent027_10"):ack()
            :expectRemoveItem(DAMAGED_BOOTS, 1)
            :expectDelegate("processEvent028"):ack()
            :expectStartSequence(28)
        w:stateChange(28):expectEnpc(HEREWARD, QFLAG_TALK)
        w:talk(HEREWARD):expectDelegate("processEvent030"):ack()
            :expectRemoveItem(VINTAGE_BOOTS, 1)
            :expectStartSequence(30)
    end)

    it("SEQ_030: the Echo on Lalatta", function()
        local w = walkthrough.start("Tan306", 30)

        w:stateChange(30):expectEnpc(LALATTA_GUILD, QFLAG_TALK)
        w:talk(MADDELINE):expectDelegate("processEvent030_4"):ack()
        w:talk(LALATTA_GUILD):expectDelegate("processEvent040"):answer(0)
        w:expectSequence(30)
        w:talk(LALATTA_GUILD):expectDelegate("processEvent040"):answer(1):expectStartSequence(40)
    end)

    it("SEQ_040: Hereward's payment", function()
        local w = walkthrough.start("Tan306", 40)

        w:stateChange(40):expectEnpc(HEREWARD, QFLAG_REWARD)
        w:talk(KAIN):expectDelegate("processEvent040_8"):ack()
        w:talk(HEREWARD):expectDelegate("processEvent050"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110382)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11038201 },
            { 10, 11038202 },
            { 20, nil },
            { 27, nil },
            { 28, 11038203 },
            { 30, 11038204 },
            { 40, 11038205 },
        }) do
            local w = walkthrough.start("Tan306", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)
