-- Goldsmiths' Guild quests at Eshtaime's Lapidaries: Gld200, Gld300, Gld306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Each case seeds the
-- sequence it walks; crafted pieces are put in the bag with `give`.

-- Actor class ids (from scripts/lua/quests/gld/*.lua).
local ELECOTTE       = 1000950
local COLBERNOUX     = 1000949
local ZSSAPA         = 1000887
local FLHAMINN       = 1000038
local HAWAZI_ZOWAZI  = 1000638
local ISABELLA       = 1000639
local LEFCHILD       = 1000994
local BOUCHARD       = 1001055
local CRHABYE        = 1001476
local DIRIAINE       = 1001475
local MAMAZA         = 1000652

local SILVER_NUGGETS   = 11000121
local ADORABLE_SKETCH  = 11000110
local GRACEFUL_SKETCH  = 11000111
local DASHING_SKETCH   = 11000112
local IDEAL_SKETCH     = 11000113
local ZSSAPA_BROOCH    = 11000108

describe("She Walks in Beauty (Gld200)", function()
    it("offer: Elecotte signs you on", function()
        local w = walkthrough.start("Gld200", 65535)

        w:stateChange(65535):expectEnpc(ELECOTTE, QFLAG_TALK)
        w:talk(ELECOTTE):expectDelegate("processEventElecotteStart"):answer(1)
    end)

    it("SEQ_000: the goldsmiths' chatter, then Colbernoux's errand", function()
        local w = walkthrough.start("Gld200", 0)

        w:stateChange(0)
            :expectEnpc(COLBERNOUX, QFLAG_TALK)
            :expectEnpc(HAWAZI_ZOWAZI, 0)
        w:talk(ISABELLA):expectDelegate("processEvent007_3"):ack()
        w:talk(COLBERNOUX):expectDelegate("processEvent013"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Colbernoux's reminder, then Z'ssapa's nuggets", function()
        local w = walkthrough.start("Gld200", 10)

        w:stateChange(10):expectEnpc(ZSSAPA, QFLAG_TALK)
        w:talk(COLBERNOUX):expectDelegate("processEvent013_2"):ack()
        w:talk(ZSSAPA):expectDelegate("processEvent020"):ack()
            :expectAddItem(SILVER_NUGGETS, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: back to Colbernoux with the nuggets", function()
        local w = walkthrough.start("Gld200", 20)

        w:stateChange(20):expectEnpc(COLBERNOUX, QFLAG_TALK)
        w:talk(ZSSAPA):expectDelegate("processEvent020_2"):ack()
        w:talk(COLBERNOUX):expectDelegate("processEvent030"):ack():expectStartSequence(30)
    end)

    it("SEQ_030: the guild's advice and three sketches", function()
        local w = walkthrough.start("Gld200", 30)

        w:stateChange(30)
            :expectEnpc(CRHABYE, QFLAG_TALK)
            :expectEnpc(DIRIAINE, QFLAG_TALK)
            :expectEnpc(MAMAZA, QFLAG_TALK)
        w:talk(BOUCHARD):expectDelegate("processEvent030_8"):ack()
        w:talk(CRHABYE):expectDelegate("processEvent030_9"):ack()
            :expectFlagSet(0)
            :expectAddItem(ADORABLE_SKETCH, 1)
        w:talk(CRHABYE):expectDelegate("processEvent032_2"):ack()
        w:talk(DIRIAINE):expectDelegate("processEvent030_10"):ack()
            :expectFlagSet(1)
            :expectAddItem(GRACEFUL_SKETCH, 1)
        w:talk(MAMAZA):expectDelegate("processEvent030_11"):ack()
            :expectFlagSet(2)
            :expectAddItem(DASHING_SKETCH, 1)
            :expectRemoveItem(ADORABLE_SKETCH, 1)
            :expectAddItem(IDEAL_SKETCH, 1)
            :expectStartSequence(32)
    end)

    it("SEQ_032: no brooch yet", function()
        local w = walkthrough.start("Gld200", 32)

        w:stateChange(32):expectEnpc(COLBERNOUX, QFLAG_REWARD)
        w:talk(COLBERNOUX):expectDelegate("processEvent030_2"):ack():expectNoRemoveItem()
        w:talk(MAMAZA):expectDelegate("processEvent032_4"):ack()
    end)

    it("SEQ_032: the brooch, and F'lhaminn at the door", function()
        local w = walkthrough.start("Gld200", 32)

        w:give(ZSSAPA_BROOCH)
        w:talk(COLBERNOUX):expectDelegate("processEvent040"):ack()
            :expectRemoveItem(ZSSAPA_BROOCH, 1)
            :expectStartSequence(40)
    end)

    it("SEQ_040: the Echo on F'lhaminn, declined then taken", function()
        local w = walkthrough.start("Gld200", 40)

        w:stateChange(40):expectEnpc(FLHAMINN, QFLAG_TALK)
        w:talk(COLBERNOUX):expectDelegate("processEvent040_2"):ack()
        w:talk(FLHAMINN):expectDelegate("processEvent045"):answer(2)
        w:talk(FLHAMINN):expectDelegate("processEvent045"):answer(1)
            :expectDelegate("processEvent050"):ack()
            :expectStartSequence(50)
    end)

    it("SEQ_050: Elecotte pays", function()
        local w = walkthrough.start("Gld200", 50)

        w:stateChange(50):expectEnpc(ELECOTTE, QFLAG_REWARD)
        w:talk(COLBERNOUX):expectDelegate("processEvent050_2"):ack()
        w:talk(ELECOTTE):expectDelegate("processEvent060"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110360)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, nil },
            { 10, 11036001 },
            { 20, 11036002 },
            { 30, nil },
            { 32, 11036003 },
            { 40, 11036004 },
            { 50, nil },
        }) do
            local w = walkthrough.start("Gld200", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)

local OPYLTYL        = 1000236
local VKOROLON       = 1000458
local FIELD_CIRCLE   = 1091180

local VIOLET_AUGITE     = 11000114
local SHATTERED_BROOCH  = 11000122
local PEARL_CLOVER      = 11000123
local FLHAMINNS_FLOWER  = 11000124

describe("F'lhaminn's Flower (Gld300)", function()
    it("offer: Elecotte asks for ten blossoms", function()
        local w = walkthrough.start("Gld300", 65535)

        w:stateChange(65535):expectEnpc(ELECOTTE, QFLAG_TALK)
        w:talk(ELECOTTE):expectDelegate("processEventElecotteStart"):answer(1)
    end)

    it("SEQ_000: the guild's chatter, then the botanists refuse", function()
        local w = walkthrough.start("Gld300", 0)

        w:stateChange(0):expectEnpc(OPYLTYL, QFLAG_TALK)
        w:talk(ELECOTTE):expectDelegate("processEvent010_2"):ack()
        w:talk(HAWAZI_ZOWAZI):expectDelegate("processEvent010_3"):ack()
        w:talk(OPYLTYL):expectDelegate("processEvent020"):ack():expectStartSequence(20)
    end)

    it("SEQ_020: Colbernoux at the Roost", function()
        local w = walkthrough.start("Gld300", 20)

        w:stateChange(20):expectEnpc(VKOROLON, QFLAG_TALK)
        w:talk(OPYLTYL):expectDelegate("processEvent020_2"):ack()
        w:talk(VKOROLON):expectDelegate("processEvent030"):ack()
            :expectAddItem(SHATTERED_BROOCH, 1)
            :expectAddItem(VIOLET_AUGITE, 1)
            :expectStartSequence(30)
    end)

    it("SEQ_030: the spriggan and the moogle at the clearing", function()
        local w = walkthrough.start("Gld300", 30)

        w:stateChange(30):expectEnpc(FIELD_CIRCLE, QFLAG_PUSH)
        w:talk(OPYLTYL):expectDelegate("processEvent030_2"):ack()
        w:push(FIELD_CIRCLE):expectDelegate("processEvent040"):ack()
            :expectDelegate("processEvent050"):ack()
            :expectAddItem(PEARL_CLOVER, 1)
            :expectStartSequence(50)
    end)

    it("SEQ_050: the blossom for Colbernoux", function()
        local w = walkthrough.start("Gld300", 50)

        w:stateChange(50):expectEnpc(VKOROLON, QFLAG_TALK)
        w:talk(VKOROLON):expectDelegate("processEvent055"):ack()
            :expectDelegate("processEvent058"):ack()
            :expectRemoveItem(PEARL_CLOVER, 1)
            :expectStartSequence(60)
    end)

    it("SEQ_060: Elecotte, and Colbernoux speaks for you", function()
        local w = walkthrough.start("Gld300", 60)

        w:stateChange(60):expectEnpc(ELECOTTE, QFLAG_TALK)
        w:talk(LEFCHILD):expectDelegate("processEvent058_6"):ack()
        w:talk(ELECOTTE):expectDelegate("processEvent060"):ack():expectStartSequence(65)
    end)

    it("SEQ_065: the mended brooch for F'lhaminn", function()
        local w = walkthrough.start("Gld300", 65)

        w:stateChange(65):expectEnpc(COLBERNOUX, QFLAG_TALK)
        w:talk(ELECOTTE):expectDelegate("processEvent060_2"):ack()
        w:talk(COLBERNOUX):expectDelegate("processEvent067"):ack()
            :expectRemoveItem(SHATTERED_BROOCH, 1)
            :expectAddItem(FLHAMINNS_FLOWER, 1)
            :expectStartSequence(70)
    end)

    it("SEQ_070/075: F'lhaminn takes the brooch, then the Echo", function()
        local w = walkthrough.start("Gld300", 70)

        w:stateChange(70):expectEnpc(FLHAMINN, QFLAG_TALK)
        w:talk(COLBERNOUX):expectDelegate("processEvent067_2"):ack()
        w:talk(FLHAMINN):expectDelegate("processEvent075"):ack()
            :expectRemoveItem(FLHAMINNS_FLOWER, 1)
            :expectStartSequence(75)
        w:talk(FLHAMINN):expectDelegate("processEvent078"):answer(1)
            :expectDelegate("processEvent080"):ack()
            :expectStartSequence(80)
    end)

    it("SEQ_075: the Echo declined", function()
        local w = walkthrough.start("Gld300", 75)

        w:talk(FLHAMINN):expectDelegate("processEvent078"):answer(2)
    end)

    it("SEQ_080: Colbernoux pays", function()
        local w = walkthrough.start("Gld300", 80)

        w:stateChange(80):expectEnpc(COLBERNOUX, QFLAG_REWARD)
        w:talk(COLBERNOUX):expectDelegate("processEvent090"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110361)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, { 11036101 } },
            { 20, { 11036102 } },
            { 30, { 11036103, 11036104 } },
            { 50, {} },
            { 60, { 11036105 } },
            { 65, {} },
            { 75, { 11036106 } },
            { 80, {} },
        }) do
            local w = walkthrough.start("Gld300", row[1])
            w:stateChange(row[1])
            w:expectMarkers((table.unpack or unpack)(row[2]))
        end
    end)
end)

local SENCE          = 1001498
local CHAMBER_CIRCLE = 1091181

local PURE_METAL_ORE      = 11000117
local GLASS_SHARDS        = 11000118
local SILVERWATER         = 11000119
local HEARTSTRIKE_REPLICA = 11000116

describe("Struck Through the Heart (Gld306)", function()
    it("offer: Elecotte's scene asks for your help", function()
        local w = walkthrough.start("Gld306", 65535)

        w:stateChange(65535):expectEnpc(ELECOTTE, QFLAG_TALK)
        w:talk(ELECOTTE):expectDelegate("processEventElecotteStart"):answer(1)
    end)

    it("SEQ_000: Sence's leave", function()
        local w = walkthrough.start("Gld306", 0)

        w:stateChange(0):expectEnpc(SENCE, QFLAG_TALK)
        w:talk(ELECOTTE):expectDelegate("processEvent010_2"):ack()
        w:talk(SENCE):expectDelegate("processEvent011"):ack()
            :expectDelegate("processEvent012"):ack()
            :expectStartSequence(10)
    end)

    it("SEQ_010: Sence hands over the materials", function()
        local w = walkthrough.start("Gld306", 10)

        w:stateChange(10):expectEnpc(SENCE, QFLAG_TALK)
        w:talk(SENCE):expectDelegate("processEvent012_5"):ack()
            :expectAddItem(PURE_METAL_ORE, 1)
            :expectAddItem(GLASS_SHARDS, 1)
            :expectAddItem(SILVERWATER, 1)
            :expectStartSequence(15)
    end)

    it("SEQ_015: no replica yet", function()
        local w = walkthrough.start("Gld306", 15)

        w:stateChange(15):expectEnpc(ELECOTTE, QFLAG_REWARD)
        w:talk(SENCE):expectDelegate("processEvent013_2"):ack()
        w:talk(ELECOTTE):expectDelegate("processEvent010_2"):ack():expectNoRemoveItem()
    end)

    it("SEQ_015: the replica, and Colbernoux's return", function()
        local w = walkthrough.start("Gld306", 15)

        w:give(HEARTSTRIKE_REPLICA)
        w:talk(ELECOTTE):expectDelegate("processEvent015"):ack()
            :expectRemoveItem(HEARTSTRIKE_REPLICA, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: the burial chamber, Echo declined", function()
        local w = walkthrough.start("Gld306", 20)

        w:stateChange(20):expectEnpc(CHAMBER_CIRCLE, QFLAG_PUSH)
        w:talk(BOUCHARD):expectDelegate("processEvent015_2"):ack()
        w:push(CHAMBER_CIRCLE):expectDelegate("processEvent020"):ack()
            :expectStartSequence(25)
            :expectDelegate("processEvent025"):answer(2)
    end)

    it("SEQ_025: the Echo on Colbernoux", function()
        local w = walkthrough.start("Gld306", 25)

        w:stateChange(25):expectEnpc(CHAMBER_CIRCLE, QFLAG_PUSH)
        w:push(CHAMBER_CIRCLE):expectDelegate("processEvent025"):answer(1)
            :expectDelegate("processEvent030"):ack()
            :expectStartSequence(40)
    end)

    it("SEQ_040: Colbernoux pays", function()
        local w = walkthrough.start("Gld306", 40)

        w:stateChange(40):expectEnpc(COLBERNOUX, QFLAG_REWARD)
        w:talk(ISABELLA):expectDelegate("processEvent030_3"):ack()
        w:talk(COLBERNOUX):expectDelegate("processEvent040"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110362)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, nil },
            { 10, nil },
            { 15, 11036202 },
            { 20, 11036203 },
            { 25, 11036204 },
            { 40, nil },
        }) do
            local w = walkthrough.start("Gld306", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)
