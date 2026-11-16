-- Alchemists' Guild quests at Frondale's Phrontistery: Alc200, Alc300, Alc306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Each case seeds the
-- sequence it walks; crafted pieces are put in the bag with `give`.

-- Actor class ids (from scripts/lua/quests/alc/*.lua).
local NOGELOIX     = 1000597
local XAU_NBOLO    = 1000641
local OEFYRBLAET   = 1000642
local BABAKI       = 1000643
local NOMOMO       = 1001392
local SLYHHIA      = 1000932
local DAMIELLIOT   = 1000853
local SCHOOLGIRL   = 1001039
local PENELOPE     = 1700001
local MIOUNNE      = 1000230

local MOLE           = 11000076
local MEDICINE       = 11000077
local POULTICE       = 11000078
local SALVE          = 11000079
local STARFALL_GRASS = 11000041

describe("Sleep, Cousin of Death (Alc200)", function()
    it("offer: Nogeloix signs you on", function()
        local w = walkthrough.start("Alc200", 65535)

        w:stateChange(65535):expectEnpc(NOGELOIX, QFLAG_TALK)
        w:talk(NOGELOIX):expectDelegate("processEventNogeloixStart"):answer(1)
    end)

    it("SEQ_000: the Phrontistery's chatter, then Nomomo's reagent", function()
        local w = walkthrough.start("Alc200", 0)

        w:stateChange(0):expectEnpc(NOMOMO, QFLAG_TALK)
        w:talk(NOGELOIX):expectDelegate("processEvent005_2"):ack()
        w:talk(BABAKI):expectDelegate("processEvent005_5"):ack()
        w:talk(NOMOMO):expectDelegate("processEvent010"):ack()
            :expectAddItem(MOLE, 1)
            :expectStartSequence(10)
    end)

    it("SEQ_010: no medicine yet", function()
        local w = walkthrough.start("Alc200", 10)

        w:stateChange(10):expectEnpc(NOGELOIX, QFLAG_TALK)
        w:expectMarkers(11042001)
        w:talk(NOMOMO):expectDelegate("processEvent010_2"):ack()
        w:talk(NOGELOIX):expectDelegate("processEvent005_2"):ack()
    end)

    it("SEQ_010: the medicine shown to Nogeloix", function()
        local w = walkthrough.start("Alc200", 10)

        w:give(MEDICINE)
        w:talk(NOGELOIX):expectDelegate("processEvent015"):ack()
            :expectNoRemoveItem()
            :expectStartSequence(15)
    end)

    it("SEQ_015: S'lyhhia takes you to Damielliot", function()
        local w = walkthrough.start("Alc200", 15)

        w:stateChange(15):expectEnpc(SLYHHIA, QFLAG_TALK)
        w:expectMarkers(11042002)
        w:talk(NOGELOIX):expectDelegate("processEvent015_2"):ack()
        w:give(MEDICINE)
        w:talk(SLYHHIA):expectDelegate("processEvent015_6"):answer(2):expectNoRemoveItem()
        w:talk(SLYHHIA):expectDelegate("processEvent015_6"):answer(1)
            :expectDelegate("processEvent020"):ack()
            :expectRemoveItem(MEDICINE, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: payment from Nogeloix", function()
        local w = walkthrough.start("Alc200", 20)

        w:stateChange(20):expectEnpc(NOGELOIX, QFLAG_REWARD)
        w:talk(SLYHHIA):expectDelegate("processEvent020_2"):ack()
        w:talk(NOGELOIX):expectDelegate("processEvent030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110420)
    end)
end)

describe("The Boy and the Dragon Gay (Alc300)", function()
    it("offer: Nogeloix asks you to visit Damielliot", function()
        local w = walkthrough.start("Alc300", 65535)

        w:stateChange(65535):expectEnpc(NOGELOIX, QFLAG_TALK)
        w:talk(NOGELOIX):expectDelegate("processEventNogeloixStart"):answer(1)
    end)

    it("SEQ_000-005: dragons, the children's tale, Nogeloix's errand", function()
        local w = walkthrough.start("Alc300", 0)

        w:stateChange(0):expectEnpc(DAMIELLIOT, QFLAG_TALK)
        w:talk(XAU_NBOLO):expectDelegate("processEvent002_3"):ack()
        w:talk(DAMIELLIOT):expectDelegate("processEvent003"):ack():expectStartSequence(3)
        w:stateChange(3):expectEnpc(SCHOOLGIRL, QFLAG_TALK)
        w:talk(SCHOOLGIRL):expectDelegate("processEvent005"):ack():expectStartSequence(5)
        w:stateChange(5):expectEnpc(NOGELOIX, QFLAG_TALK)
        w:talk(DAMIELLIOT):expectDelegate("processEvent005_2"):ack()
        w:talk(NOGELOIX):expectDelegate("processEvent007"):ack():expectStartSequence(7)
    end)

    it("SEQ_007: Penelope has the grass", function()
        local w = walkthrough.start("Alc300", 7)

        w:stateChange(7):expectEnpc(PENELOPE, QFLAG_TALK)
        w:talk(MIOUNNE):expectDelegate("processEvent007_6"):ack()
        w:talk(PENELOPE):expectDelegate("processEvent008"):ack():expectStartSequence(8)
    end)

    it("SEQ_008: Miounne's price, then Penelope's tale", function()
        local w = walkthrough.start("Alc300", 8)

        w:stateChange(8):expectEnpc(MIOUNNE, QFLAG_TALK)
        w:expectMarkers(11042101)
        w:talk(PENELOPE):expectDelegate("processEvent008_2"):ack()
        w:talk(MIOUNNE):expectDelegate("processEvent008_5"):answer(2)
        w:talk(MIOUNNE):expectDelegate("processEvent008_5"):answer(1):expectFlagSet(0)
        w:talk(MIOUNNE):expectDelegate("processEvent008_6"):ack()
        w:talk(PENELOPE):expectDelegate("processEvent010"):ack()
            :expectAddItem(STARFALL_GRASS, 1)
            :expectStartSequence(10)
    end)

    it("SEQ_010: the grass to Nogeloix", function()
        local w = walkthrough.start("Alc300", 10)

        w:stateChange(10):expectEnpc(NOGELOIX, QFLAG_TALK)
        w:talk(PENELOPE):expectDelegate("processEvent010_2"):ack()
        w:give(STARFALL_GRASS)
        w:talk(NOGELOIX):expectDelegate("processEvent015"):ack()
            :expectRemoveItem(STARFALL_GRASS, 1)
            :expectStartSequence(15)
    end)

    it("SEQ_015: a story for the children, and payment", function()
        local w = walkthrough.start("Alc300", 15)

        w:stateChange(15):expectEnpc(SLYHHIA, QFLAG_REWARD)
        w:expectMarkers(11042102)
        w:talk(SLYHHIA):expectDelegate("processEvent015_3"):ack()
            :expectDelegate("processEvent020"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110421)
    end)
end)

describe("Dream On, Dream Away (Alc306)", function()
    it("offer: S'lyhhia asks for help with the children", function()
        local w = walkthrough.start("Alc306", 65535)

        w:stateChange(65535):expectEnpc(SLYHHIA, QFLAG_TALK)
        w:talk(SLYHHIA):expectDelegate("processEventSlyhhiaStart"):answer(1)
    end)

    it("SEQ_000: the Echo declined", function()
        local w = walkthrough.start("Alc306", 0)

        w:stateChange(0):expectEnpc(DAMIELLIOT, QFLAG_TALK)
        w:expectMarkers(11042201)
        w:talk(SCHOOLGIRL):expectDelegate("processEvent002_10"):ack()
        w:talk(DAMIELLIOT):expectDelegate("processEvent005"):answer(2)
    end)

    it("SEQ_000: the Echo, the fallen boy and the poultice", function()
        local w = walkthrough.start("Alc306", 0)

        w:talk(DAMIELLIOT):expectDelegate("processEvent005"):answer(1)
            :expectDelegate("processEvent000"):ack()
            :expectDelegate("processEvent008"):ack()
            :expectDelegate("processEvent009"):ack()
            :expectAddItem(POULTICE, 1)
            :expectStartSequence(10)
    end)

    it("SEQ_010: no salve yet", function()
        local w = walkthrough.start("Alc306", 10)

        w:stateChange(10):expectEnpc(DAMIELLIOT, QFLAG_TALK)
        w:talk(DAMIELLIOT):expectDelegate("processEvent009_2"):ack():expectNoRemoveItem()
    end)

    it("SEQ_010: the salve, and Damielliot wakes", function()
        local w = walkthrough.start("Alc306", 10)

        w:give(SALVE)
        w:talk(DAMIELLIOT):expectDelegate("processEvent010"):ack()
            :expectRemoveItem(SALVE, 1)
            :expectStartSequence(20)
    end)

    it("SEQ_020: the news to Nogeloix, and payment", function()
        local w = walkthrough.start("Alc306", 20)

        w:stateChange(20):expectEnpc(NOGELOIX, QFLAG_REWARD)
        w:expectMarkers(11042203)
        w:talk(DAMIELLIOT):expectDelegate("processEvent020_10"):ack()
        w:talk(OEFYRBLAET):expectDelegate("processEvent020_8"):ack()
        w:talk(NOGELOIX):expectDelegate("processEvent030"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110422)
    end)
end)
