-- Archers' Guild: "There Can Be Only One" (Arc306).
--
-- Quest-hook legs only (the `walkthrough` bridge). The fight with Siward
-- runs on the content substrate (SimpleContentArc30601, directed by
-- QuestDirectorArc30601); the leg after it is seeded at SEQ_040.

-- Actor class ids (from scripts/lua/quests/arc/arc306.lua).
local NONOLATO     = 1000463
local BUBUKU       = 1000625
local ODHINEK      = 1000829
local MIANNE       = 1000832
local CHLOE        = 1001175
local KEELTY_GUILD = 1090510
local KEELTY_WOOD  = 1090518

describe("There Can Be Only One (Arc306)", function()
    it("offer: Nonolato asks you to find Keelty", function()
        local w = walkthrough.start("Arc306", 65535)

        w:stateChange(65535):expectEnpc(NONOLATO, QFLAG_TALK)
        w:talk(NONOLATO):expectDelegate("processEventNonolatoStart"):answer(1)
    end)

    it("SEQ_000: the archers' word, then Keelty in the wood", function()
        local w = walkthrough.start("Arc306", 0)

        w:stateChange(0)
            :expectEnpc(KEELTY_WOOD, QFLAG_PUSH)
            :expectEnpc(NONOLATO, 0)
        w:expectMarkers(11016201)
        w:talk(NONOLATO):expectDelegate("processEvent005_2"):ack()
        w:talk(MIANNE):expectDelegate("processEvent005_3"):ack()
        w:talk(BUBUKU):expectDelegate("processEvent005_5"):ack()
        w:talk(CHLOE):expectDelegate("processEvent005_8"):ack()
        w:push(KEELTY_WOOD):expectDelegate("processEvent010"):ack():expectStartSequence(10)
    end)

    it("SEQ_010: back for Keelty, into the fight with Siward", function()
        local w = walkthrough.start("Arc306", 10)

        w:stateChange(10):expectEnpc(KEELTY_WOOD, QFLAG_PUSH)
        w:expectMarkers(11016202)
        w:talk(MIANNE):expectDelegate("processEvent010_2"):ack()
        w:push(KEELTY_WOOD):expectDelegate("processEvent020"):ack()
            :expectStartSequence(20)
            :expectCreateContentArea()
            :expectZoneChangeContent()
    end)

    it("SEQ_020: after a lost fight, straight back in", function()
        local w = walkthrough.start("Arc306", 20)

        w:stateChange(20):expectEnpc(KEELTY_WOOD, QFLAG_PUSH)
        w:expectMarkers(11016203)
        w:push(KEELTY_WOOD):expectCreateContentArea():expectZoneChangeContent()
    end)

    it("SEQ_040: the Quiver's Hold, and Keelty's story", function()
        local w = walkthrough.start("Arc306", 40)

        w:stateChange(40):expectEnpc(KEELTY_GUILD, QFLAG_PUSH)
        w:expectMarkers(11016204)
        w:talk(NONOLATO):expectDelegate("processEvent040_8"):ack()
        w:talk(ODHINEK):expectDelegate("processEvent040_5"):ack()
        w:push(KEELTY_GUILD):expectDelegate("processEvent040"):ack():expectStartSequence(50)
    end)

    it("SEQ_050: Nonolato's payment", function()
        local w = walkthrough.start("Arc306", 50)

        w:stateChange(50):expectEnpc(NONOLATO, QFLAG_REWARD)
        w:expectMarkers(11016205)
        w:talk(NONOLATO):expectDelegate("processEvent050"):ack()
            :expectDelegate("sqrwa"):ack()
            :expectGil(36000)
            :expectCompleted(110162)
    end)
end)
