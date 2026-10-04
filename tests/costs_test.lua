-- Tests for the terraforming cost rules of mod.script.tl.
-- Run through tools/check.py, which passes a loader for the compiled mod scripts.

return function(load)
	local r = load("terraforming_reputation/mod.script.tl").rules
	local results = {}

	local function test(name, fn)
		local ok, err = pcall(fn)
		table.insert(results, { name, ok, err and tostring(err) or "" })
	end

	local function near(a, b)
		return math.abs(a - b) < 1e-9
	end

	test("Off plus ten steps from 2x to 100x, rising", function()
		assert(#r.COST_FACTORS == 11, tostring(#r.COST_FACTORS))
		assert(r.COST_FACTORS[1] == 1, "Off")
		assert(r.COST_FACTORS[2] == 2 and r.COST_FACTORS[11] == 100)
		for i = 2, #r.COST_FACTORS do
			assert(r.COST_FACTORS[i] > r.COST_FACTORS[i - 1], "step " .. i)
		end
	end)

	test("option index picks the factor, 1-based, clamped, default Off", function()
		assert(r.costFactorForIndex(1) == 1)
		assert(r.costFactorForIndex(2) == 2)
		assert(r.costFactorForIndex(6) == 10)
		assert(r.costFactorForIndex(11) == 100)
		assert(r.costFactorForIndex(nil) == 1)
		assert(r.costFactorForIndex(0) == 1)
		assert(r.costFactorForIndex(99) == 100)
	end)

	test("only raise and lower prices are divided", function()
		local costs = { terrainRaise = 4.5, terrainLower = 5.25, tree = 100, bulldozeRefundFactor = 0.75 }
		assert(r.reduceCosts(costs, 10) == true)
		assert(near(costs.terrainRaise, 0.45) and near(costs.terrainLower, 0.525))
		assert(costs.tree == 100 and costs.bulldozeRefundFactor == 0.75)
	end)

	test("missing prices change nothing", function()
		assert(r.reduceCosts(nil, 10) == false)
		local costs = { terrainRaise = 4.5 }
		assert(r.reduceCosts(costs, 10) == false)
		assert(costs.terrainRaise == 4.5)
	end)

	test("the option is found in any mod's params", function()
		assert(r.optionIndex({ [""] = { ["map.size"] = 3 }, glcrte_terraforming_reputation_1 = { glcrte_tfr_cost = 6 } }, "glcrte_tfr_cost") == 6)
		assert(r.optionIndex({ [""] = {} }, "glcrte_tfr_cost") == nil)
		assert(r.optionIndex(nil, "glcrte_tfr_cost") == nil)
	end)

	return results
end
