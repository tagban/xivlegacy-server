-- Miners' Guild quests at Amajina & Sons Mineral Concern: Min200, Min300, Min306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Each case seeds the
-- sequence it walks; gathered finds are put in the bag with `give`.

-- Actor class ids (from scripts/lua/quests/min/*.lua).
local LINETTE           = 1000861
local ZSSAPA            = 1000887
local NENEKKO           = 1000888
local VKOROLON          = 1000458
local COACHMAN          = 1000703
local POPOKKULI         = 1000040
local SESERUKKA         = 1000041
local MOMODI            = 1000841
local MOHTFRYD          = 1001170
local PIERRIQUET        = 1001169
local CHACHAI           = 1001167
local QHOTA_NBOLO       = 1001171
local FIELD_CIRCLE      = 1091182
local LAPIDARIES_CIRCLE = 1091183
local MIRAGE_CIRCLE     = 1091184
local DOCKS_CIRCLE      = 1091185

local SHEEPS_EYE     = 11000012
local PETRIFIED_WOOD = 11000013
local EWER_FRAGMENT  = 11000014

describe("A Piece of History (Min200)", function()
    it("offer: Linette signs you on", function()
        local w = walkthrough.start("Min200", 65535)

        w:stateChange(65535):expectEnpc(LINETTE, QFLAG_TALK)
        w:talk(LINETTE):expectDelegate("processEventLinetteStart"):answer(1)
    end)

    it("SEQ_000: the miners' chatter, then the twins' test", function()
        local w = walkthrough.start("Min200", 0)

        w:stateChange(0)
            :expectEnpc(ZSSAPA, QFLAG_TALK)
            :expectEnpc(LINETTE, 0)
        w:talk(LINETTE):expectDelegate("processEvent000_8"):ack()
        w:talk(PIERRIQUET):expectDelegate("processEvent000_3"):ack()
        w:talk(ZSSAPA):expectDelegate("processEvent010"):ack():expectStartSequence(15)
    end)

    it("SEQ_015: nothing to show Z'ssapa yet", function()
        local w = walkthrough.start("Min200", 15)

        w:stateChange(15):expectEnpc(ZSSAPA, QFLAG_TALK)
        w:talk(ZSSAPA):expectDelegate("processEvent015_1"):ack():expectNoRemoveItem()
    end)

    it("SEQ_015: three finds appraised, and Nenekko knows the shard", function()
        local w = walkthrough.start("Min200", 15)

        w:give(EWER_FRAGMENT)
        w:talk(ZSSAPA):expectDelegate("processEvent017_C"):ack()
            :expectFlagSet(2)
            :expectNoRemoveItem()
        w:talk(ZSSAPA):expectDelegate("processEvent015_1"):ack()
        w:give(SHEEPS_EYE)
        w:talk(ZSSAPA):expectDelegate("processEvent017_B"):ack()
            :expectFlagSet(1)
            :expectRemoveItem(SHEEPS_EYE, 1)
        w:give(PETRIFIED_WOOD)
        w:talk(ZSSAPA):expectDelegate("processEvent017_A"):ack()
            :expectFlagSet(0)
            :expectRemoveItem(PETRIFIED_WOOD, 1)
            :expectDelegate("processEvent020"):ack()
            :expectStartSequence(20)
    end)

    it("SEQ_020: Nenekko and her brothers", function()
        local w = walkthrough.start("Min200", 20)

        w:stateChange(20):expectEnpc(NENEKKO, QFLAG_TALK)
        w:talk(NENEKKO):expectDelegate("processEvent030"):ack():expectStartSequence(35)
    end)

    it("SEQ_035: see Nenekko home", function()
        local w = walkthrough.start("Min200", 35)

        w:stateChange(35):expectEnpc(NENEKKO, QFLAG_TALK)
        w:talk(ZSSAPA):expectDelegate("processEvent035_3"):ack()
        w:give(EWER_FRAGMENT)
        w:talk(NENEKKO):expectDelegate("processEvent040"):ack()
            :expectRemoveItem(EWER_FRAGMENT, 1)
            :expectStartSequence(40)
    end)

    it("SEQ_040: Linette pays", function()
        local w = walkthrough.start("Min200", 40)

        w:stateChange(40):expectEnpc(LINETTE, QFLAG_REWARD)
        w:talk(CHACHAI):expectDelegate("processEvent040_5"):ack()
        w:talk(LINETTE):expectDelegate("processEvent050"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110460)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11046001 },
            { 15, 11046002 },
            { 20, 11046003 },
            { 35, 11046004 },
            { 40, nil },
        }) do
            local w = walkthrough.start("Min200", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)

describe("Little Saboteurs (Min300)", function()
    it("offer: Linette sends you after the twins", function()
        local w = walkthrough.start("Min300", 65535)

        w:stateChange(65535):expectEnpc(LINETTE, QFLAG_TALK)
        w:talk(LINETTE):expectDelegate("processEventLinetteStart"):answer(1)
    end)

    it("SEQ_000: the twins at the Roost", function()
        local w = walkthrough.start("Min300", 0)

        w:stateChange(0):expectEnpc(VKOROLON, QFLAG_TALK)
        w:talk(LINETTE):expectDelegate("processEvent005_2"):ack()
        w:talk(VKOROLON):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: the coachman lets it slip", function()
        local w = walkthrough.start("Min300", 10)

        w:stateChange(10):expectEnpc(COACHMAN, QFLAG_TALK)
        w:talk(VKOROLON):expectDelegate("processEvent010_8"):ack()
        w:talk(COACHMAN):expectDelegate("processEvent013"):ack():expectStartSequence(17)
    end)

    it("SEQ_017: Fafajon's box at the flower fields", function()
        local w = walkthrough.start("Min300", 17)

        w:stateChange(17):expectEnpc(FIELD_CIRCLE, QFLAG_PUSH)
        w:talk(VKOROLON):expectDelegate("processEvent013_2"):ack()
        w:push(FIELD_CIRCLE):expectDelegate("processEvent020"):ack():expectStartSequence(25)
    end)

    it("SEQ_025: Linette on Nenekko's errand", function()
        local w = walkthrough.start("Min300", 25)

        w:stateChange(25):expectEnpc(LINETTE, QFLAG_TALK)
        w:talk(MOHTFRYD):expectDelegate("processEvent020_2"):ack()
        w:talk(LINETTE):expectDelegate("processEvent025"):ack():expectStartSequence(30)
    end)

    it("SEQ_030: Nenekko at the Lapidaries", function()
        local w = walkthrough.start("Min300", 30)

        w:stateChange(30):expectEnpc(LAPIDARIES_CIRCLE, QFLAG_PUSH)
        w:talk(LINETTE):expectDelegate("processEvent025_2"):ack()
        w:push(LAPIDARIES_CIRCLE):expectDelegate("processEvent030"):ack()
            :expectDelegate("processEvent040"):ack()
            :expectStartSequence(45)
    end)

    it("SEQ_045: the lady mother at the Concern", function()
        local w = walkthrough.start("Min300", 45)

        w:stateChange(45):expectEnpc(LINETTE, QFLAG_TALK)
        w:talk(QHOTA_NBOLO):expectDelegate("processEvent040_7"):ack()
        w:talk(LINETTE):expectDelegate("processEvent050"):ack():expectStartSequence(50)
    end)

    it("SEQ_050: the Echo on both twins, then payment", function()
        local w = walkthrough.start("Min300", 50)

        w:stateChange(50)
            :expectEnpc(POPOKKULI, QFLAG_TALK)
            :expectEnpc(SESERUKKA, QFLAG_TALK)
        w:talk(SESERUKKA):expectDelegate("processEvent070"):answer(2)
        w:talk(POPOKKULI):expectDelegate("processEvent060"):answer(1):expectFlagSet(0)
        w:talk(POPOKKULI):expectDelegate("processEvent050_2"):ack()
        w:talk(LINETTE):expectDelegate("processEvent050_4"):ack()
        w:talk(SESERUKKA):expectDelegate("processEvent070"):answer(1)
            :expectFlagSet(1)
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110461)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, { 11046101 } },
            { 10, {} },
            { 17, { 11046102 } },
            { 25, {} },
            { 30, { 11046103, 11046104 } },
            { 45, { 11046105 } },
            { 50, { 11046106, 11046107 } },
        }) do
            local w = walkthrough.start("Min300", row[1])
            w:stateChange(row[1])
            w:expectMarkers((table.unpack or unpack)(row[2]))
        end
    end)
end)

describe("Runaway Little Girl (Min306)", function()
    it("offer: Linette asks for help finding Nenekko", function()
        local w = walkthrough.start("Min306", 65535)

        w:stateChange(65535):expectEnpc(LINETTE, QFLAG_TALK)
        w:talk(LINETTE):expectDelegate("processEventLinetteStart"):answer(1)
    end)

    it("SEQ_000: the miners' gossip, then Nenekko at the Quicksand", function()
        local w = walkthrough.start("Min306", 0)

        w:stateChange(0):expectEnpc(MOMODI, QFLAG_TALK)
        w:talk(QHOTA_NBOLO):expectDelegate("processEvent007_8"):ack()
        w:talk(MOMODI):expectDelegate("processEvent013"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: Nenekko by the mirage of Sil'dih", function()
        local w = walkthrough.start("Min306", 10)

        w:stateChange(10):expectEnpc(MIRAGE_CIRCLE, QFLAG_PUSH)
        w:talk(MOMODI):expectDelegate("processEvent013_2"):ack()
        w:push(MIRAGE_CIRCLE):expectDelegate("processEvent020"):ack():expectStartSequence(20)
    end)

    it("SEQ_020: the ferry docks of Vesper Bay", function()
        local w = walkthrough.start("Min306", 20)

        w:stateChange(20):expectEnpc(DOCKS_CIRCLE, QFLAG_PUSH)
        w:push(DOCKS_CIRCLE):expectDelegate("processEvent030"):ack():expectStartSequence(40)
    end)

    it("SEQ_040: the twins' thanks, and payment", function()
        local w = walkthrough.start("Min306", 40)

        w:stateChange(40):expectEnpc(LINETTE, QFLAG_REWARD)
        w:talk(MOHTFRYD):expectDelegate("processEvent035_3"):ack()
        w:talk(LINETTE):expectDelegate("processEvent040"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110462)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11046201 },
            { 10, 11046202 },
            { 20, 11046203 },
            { 40, 11046204 },
        }) do
            local w = walkthrough.start("Min306", row[1])
            w:stateChange(row[1])
            w:expectMarkers(row[2])
        end
    end)
end)
