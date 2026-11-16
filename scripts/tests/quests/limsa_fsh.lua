-- Fishermen's Guild quests at Fisherman's Bottom: Fsh200, Fsh300, Fsh306.
--
-- Quest-hook legs only (the `walkthrough` bridge). Each case seeds the
-- sequence it walks; catches are put in the bag with `give`.

-- Actor class ids (from scripts/lua/quests/fsh/*.lua).
local NNMULIKA    = 1000153
local SISIPU      = 1000155
local MAISIE      = 1000173
local ASTRID      = 1000180
local CLIFTON     = 1000199
local UNDSATZ     = 1000200
local RERENASU    = 1000201
local DACA_JINJAHL = 1000202
local BLOEMERL    = 1000203
local ROROJARU    = 1000374

local PIXIE_REMORA = 11000127
local BARREL_FEED  = 11000025
local NAUTILUS     = 3011203

describe("To Fight a Fishback (Fsh200)", function()
    it("offer: N'nmulika welcomes you to the pullers", function()
        local w = walkthrough.start("Fsh200", 65535)

        w:stateChange(65535):expectEnpc(NNMULIKA, QFLAG_TALK)
        w:talk(NNMULIKA):expectDelegate("processEventNnmulikaStart"):answer(1)
    end)

    it("SEQ_000: the guild's chatter, then Maisie's job", function()
        local w = walkthrough.start("Fsh200", 0)
        w:expectMarkers(11050001)

        w:stateChange(0)
            :expectEnpc(MAISIE, QFLAG_TALK)
            :expectEnpc(NNMULIKA, 0)
        w:talk(NNMULIKA):expectDelegate("processEvent005_2"):ack()
        w:talk(CLIFTON):expectDelegate("processEvent010_5"):ack()
        w:talk(DACA_JINJAHL):expectDelegate("processEvent010_6"):ack()
        w:talk(BLOEMERL):expectDelegate("processEvent010_7"):ack()
        w:talk(MAISIE):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: no remora yet", function()
        local w = walkthrough.start("Fsh200", 10)
        w:expectMarkers(11050002)

        w:stateChange(10):expectEnpc(MAISIE, QFLAG_REWARD)
        w:talk(MAISIE):expectDelegate("processEvent010_9"):ack():expectNoRemoveItem()
    end)

    it("SEQ_010: the remora, and payment", function()
        local w = walkthrough.start("Fsh200", 10)

        w:give(PIXIE_REMORA)
        w:talk(MAISIE):expectDelegate("processEvent020"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectRemoveItem(PIXIE_REMORA, 1)
            :expectGil(20000)
            :expectExp(2000)
            :expectCompleted(110500)
    end)
end)

describe("The Beast of the Barrel (Fsh300)", function()
    it("offer: N'nmulika has a job for you", function()
        local w = walkthrough.start("Fsh300", 65535)

        w:stateChange(65535):expectEnpc(NNMULIKA, QFLAG_TALK)
        w:talk(NNMULIKA):expectDelegate("processEventNnmulikaStart"):answer(1)
    end)

    it("SEQ_000: Sisipu's bucket of feed", function()
        local w = walkthrough.start("Fsh300", 0)
        w:expectMarkers(11050101)

        w:stateChange(0):expectEnpc(SISIPU, QFLAG_TALK)
        w:talk(NNMULIKA):expectDelegate("processEvent010_1000"):ack()
        w:talk(SISIPU):expectDelegate("processEvent010"):ack()
            :expectAddItem(BARREL_FEED, 1)
            :expectStartSequence(10)
    end)

    it("SEQ_010: staying ashore", function()
        local w = walkthrough.start("Fsh300", 10)
        w:expectMarkers(11050102)

        w:stateChange(10):expectEnpc(RERENASU, QFLAG_TALK)
        w:talk(SISIPU):expectDelegate("processEvent010_2"):ack()
        w:talk(RERENASU):expectDelegate("processEvent010_1001"):answer(2)
            :expectNoRemoveItem()
    end)

    it("SEQ_010: the Barrel, the stranger's dance, off to Ul'dah", function()
        local w = walkthrough.start("Fsh300", 10)

        w:give(BARREL_FEED)
        w:talk(RERENASU):expectDelegate("processEvent010_1001"):answer(1)
            :expectDelegate("processEvent020"):ack()
            :expectDelegate("processEvent025"):ack()
            :expectRemoveItem(BARREL_FEED, 1)
            :expectStartSequence(28)
    end)

    it("SEQ_028: Rorojaru's outfit", function()
        local w = walkthrough.start("Fsh300", 28)

        w:stateChange(28):expectEnpc(ROROJARU, QFLAG_TALK)
        w:talk(MAISIE):expectDelegate("processEvent025_6"):ack()
        w:talk(ROROJARU):expectDelegate("processEvent028"):ack():expectStartSequence(29)
    end)

    it("SEQ_029: back to the Barrel to dance and fish", function()
        local w = walkthrough.start("Fsh300", 29)
        w:expectMarkers(11050104)

        w:stateChange(29):expectEnpc(RERENASU, QFLAG_TALK)
        w:talk(DACA_JINJAHL):expectDelegate("processEvent028_6"):ack()
        w:talk(RERENASU):expectDelegate("processEvent010_1001"):answer(1)
            :expectDelegate("processEvent030"):ack()
            :expectDelegate("processEvent040"):ack()
            :expectDelegate("processEvent050"):ack()
            :expectStartSequence(50)
    end)

    it("SEQ_050: Sisipu hears the tale", function()
        local w = walkthrough.start("Fsh300", 50)
        w:expectMarkers(11050107)

        w:stateChange(50):expectEnpc(SISIPU, QFLAG_TALK)
        w:talk(SISIPU):expectDelegate("processEvent060"):ack():expectStartSequence(60)
    end)

    it("SEQ_060: the Echo at the netmaster's door", function()
        local w = walkthrough.start("Fsh300", 60)
        w:expectMarkers(11050108)

        w:stateChange(60):expectEnpc(SISIPU, QFLAG_TALK)
        w:talk(ASTRID):expectDelegate("processEvent050_3"):ack()
        w:talk(SISIPU):expectDelegate("processEvent070"):answer(1):expectStartSequence(70)
    end)

    it("SEQ_070: N'nmulika's apology and payment", function()
        local w = walkthrough.start("Fsh300", 70)

        w:stateChange(70):expectEnpc(NNMULIKA, QFLAG_REWARD)
        w:talk(SISIPU):expectDelegate("processEvent070_2"):ack()
        w:talk(NNMULIKA):expectDelegate("processEvent075"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(30000)
            :expectExp(3000)
            :expectCompleted(110501)
    end)
end)

describe("Polishing the Mast (Fsh306)", function()
    it("offer: N'nmulika invites you to the meeting", function()
        local w = walkthrough.start("Fsh306", 65535)

        w:stateChange(65535):expectEnpc(NNMULIKA, QFLAG_TALK)
        w:talk(NNMULIKA):expectDelegate("processEventNnmulikaStart"):answer(1)
    end)

    it("SEQ_000: the meeting and the sale", function()
        local w = walkthrough.start("Fsh306", 0)
        w:expectMarkers(11050201)

        w:stateChange(0):expectEnpc(NNMULIKA, QFLAG_TALK)
        w:talk(MAISIE):expectDelegate("processEvent005_6"):ack()
        w:talk(NNMULIKA):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: which catch the guild wants", function()
        local w = walkthrough.start("Fsh306", 10)

        w:stateChange(10):expectEnpc(NNMULIKA, QFLAG_TALK)
        w:talk(UNDSATZ):expectDelegate("processEvent010_4"):ack()
        w:talk(NNMULIKA):expectDelegate("processEvent015"):ack():expectStartSequence(15)
    end)

    it("SEQ_015: no nautilus yet", function()
        local w = walkthrough.start("Fsh306", 15)
        w:expectMarkers(11050202)

        w:talk(NNMULIKA):expectDelegate("processEvent016"):ack():expectNoRemoveItem()
    end)

    it("SEQ_015: the nautilus sold, the sale closes", function()
        local w = walkthrough.start("Fsh306", 15)

        w:give(NAUTILUS)
        w:talk(NNMULIKA):expectDelegate("processEvent015_3"):ack()
            :expectRemoveItem(NAUTILUS, 1)
            :expectGil(1000)
            :expectDelegate("processEvent020"):ack()
            :expectStartSequence(20)
    end)

    it("SEQ_020: turned away at the netmaster's door", function()
        local w = walkthrough.start("Fsh306", 20)
        w:expectMarkers(11050203)

        w:stateChange(20):expectEnpc(SISIPU, QFLAG_TALK)
        w:talk(RERENASU):expectDelegate("processEvent020_6"):ack()
        w:talk(SISIPU):expectDelegate("processEvent030"):ack():expectStartSequence(30)
    end)

    it("SEQ_030-050: the Echo, three times", function()
        local w = walkthrough.start("Fsh306", 30)
        w:expectMarkers(11050204)

        w:stateChange(30):expectEnpc(SISIPU, QFLAG_TALK)
        w:talk(SISIPU):expectDelegate("processEvent040"):answer(1):expectStartSequence(40)
        w:talk(SISIPU):expectDelegate("processEvent050"):answer(1):expectStartSequence(50)
        w:stateChange(50):expectEnpc(MAISIE, QFLAG_TALK)
        w:talk(SISIPU):expectDelegate("processEvent050_2"):ack()
        w:talk(MAISIE):expectDelegate("processEvent060"):answer(1):expectStartSequence(60)
    end)

    it("SEQ_030: turning the Echo down", function()
        local w = walkthrough.start("Fsh306", 30)

        w:talk(SISIPU):expectDelegate("processEvent040"):answer(2)
            :expectSequence(30)
    end)

    it("SEQ_060: N'nmulika's payment", function()
        local w = walkthrough.start("Fsh306", 60)

        w:stateChange(60):expectEnpc(NNMULIKA, QFLAG_REWARD)
        w:talk(MAISIE):expectDelegate("processEvent060_2"):ack()
        w:talk(NNMULIKA):expectDelegate("processEvent070"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectExp(3600)
            :expectCompleted(110502)
    end)
end)
