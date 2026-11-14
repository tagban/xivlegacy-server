--[[

synthesis.lua: the rules of one 1.0 synthesis (CraftCommand.lua drives the client widgets).

1.23b gives every crafting class three synthesis actions per tool hand (CraftJudge
getAvailableStandardCraftCommand: main hand 22550 + 6 * (classId - 29) .. +2, off hand +3 .. +5)
plus Wait (22506). At 100% progress the widget switches to its finishing phase: Finish (22503)
or Double Down (22504). Bars: progress 0-100, durability ("craftPoint") and quality, both
displayed against a maximum of 1000 by the widget.

What the 1.0 guides and command help text say, and what this file does with it:
  * Standard: best success rate, moderate progress, moderate quality, low durability loss.
  * Rapid: big progress, little quality, more durability loss (patch 1.20 raised it); failures cost more.
  * Careful (Bold): small progress, big quality, the most durability loss; lowest success rate.
  * Wait: no progress, a little durability (more for each wait in a row); gives the glow a chance to settle.
  * The item's glow sets the odds: white is safe, yellow is shaky, red is risky, a rainbow is
    risky but doubles quality gains.
  * Durability at 0 fails the synthesis. Materials were consumed at the start either way.
  * Double Down gambles at 100% for more quality; failure fails the synthesis.
  * Higher quality means a better chance of a high-quality (+1 to +3) result and more EXP.
The exact numbers were never published; the ones below are this server's choice, tuned so an
on-level recipe takes 6-8 steps and usually succeeds with Standard alone.

--]]

Synthesis = {};

SYNTH_ACTION_STANDARD = 0;
SYNTH_ACTION_RAPID = 1;
SYNTH_ACTION_CAREFUL = 2;
SYNTH_ACTION_WAIT = 3;

SYNTH_CMD_QUIT = 22501;
SYNTH_CMD_CANCEL = 22502;
SYNTH_CMD_FINISH = 22503;
SYNTH_CMD_DOUBLE_DOWN = 22504;
SYNTH_CMD_WAIT = 22506;
SYNTH_CMD_TIME_UP = 22507;

GLOW_WHITE = 1;
GLOW_YELLOW = 2;
GLOW_RED = 3;
GLOW_RAINBOW = 4;

-- Per action: base success %, progress on success / failure, durability loss on success /
-- failure (per 100 max durability), quality on success / failure.
local ACTIONS = {
	[SYNTH_ACTION_STANDARD] = {rate = 90, prog = {14, 20}, progFail = {2, 5},
		dur = {5, 7}, durFail = {12, 16}, qual = {25, 35}, qualFail = {3, 6}},
	[SYNTH_ACTION_RAPID] = {rate = 75, prog = {24, 32}, progFail = {4, 8},
		dur = {8, 10}, durFail = {16, 20}, qual = {4, 8}, qualFail = {0, 0}},
	[SYNTH_ACTION_CAREFUL] = {rate = 75, prog = {10, 14}, progFail = {0, 2},
		dur = {7, 9}, durFail = {16, 20}, qual = {50, 70}, qualFail = {8, 12}},
};

local GLOW_RATE = {[GLOW_WHITE] = 0, [GLOW_YELLOW] = -15, [GLOW_RED] = -35, [GLOW_RAINBOW] = -10};
-- Chance (out of 100) of the next glow, by the outcome of the step.
local GLOW_NEXT = {
	success = {{GLOW_WHITE, 65}, {GLOW_YELLOW, 22}, {GLOW_RED, 8}, {GLOW_RAINBOW, 5}},
	failure = {{GLOW_WHITE, 35}, {GLOW_YELLOW, 35}, {GLOW_RED, 25}, {GLOW_RAINBOW, 5}},
	wait = {{GLOW_WHITE, 70}, {GLOW_YELLOW, 18}, {GLOW_RED, 7}, {GLOW_RAINBOW, 5}},
};

-- Recipes this many levels above the crafter can't be attempted.
SYNTH_MAX_LEVEL_GAP = 10;

local function clamp(v, lo, hi)
	if v < lo then return lo; end
	if v > hi then return hi; end
	return v;
end

local function roll(rng, range)
	if range[1] >= range[2] then return range[1]; end
	return rng(range[1], range[2]);
end

-- recipe: {level, facility}; classLevel: the crafter's level; rng(lo, hi): integer roll
-- (math.random by default). hasFacility: whether the crafter has the recommended facility.
function Synthesis.new(recipe, classLevel, rng, hasFacility)
	local level = recipe.level or 1;
	local s = {
		recipeLevel = level,
		gap = level - (classLevel or 1),
		facilityPenalty = ((recipe.facility or 0) ~= 0 and not hasFacility) and 10 or 0,
		rng = rng or math.random,
		maxDurability = 100 + 5 * level,
		progress = 0,
		quality = 0,
		glow = GLOW_WHITE,
		waits = 0,
		steps = 0,
		finished = false,
		failed = false,
	};
	s.durability = s.maxDurability;
	setmetatable(s, {__index = Synthesis});
	return s;
