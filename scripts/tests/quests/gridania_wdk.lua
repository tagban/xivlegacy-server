-- Carpenters' Guild: Wdk200, Wdk300, Wdk306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Class ids come from
-- scripts/lua/quests/wdk/*.lua.

local ANAIDJAA      = 1000465
local HABREHAM      = 1000621
local DECIMA        = 1000622
local CHALYO_TAMLYO = 1000623
local NELLAURE      = 1000821
local CAPLAN        = 1000822
local ULMHYLT       = 1000823
local NICOLIAUX     = 1000409
local ELYN          = 1000411
local RYD           = 1000412
local NONOLATO      = 1000463
local VKOROLON      = 1000458
local NOGELOIX      = 1000597
local JOLLINE       = 1000069
local WYBIR         = 1000556
local MARCELLOIX    = 1000596
local ORCHARD       = 1091100
local STURDY        = 1091101
local SUPPLE        = 1091102
local BLOOMING      = 1091103
local WORKSHOP_DOOR = 1091104
local POWLE_BOX     = 1091105
local FETISH_MATS   = 1091106
local MIRROR        = 1091107

local ATRIUM_ARROW    = 11000067
local BLOOMING_BRANCH = 11000062
local SUPPLE_BRANCH   = 11000063
local STURDY_BRANCH   = 11000064

describe("The Mouths of Babes (Wdk200)", function()
    it("offer: A'naidjaa signs you on", function()
        local w = walkthrough.start("Wdk200", 65535)

        w:stateChange(65535):expectEnpc(ANAIDJAA, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEventANaidjaaStart"):answer(1)
    end)

    it("SEQ_000: guild chatter, then the children in the orchard", function()
        local w = walkthrough.start("Wdk200", 0)

        w:stateChange(0)
            :expectEnpc(ORCHARD, QFLAG_PUSH)
            :expectEnpc(ANAIDJAA, 0)
        w:talk(ANAIDJAA):expectDelegate("processEvent005_2"):ack()
        w:talk(DECIMA):expectDelegate("processEvent005_3"):ack()
        w:talk(HABREHAM):expectDelegate("processEvent005_7"):ack()
        w:push(ORCHARD):expectDelegate("processEvent010"):ack()
            :expectAddItem(ATRIUM_ARROW, 1)
            :expectStartSequence(10)
    end)

    it("SEQ_010: Wybir takes the arrows", function()
        local w = walkthrough.start("Wdk200", 10)
        w:give(ATRIUM_ARROW, 1)

        w:stateChange(10):expectEnpc(WYBIR, QFLAG_TALK)
        w:talk(NICOLIAUX):expectDelegate("processEvent010_3"):ack()
        w:talk(WYBIR):expectDelegate("processEvent020"):ack()
            :expectRemoveItem(ATRIUM_ARROW, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: pick up a branch, swapping the one you hold", function()
        local w = walkthrough.start("Wdk200", 20)
        w:give(STURDY_BRANCH, 1)

        w:stateChange(20)
            :expectEnpc(STURDY, QFLAG_TALK)
            :expectEnpc(SUPPLE, QFLAG_TALK)
            :expectEnpc(BLOOMING, QFLAG_TALK)
        w:talk(SUPPLE):expectDelegate("processEvent020_4_2"):ack()
            :expectDelegate("processEvent020_4"):answer(1)
            :expectRemoveItem(STURDY_BRANCH, 1)
            :expectAddItem(SUPPLE_BRANCH, 1)
        w:talk(BLOOMING):expectDelegate("processEvent020_5_2"):ack()
            :expectDelegate("processEvent020_5"):answer(2)
            :expectNoRemoveItem()
    end)

    it("SEQ_020: no branch yet, Wybir says where to look", function()
        local w = walkthrough.start("Wdk200", 20)

        w:talk(WYBIR):expectDelegate("processEvent020_2"):ack():expectNoRemoveItem()
    end)

    it("SEQ_020: the wrong branches are sent back", function()
        local w = walkthrough.start("Wdk200", 20)
        w:give(STURDY_BRANCH, 1)
        w:talk(WYBIR):expectDelegate("processEvent020_6"):ack():expectRemoveItem(STURDY_BRANCH, 1)
        w:give(BLOOMING_BRANCH, 1)
        w:talk(WYBIR):expectDelegate("processEvent020_7"):ack():expectRemoveItem(BLOOMING_BRANCH, 1)
        w:expectSequence(20)
    end)

    it("SEQ_020: the supple branch mends the bow", function()
        local w = walkthrough.start("Wdk200", 20)
        w:give(SUPPLE_BRANCH, 1)

        w:talk(WYBIR):expectDelegate("processEvent025"):ack()
            :expectRemoveItem(SUPPLE_BRANCH, 1)
            :expectStartSequence(25)
    end)

    it("SEQ_025: back to the orchard, Marcelloix turns up", function()
        local w = walkthrough.start("Wdk200", 25)

        w:stateChange(25):expectEnpc(ORCHARD, QFLAG_PUSH)
        w:talk(WYBIR):expectDelegate("processEvent025_3"):ack()
        w:push(ORCHARD):expectDelegate("processEvent030"):ack():expectStartSequence(30)
    end)

    it("SEQ_030: A'naidjaa's payment", function()
        local w = walkthrough.start("Wdk200", 30)

        w:stateChange(30):expectEnpc(ANAIDJAA, QFLAG_REWARD)
        w:talk(CHALYO_TAMLYO):expectDelegate("processEvent030_5"):ack()
        w:talk(ANAIDJAA):expectDelegate("processEvent040"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110300)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11030001 },
            { 10, 11030002 },
            { 20, 11030002 },
            { 25, 11030003 },
            { 30, nil },
        }) do
            local w = walkthrough.start("Wdk200", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)

local BUILDING_BLOCK = 11000029
local SUGARLOAF_HAT  = 8010932

describe("Hide and Seek Shenanigans (Wdk300)", function()
    it("offer: A'naidjaa asks you to mind the children", function()
        local w = walkthrough.start("Wdk300", 65535)

        w:stateChange(65535):expectEnpc(ANAIDJAA, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEventANaidjaaStart"):answer(1)
    end)

    it("SEQ_000: guild chatter, then the workshop door", function()
        local w = walkthrough.start("Wdk300", 0)

        w:stateChange(0):expectEnpc(WORKSHOP_DOOR, QFLAG_TALK)
        w:talk(ULMHYLT):expectDelegate("processEvent005_7"):ack()
        w:talk(WORKSHOP_DOOR):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: the children slip off to play hide-and-seek", function()
        local w = walkthrough.start("Wdk300", 10)

        w:stateChange(10):expectEnpc(WORKSHOP_DOOR, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEventS000_0"):ack()
        w:talk(WORKSHOP_DOOR):expectDelegate("processEvent020"):ack():expectStartSequence(20)
    end)

    it("SEQ_020-021: Nicoliaux in the orchard, and his slip about Ryd", function()
        local w = walkthrough.start("Wdk300", 20)

        w:stateChange(20):expectEnpc(NICOLIAUX, QFLAG_TALK)
        w:talk(NICOLIAUX):expectDelegate("processEventS000_1"):ack():expectStartSequence(21)
        w:stateChange(21):expectEnpc(NICOLIAUX, QFLAG_TALK)
        w:talk(NICOLIAUX):expectDelegate("processEventS000_5"):ack()
            :expectDelegate("processEventS000_6"):ack()
            :expectStartSequence(22)
    end)

    it("SEQ_022-023: Ryd at the barracks, Powle in the box", function()
        local w = walkthrough.start("Wdk300", 22)

        w:stateChange(22):expectEnpc(RYD, QFLAG_TALK)
        w:talk(JOLLINE):expectDelegate("processEventS001_1"):ack()
        w:talk(RYD):expectDelegate("processEventS001_3"):ack()
            :expectDelegate("processEventS001_4"):ack()
            :expectStartSequence(23)
        w:stateChange(23):expectEnpc(POWLE_BOX, QFLAG_TALK)
        w:talk(POWLE_BOX):expectDelegate("processEventS001_5"):answer(0)
        w:expectSequence(23)
        w:talk(POWLE_BOX):expectDelegate("processEventS001_5"):answer(1):expectStartSequence(24)
    end)

    it("SEQ_024: Elyn leads you on, then gives you her toys", function()
        local w = walkthrough.start("Wdk300", 24)

        w:stateChange(24):expectEnpc(ELYN, QFLAG_TALK)
        w:talk(ELYN):expectDelegate("processEventS003_1"):ack()
        w:talk(ELYN):expectDelegate("processEventS003_3"):ack()
        w:talk(ELYN):expectDelegate("processEventS003_6"):ack()
            :expectAddItem(SUGARLOAF_HAT, 1)
            :expectAddItem(BUILDING_BLOCK, 1)
            :expectStartSequence(26)
    end)

    it("SEQ_026-030: back to the workshop, then A'naidjaa's errand", function()
        local w = walkthrough.start("Wdk300", 26)

        w:stateChange(26):expectEnpc(WORKSHOP_DOOR, QFLAG_TALK)
        w:talk(WORKSHOP_DOOR):expectDelegate("processEvent030"):ack():expectStartSequence(30)
        w:stateChange(30):expectEnpc(ANAIDJAA, QFLAG_TALK)
        w:talk(NELLAURE):expectDelegate("processEvent025_2"):ack()
        w:talk(ANAIDJAA):expectDelegate("processEvent040"):ack():expectStartSequence(40)
    end)

    it("SEQ_040-050: the Phrontistery, and the ghost", function()
        local w = walkthrough.start("Wdk300", 40)

        w:stateChange(40):expectEnpc(NOGELOIX, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEvent040_2"):ack()
        w:talk(NOGELOIX):expectDelegate("processEvent050"):ack():expectStartSequence(50)
        w:stateChange(50):expectEnpc(ANAIDJAA, QFLAG_TALK)
        w:talk(NOGELOIX):expectDelegate("processEvent050_7"):ack()
        w:talk(ANAIDJAA):expectDelegate("processEvent055"):answer(2):expectStartSequence(55)
    end)

    it("SEQ_055-060: Marcelloix at the Roost, and payment", function()
        local w = walkthrough.start("Wdk300", 55)

        w:stateChange(55):expectEnpc(VKOROLON, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEvent055_2"):ack()
        w:talk(VKOROLON):expectDelegate("processEvent060"):ack():expectStartSequence(60)
        w:stateChange(60):expectEnpc(ANAIDJAA, QFLAG_REWARD)
        w:talk(ANAIDJAA):expectDelegate("processEvent070"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110301)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11030101 },
            { 10, 11030102 },
            { 20, nil },
            { 21, nil },
            { 22, nil },
            { 23, nil },
            { 24, nil },
            { 26, 11030103 },
            { 30, 11030104 },
            { 40, 11030105 },
            { 50, nil },
            { 55, 11030106 },
            { 60, nil },
        }) do
            local w = walkthrough.start("Wdk300", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)

local FETISH = 11000065

describe("Spanning the Spectrum (Wdk306)", function()
    it("offer: Marcelloix plans an outing", function()
        local w = walkthrough.start("Wdk306", 65535)

        w:stateChange(65535):expectEnpc(MARCELLOIX, QFLAG_TALK)
        w:talk(MARCELLOIX):expectDelegate("processEventMarcelloixStart"):answer(1)
    end)

    it("SEQ_000: the children in the orchard", function()
        local w = walkthrough.start("Wdk306", 0)

        w:stateChange(0):expectEnpc(ORCHARD, QFLAG_PUSH)
        w:talk(CAPLAN):expectDelegate("processEvent005_4"):ack()
        w:push(ORCHARD):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: no fetish yet", function()
        local w = walkthrough.start("Wdk306", 10)

        w:stateChange(10)
            :expectEnpc(NICOLIAUX, QFLAG_TALK)
            :expectEnpc(FETISH_MATS, QFLAG_TALK)
        w:talk(NICOLIAUX):expectDelegate("processEventS000_1"):ack():expectNoRemoveItem()
        w:expectSequence(10)
    end)

    it("SEQ_010: make a fetish and give it to Nicoliaux", function()
        local w = walkthrough.start("Wdk306", 10)

        w:talk(FETISH_MATS):expectAddItem(FETISH, 1)
        w:talk(NICOLIAUX):expectDelegate("processEventS002_2"):ack()
            :expectDelegate("processEvent020"):ack()
            :expectRemoveItem(FETISH, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020-023: Nonolato, then Wybir", function()
        local w = walkthrough.start("Wdk306", 20)

        w:stateChange(20):expectEnpc(NONOLATO, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEvent020_1"):ack()
        w:talk(NONOLATO):expectDelegate("processEvent023"):ack():expectStartSequence(23)
        w:stateChange(23):expectEnpc(WYBIR, QFLAG_TALK)
        w:talk(NONOLATO):expectDelegate("processEvent023_1"):ack()
        w:talk(WYBIR):expectDelegate("processEvent025"):ack():expectStartSequence(30)
    end)

    it("SEQ_030-040: A'naidjaa, then off to the Mirror", function()
        local w = walkthrough.start("Wdk306", 30)

        w:stateChange(30):expectEnpc(ANAIDJAA, QFLAG_TALK)
        w:talk(ANAIDJAA):expectDelegate("processEvent030"):ack():expectStartSequence(40)
        w:stateChange(40):expectEnpc(MIRROR, QFLAG_TALK)
        w:talk(DECIMA):expectDelegate("processEvent030_3"):ack()
        w:talk(MIRROR):expectDelegate("processEvent040"):ack():expectStartSequence(45)
    end)

    it("SEQ_045-055: rain, drawings, and Marcelloix's thanks", function()
        local w = walkthrough.start("Wdk306", 45)

        w:talk(MIRROR):expectDelegate("processEvent050"):ack():expectStartSequence(50)
        w:talk(MIRROR):expectDelegate("processEvent055"):answer(3):expectStartSequence(55)
        w:stateChange(55):expectEnpc(MIRROR, QFLAG_REWARD)
        w:talk(MIRROR):expectDelegate("processEvent060"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110302)
    end)

    it("map markers point at the next cutscene", function()
        for _, row in ipairs({
            { 0, 11030201 },
            { 10, 11030202 },
            { 20, nil },
            { 23, nil },
            { 30, 11030203 },
            { 40, 11030204 },
            { 45, 11030205 },
            { 50, nil },
            { 55, 11030206 },
        }) do
            local w = walkthrough.start("Wdk306", row[1])
            w:stateChange(row[1])
            if row[2] then w:expectMarkers(row[2]) else w:expectMarkers() end
        end
    end)
end)
