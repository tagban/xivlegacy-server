-- Black Mage job quests: Lalai at the Milvaneth Sacrarium.
--
-- Lalai is actor class 1060035 (display name 1500186, "Lalai"). Class
-- 1060034 is Ququruka (1400197), the mastermind; he never stands at the
-- Sacrarium, so none of these talks may go to him.

local LALAI    = 1060035

describe("Black Mage quests: Lalai (Blm0j2-6)", function()
    it("Blm0j2 offer: Lalai hands down the second prophecy", function()
        local w = walkthrough.start("Blm0j2", 65535)
        w:stateChange(65535):expectEnpc(LALAI, QFLAG_TALK)
        w:talk(LALAI):expectDelegate("processEventLALAIStart"):answer(1)
    end)

    it("Blm0j2 SEQ_000: Lalai repeats the prophecy", function()
        local w = walkthrough.start("Blm0j2", 0)
        w:stateChange(0)
        w:talk(LALAI):expectDelegate("processEvent000_LALAI"):ack()
    end)

    it("Blm0j3 offer: three souls of three races", function()
        local w = walkthrough.start("Blm0j3", 65535)
        w:stateChange(65535):expectEnpc(LALAI, QFLAG_TALK)
        w:talk(LALAI):expectDelegate("processEventLALAIStart"):answer(1)
    end)

    it("Blm0j4 SEQ_000: Lalai's chatter", function()
        local w = walkthrough.start("Blm0j4", 0)
        w:stateChange(0)
        w:talk(LALAI):expectDelegate("processEvent000_LALAI"):ack()
    end)

    it("Blm0j6 SEQ_010: Lalai unmasks Ququruka", function()
        local w = walkthrough.start("Blm0j6", 10)
        w:stateChange(10):expectEnpc(LALAI, QFLAG_TALK)
        w:talk(LALAI):expectDelegate("processEventLalai02"):ack():expectStartSequence(15)
    end)
end)
