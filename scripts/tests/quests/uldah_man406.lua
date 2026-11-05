-- Main story: "Futures Perfect" (Man406).
--
-- Quest-hook legs only (the `walkthrough` bridge). The patrol fight and the
-- move into the children's cave run on the content substrate
-- (SimpleContentMan40601 / QuestDirectorMan40601); the leg after it is
-- seeded at SEQ_045.

-- Actor class ids (from scripts/lua/quests/man/man406.lua).
local MINFILIA             = 1000843
local TATARU               = 1001046
local NENEKANI             = 1001374
local RESISTANCE_CAPTAIN   = 1000477
local BRUTISH_MEMBER       = 1000478
local STRAPPING_MEMBER     = 1000479
local DISPASSIONATE_MEMBER = 1000480
local UNBLOODIED_MEMBER    = 1000482
local SHUDDERING_CHILD     = 1000957
local ULDAH_MARKET         = 1090265
local REVENANTS_TOLL       = 1090369
local IMPERIALS_STOP       = 1090370
local CAVE_EXIT            = 1090371

describe("Futures Perfect (Man406)", function()
    it("offer: Tataru's summons, accepted into the audience", function()
        local w = walkthrough.start("Man406", 65535)

        w:stateChange(65535):expectEnpc(TATARU, QFLAG_TALK)
        w:talk(TATARU):expectDelegate("pES"):answer(1)
    end)

    it("SEQ_000: the captain's plan and Minfilia's doubts", function()
        local w = walkthrough.start("Man406", 0)

        w:stateChange(0)
            :expectEnpc(RESISTANCE_CAPTAIN, QFLAG_TALK)
            :expectEnpc(STRAPPING_MEMBER, 0)
            :expectEnpc(MINFILIA, 0)
        w:expectMarkers(11001901)

        w:talk(MINFILIA):expectDelegate("processEvent010_7"):ack()
        w:talk(NENEKANI):expectDelegate("processEvent000_4"):ack()
        w:talk(RESISTANCE_CAPTAIN):expectDelegate("pE10"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: every tale heard, then the captain leaves with your companion", function()
        local w = walkthrough.start("Man406", 10)

        w:stateChange(10)
            :expectEnpc(RESISTANCE_CAPTAIN, 0)
            :expectEnpc(BRUTISH_MEMBER, QFLAG_TALK)

        -- The captain waits until every member has been heard.
        w:talk(RESISTANCE_CAPTAIN):expectDelegate("processEvent010_3"):ack()
        w:talk(STRAPPING_MEMBER):expectDelegate("processEvent010_2"):ack():expectFlagSet(0)
        w:talk(DISPASSIONATE_MEMBER):expectDelegate("processEvent010_4"):ack():expectFlagSet(1)
        w:talk(BRUTISH_MEMBER):expectDelegate("processEvent010_5"):ack():expectFlagSet(2)
        w:talk(UNBLOODIED_MEMBER):expectDelegate("processEvent010_6"):ack():expectFlagSet(3)
        w:talk(MINFILIA):expectDelegate("processEvent010_9"):ack()

        w:stateChange(10):expectEnpc(RESISTANCE_CAPTAIN, QFLAG_TALK)
        w:talk(RESISTANCE_CAPTAIN):expectDelegate("pE15"):ack():expectStartSequence(15)
    end)

    it("SEQ_015/020: Camp Revenant's Toll, then the patrol's stop starts the duty", function()
        local w = walkthrough.start("Man406", 15)

        w:stateChange(15):expectEnpc(REVENANTS_TOLL, QFLAG_PUSH)
        w:expectMarkers(11001902)
        w:talk(TATARU):expectDelegate("pE17"):ack()
        w:talk(MINFILIA):expectDelegate("pE16"):ack()
        w:push(REVENANTS_TOLL):expectDelegate("processEvent020"):ack():expectStartSequence(20)

        w:stateChange(20):expectEnpc(IMPERIALS_STOP, QFLAG_PUSH)
        w:push(IMPERIALS_STOP):expectDelegate("processEvent025"):ack()
            :expectCreateContentArea()
            :expectZoneChangeContent()
    end)

    it("SEQ_045: the children's cave, and waking by the camp", function()
        local w = walkthrough.start("Man406", 45)

        w:stateChange(45):expectEnpc(CAVE_EXIT, QFLAG_PUSH)
        w:expectMarkers(11001904)
        w:talk(SHUDDERING_CHILD):expectDelegate("processEvent045_1"):ack()
        w:push(CAVE_EXIT):expectDelegate("pE50"):ack():expectStartSequence(50)
    end)

    it("SEQ_050: the report at the Waking Sands", function()
        local w = walkthrough.start("Man406", 50)

        w:stateChange(50)
            :expectEnpc(TATARU, QFLAG_REWARD)
            :expectEnpc(ULDAH_MARKET, QFLAG_PUSH)
        w:expectMarkers(11001905)
        w:talk(MINFILIA):expectDelegate("pE61"):ack()
        w:talk(NENEKANI):expectDelegate("processEvent060_3"):ack()
        w:talk(TATARU):expectDelegate("pE60"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(138000)
            :expectCompleted(110019)
    end)
end)
