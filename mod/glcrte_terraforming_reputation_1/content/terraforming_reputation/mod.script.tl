-- Terraforming Costs and Reputation Customization: terraforming costs
-- Divides the cost of the terrain brush (raise and lower, per m^3) by a
-- factor from the mod options, 2x to 100x, or leaves it unchanged (Off).
--
-- The base game sets the prices per m^3 in its preRunFn (base/mod.script.tl):
-- baseConfig.costs.terrainRaise = 4.5 and terrainLower = 5.25, times the
-- difficulty's infrastructure purchase cost scale. Mods' preRunFns run after
-- the base game's, so this one reads the costs, divides the two prices and
-- writes the table back, like the base game assigns it. The prices are read
-- when a game is loaded, so a changed option takes effect after loading.

local MOD_TAG <const> = "[Terraforming Costs and Reputation Customization]"
local COST_PARAM <const> = "glcrte_tfr_cost"

-- mod option "Terraforming cost reduction" (1-based index, as allModParams
-- has it): 1 is Off, 2..11 are the factors
local COST_FACTORS <const> : {number} = { 1, 2, 3, 5, 7, 10, 15, 20, 30, 50, 100 }
local DEFAULT_COST_INDEX <const> = 1

local mod = {}

-- cost divisor for a 1-based option index; out of range is clamped, unknown
-- is Off (1)
local function costFactorForIndex(index : integer) : number
	if index == nil then
		index = DEFAULT_COST_INDEX
	end
	return COST_FACTORS[math.max(1, math.min(#COST_FACTORS, index))]
end

-- the costs with terrainRaise and terrainLower divided by factor; returns
-- false if they are missing
local function reduceCosts(costs : {string : number}, factor : number) : boolean
	if costs == nil or type(costs.terrainRaise) ~= "number" or type(costs.terrainLower) ~= "number" then
		return false
	end
	costs.terrainRaise = costs.terrainRaise / factor
	costs.terrainLower = costs.terrainLower / factor
	return true
end

-- the option's index; the key is unique, so it is found regardless of how
-- params are namespaced
local function optionIndex(allModParams : {string : {string : integer}}, key : string) : integer
	for __, params in pairs(allModParams or {}) do
		local v = params[key] as any
		if type(v) == "number" then
			return math.floor(v as number)
		end
	end
	return nil
end

mod.preRunFn = function(_captureParams : any, _configDict : {{string, string}}, allModParams : {string : {string : integer}}, baseConfig : BaseConfig)
	local factor = costFactorForIndex(optionIndex(allModParams, COST_PARAM))
	if factor <= 1 then
		return
	end
	local costs = baseConfig ~= nil and baseConfig.costs or nil
	if not reduceCosts(costs, factor) then
		print(MOD_TAG .. " error: baseConfig.costs.terrainRaise/terrainLower missing, terraforming costs unchanged")
		return
	end
	baseConfig.costs = costs
	print(string.format("%s terraforming costs divided by %d: raise %.4f, lower %.4f per m^3",
		MOD_TAG, math.floor(factor), baseConfig.costs.terrainRaise, baseConfig.costs.terrainLower))
end

-- exposed for tests
;(mod as {string : any})["rules"] = {
	COST_FACTORS = COST_FACTORS,
	costFactorForIndex = costFactorForIndex,
	reduceCosts = reduceCosts,
	optionIndex = optionIndex,
}

return mod
