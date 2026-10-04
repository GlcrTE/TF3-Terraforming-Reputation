-- Tests for the rules of terraforming_reputation.script.tl.
-- Run through tools/check.py, which passes a loader for the compiled mod scripts.

return function(load)
	local r = load("terraforming_reputation/terraforming_reputation.script.tl").rules
	local results = {}

	local function test(name, fn)
		local ok, err = pcall(fn)
		table.insert(results, { name, ok, err and tostring(err) or "" })
	end

	local function near(a, b)
		return math.abs(a - b) < 1e-9
	end

	local function impact()
		return { trees = 0.1, rocks = 0.05, terrainModification = 0.5, demolishedTownBuilding = 0.2, landscaping = -0.3 }
	end

	-- stands in for the base game's calculateProposalImpact: 2M m^3 -> 100%
	local function fakeTownUtil()
		local calls = 0
		local m = {}
		m.calculateProposalImpact = function(stats)
			calls = calls + 1
			local i = impact()
			i.terrainModification = stats.volume * 0.0000005
			return i
		end
		return m, function() return calls end
	end

	test("ten steps from 100x to 2000x, rising", function()
		assert(#r.FACTORS == 10, tostring(#r.FACTORS))
		assert(r.FACTORS[1] == 100 and r.FACTORS[10] == 2000)
		for i = 2, #r.FACTORS do
			assert(r.FACTORS[i] > r.FACTORS[i - 1], "step " .. i)
		end
	end)

	test("option index picks the factor, 1-based, clamped, default 100x", function()
		assert(r.factorForIndex(1) == 100)
		assert(r.factorForIndex(8) == 1000)
		assert(r.factorForIndex(10) == 2000)
		assert(r.factorForIndex(nil) == 100)
		assert(r.factorForIndex(0) == 100)
		assert(r.factorForIndex(99) == 2000)
	end)

	test("only the landscaping penalty is divided", function()
		local i = r.reduceImpact(impact(), 100)
		assert(near(i.terrainModification, 0.005), tostring(i.terrainModification))
		assert(i.trees == 0.1 and i.rocks == 0.05 and i.demolishedTownBuilding == 0.2 and i.landscaping == -0.3)
	end)

	test("a gain from filling in terrain is divided too, never flips sign", function()
		local i = impact()
		i.terrainModification = -0.4
		assert(near(r.reduceImpact(i, 2000).terrainModification, -0.0002))
	end)

	test("a missing impact or factor changes nothing", function()
		assert(r.reduceImpact(nil, 100) == nil)
		assert(near(r.reduceImpact(impact(), nil).terrainModification, 0.5))
		assert(near(r.reduceImpact(impact(), 0).terrainModification, 0.5))
	end)

	test("the wrapper divides the base game's result", function()
		local m = fakeTownUtil()
		assert(r.install(m, function() return 1000 end) == true)
		-- 2M m^3 cost 100% in the base game, 0.1% at 1000x
		assert(near(m.calculateProposalImpact({ volume = 2000000 }).terrainModification, 0.001))
	end)

	test("the option is read on every call", function()
		local m = fakeTownUtil()
		local factor = 100
		r.install(m, function() return factor end)
		assert(near(m.calculateProposalImpact({ volume = 2000000 }).terrainModification, 0.01))
		factor = 2000
		assert(near(m.calculateProposalImpact({ volume = 2000000 }).terrainModification, 0.0005))
	end)

	test("installing twice wraps only once", function()
		local m, calls = fakeTownUtil()
		assert(r.install(m, function() return 100 end) == true)
		assert(r.install(m, function() return 100 end) == false)
		assert(near(m.calculateProposalImpact({ volume = 2000000 }).terrainModification, 0.01), "divided once")
		assert(calls() == 1, "base function called once")
		assert(m[r.ORIGINAL_KEY] ~= nil, "original kept on the module")
	end)

	test("a missing module or function is left alone", function()
		assert(r.install(nil, function() return 100 end) == false)
		assert(r.install({}, function() return 100 end) == false)
	end)

	return results
end