end

-- Success chance (percent) of a synthesis action under the current glow.
function Synthesis:successRate(action)
	local rate = ACTIONS[action].rate + GLOW_RATE[self.glow] - self.facilityPenalty;
	if self.gap > 0 then
		rate = rate - 4 * self.gap;
	else
		rate = rate + math.min(10, -2 * self.gap);
	end
	return clamp(rate, 5, 98);
end

function Synthesis:nextGlow(outcome)
	local r = self.rng(1, 100);
	for _, entry in ipairs(GLOW_NEXT[outcome]) do
		r = r - entry[2];
		if r <= 0 then return entry[1]; end
	end
	return GLOW_WHITE;
end

-- Run one step. Returns a table describing what happened:
-- {success, progress, durability (loss, positive), quality (gain, may be 0), oldGlow, glow}.
function Synthesis:step(action)
	local result = {action = action, oldGlow = self.glow};
	if action == SYNTH_ACTION_WAIT then
		self.waits = self.waits + 1;
		result.success = true;
		result.progress = 0;
		result.quality = 0;
		result.durability = self.waits;
		self.durability = math.max(0, self.durability - result.durability);
		self.glow = self:nextGlow("wait");
	else
		local a = ACTIONS[action];
		self.waits = 0;
		result.success = self.rng(1, 100) <= self:successRate(action);
		local prog, dur, qual;
		if result.success then
			prog, dur, qual = roll(self.rng, a.prog), roll(self.rng, a.dur), roll(self.rng, a.qual);
			if self.glow == GLOW_RAINBOW then qual = qual * 2; end
		else
			prog, dur, qual = roll(self.rng, a.progFail), roll(self.rng, a.durFail), roll(self.rng, a.qualFail);
			if self.glow == GLOW_RED then dur = math.floor(dur * 3 / 2); end
		end
		-- Above-level recipes advance more slowly.
		if self.gap > 0 then prog = math.floor(prog * math.max(40, 100 - 6 * self.gap) / 100); end
		dur = math.ceil(dur * self.maxDurability / 100);
		result.progress = math.min(prog, 100 - self.progress);
		result.durability = math.min(dur, self.durability);
		result.quality = math.min(qual, 1000 - self.quality);
		self.progress = self.progress + result.progress;
		self.durability = self.durability - result.durability;
		self.quality = self.quality + result.quality;
		self.glow = self:nextGlow(result.success and "success" or "failure");
	end
	self.steps = self.steps + 1;
	result.glow = self.glow;
	if self.durability <= 0 then
		self.failed = true;
	elseif self.progress >= 100 then
		self.finished = true;
	end
	return result;
end

-- Time ran out on the action timer: a failed step with no progress or quality.
function Synthesis:timeUp()
	local loss = math.min(self.durability, math.ceil(14 * self.maxDurability / 100));
	self.durability = self.durability - loss;
	self.waits = 0;
	self.steps = self.steps + 1;
	if self.durability <= 0 then self.failed = true; end
	return {success = false, progress = 0, durability = loss, quality = 0, oldGlow = self.glow, glow = self.glow};
end

-- High-quality chance in percent, shown by the widget.
function Synthesis:hqChance()
	return clamp(math.floor(self.quality / 12), 0, 100);
end

-- Double Down at 100%: success raises quality by half, failure fails the synthesis.
function Synthesis:doubleDown()
	local rate = clamp(55 + GLOW_RATE[self.glow] - 3 * math.max(0, self.gap), 10, 85);
	local result = {success = self.rng(1, 100) <= rate, oldGlow = self.glow};
	if result.success then
		result.quality = math.min(math.floor(self.quality / 2) + 20, 1000 - self.quality);
		self.quality = self.quality + result.quality;
	else
		self.failed = true;
		self.finished = false;
	end
	return result;
end

-- Result quality for the finished item: 1 normal, 2-4 high quality +1 to +3.
function Synthesis:rollQuality()
	local hq = self:hqChance();
	if self.rng(1, 100) > hq then return 1; end
	if self.rng(1, 100) > math.floor(hq / 2) then return 2; end
	if self.rng(1, 100) > math.floor(hq / 4) then return 3; end
	return 4;
end

-- Crafter EXP: base by recipe level, scaled by the level gap; a quality bonus on success
-- (returned separately for the "quality gains you N% more experience" message); a quarter on failure.
function Synthesis:experience(success)
	local base = 150 + 30 * self.recipeLevel;
	local mod;
	if self.gap >= 0 then
		mod = 100 + 10 * math.min(self.gap, 5);
	else
		mod = math.max(10, 100 + 10 * self.gap);
	end
	local exp = math.floor(base * mod / 100);
	if not success then return math.floor(exp / 4), 0; end
	local bonus = clamp(math.floor(self.quality / 10), 0, 50);
	return exp, bonus;
end
