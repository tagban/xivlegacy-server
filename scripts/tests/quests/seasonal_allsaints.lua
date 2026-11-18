-- All Saints' Wake: "Impish Impositions" (Spl0i2). Quest-hook legs only;
-- the walkthrough player owns no cookies, so a trade is walked down its
-- "not enough cookies" branch (the full trade and the imps' riddles are
-- client-tested).

-- Actor class ids (from scripts/lua/quests/spl/allsaints.lua).
local URSIELLE = 1001789
local MUDEDE   = 1001790
local YVANE    = 1001791

describe("Impish Impositions (Spl0i2)", function()
    it("offer: any of the three guild runners", function()
        local w = walkthrough.start("Spl0i2", 65535)
        w:stateChange(65535):expectEnpc(URSIELLE, QFLAG_TALK)
            :expectEnpc(MUDEDE, QFLAG_TALK):expectEnpc(YVANE, QFLAG_TALK)
        w:talk(URSIELLE):expectDelegate("processEventHWLStart"):answer(1)
        w:talk(MUDEDE):expectDelegate("processEventHWGStart"):answer(2)
        w:talk(YVANE):expectDelegate("processEventHWUStart"):answer(1)
    end)

    it("SEQ_000: trade cookies at a runner", function()
        local w = walkthrough.start("Spl0i2", 0)
        w:stateChange(0):expectEnpc(URSIELLE, QFLAG_REWARD)
            :expectEnpc(MUDEDE, QFLAG_REWARD):expectEnpc(YVANE, QFLAG_REWARD)
        -- left the menu without trading
        w:talk(MUDEDE):expectDelegate("processEventSUMFES001"):answer(3)
        -- picked the Pumpkin Head (3 cookies) and confirmed, with no cookies
        w:talk(YVANE):expectDelegate("processEventSUMFES001"):answer(11)
            :expectDelegate("processEventSUMFES002"):ack()
        w:expectSequence(0)
    end)
end)
