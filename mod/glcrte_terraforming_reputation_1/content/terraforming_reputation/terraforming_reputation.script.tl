-- Terraforming Costs and Reputation Customization
-- Divides the town reputation loss from landscaping (terrain brush, terrain
-- alignment of constructions, tunnels) by a factor from the mod options,
-- 100x to 2000x. Other reputation losses (trees, rocks, demolished
-- buildings, interrupted connections) stay as in the base game.
--
-- The base game computes a build's reputation impact per town in
-- town_util.calculateProposalImpact (game_mechanics/towns/town_util.tl):
-- 2 million m^3 of moved earth cost 100% reputation, booked as the event
-- "TerrainModification" (shown as "Landscaping"). The towns game script
-- applies it on onPreBuildProposal, and the construction GUI uses the same
-- function for the reputation preview of a build. Both call it through the
-- shared town_util module table, so this script replaces the function in
-- that table with a wrapper that divides impact.terrainModification. The
-- script is loaded in the simulation (update) and in the GUI
-- (guiHandleEvent), so the wrapper is installed in both. A marker on the
-- module keeps it from being wrapped twice.
--
-- Debug mode (mod option): clicking a town (its name sign or one of its
-- buildings) resets its reputation. This sends the base game's own
-- Towns/decreaseReputation event with amount 1 (a positive amount recovers
-- reputation), like the mission script does. A penalty for currently
-- interrupted main connections stays, the base game keeps it as a baseline.

local MOD_TAG <const> = "[Terraforming Costs and Reputation Customization]"
local FACTOR_PARAM <const> = "glcrte_tfr_factor"
local DEBUG_PARAM <const> = "glcrte_tfr_debug"
local TOWN_UTIL_PATH <const> = "/game_mechanics/towns/town_util.tl"
-- key on the town_util module that holds the base game's function
local ORIGINAL_KEY <const> = "glcrte_tfr_originalCalculateProposalImpact"

-- mod option "Reduction" (1-based index, as getModParams returns it)
local FACTORS <const> : {number} = { 100, 150, 200, 300, 400, 500, 750, 1000, 1500, 2000 }
local DEFAULT_FACTOR_INDEX <const> = 1

local record State
end

local record GuiState
end

---------------------------------------------------------------------------
-- Rules (pure, no game API)
---------------------------------------------------------------------------

-- reduction factor for a 1-based option index; out of range is clamped,
-- unknown is the default
local function factorForIndex(index : integer) : number
	if index == nil then
		index = DEFAULT_FACTOR_INDEX
	end
	return FACTORS[math.max(1, math.min(#FACTORS, index))]
end

-- the impact with the landscaping penalty divided by factor
local function reduceImpact(impact : TownProposalImpact, factor : number) : TownProposalImpact
	if impact ~= nil and impact.terrainModification ~= nil and factor ~= nil and factor > 0 then
		impact.terrainModification = impact.terrainModification / factor
	end
	return impact
end

-- Replaces calculateProposalImpact in the town_util module with a wrapper
-- that divides the landscaping penalty by getFactor(). Wraps only once per
-- module, also if this script is loaded again in the same Lua state.
-- Returns true if the wrapper was installed now.
local function install(module : TownUtil, getFactor : function() : number) : boolean
	if module == nil then
		return false
	end
	local fields = module as {string : any}
	if fields[ORIGINAL_KEY] ~= nil then
		return false
	end
	local original = module.calculateProposalImpact
	if original == nil then
		return false
	end
	fields[ORIGINAL_KEY] = original
	module.calculateProposalImpact = function(stats : ProposalStats.TownProposalStats) : TownProposalImpact
		return reduceImpact(original(stats), getFactor())
	end
	return true
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

-- 1-based option index of a mod param; the key is unique, so it is found
-- regardless of how params are namespaced
local function intParam(key : string) : integer
	local ok, params = pcall(api.engine.config.getModParams)
	if not ok or params == nil then
		return nil
	end
	for __, modParams in pairs(params as {string : {string : any}}) do
		local v = modParams[key]
		if type(v) == "number" then
			return math.floor(v as number)
		end
	end
	return nil
end

-- read on every call, so changing the option in a running game takes effect
local function getFactor() : number
	return factorForIndex(intParam(FACTOR_PARAM))
end

local function debugMode() : boolean
	return intParam(DEBUG_PARAM) == 2
end

---------------------------------------------------------------------------
-- Game
---------------------------------------------------------------------------

-- each distinct error is logged once per Lua state
local errorsReported : {string : boolean} = {}

local function reportError(err : any)
	local msg = tostring(err)
	if not errorsReported[msg] then
		errorsReported[msg] = true
		debugPrint(MOD_TAG .. " error: " .. msg)
	end
end

-- true once this Lua state's town_util module has the wrapper
local installedHere = false

local function installInGame()
	if installedHere then
		return
	end
	local ok, err : boolean, any = pcall(function()
		local town_util = ug_require(TOWN_UTIL_PATH) as TownUtil
		installedHere = town_util ~= nil
		if install(town_util, getFactor) then
			debugPrint(string.format("%s landscaping reputation loss divided by %d", MOD_TAG, math.floor(getFactor())))
		end
	end)
	if not ok then
		reportError(err)
	end
end

-- the town of a selected entity: the town itself, a town building, or a
-- construction holding town buildings; -1 if none
local function townOf(entity : Engine.Entity) : Engine.Entity
	if entity == nil or entity < 0 then
		return -1
	end
	if api.engine.getComponent(entity, api.type.ComponentType.TOWN) ~= nil then
		return entity
	end
	local townBuilding = api.engine.getComponent(entity, api.type.ComponentType.TOWN_BUILDING) as Engine.Component.TownBuilding
	if townBuilding ~= nil and townBuilding.town >= 0 then
		return townBuilding.town
	end
	local construction = api.engine.getComponent(entity, api.type.ComponentType.CONSTRUCTION) as Engine.Component.Construction
	if construction ~= nil and construction.townBuildings ~= nil and #construction.townBuildings > 0 then
		local first = api.engine.getComponent(construction.townBuildings[1], api.type.ComponentType.TOWN_BUILDING) as Engine.Component.TownBuilding
		if first ~= nil and first.town >= 0 then
			return first.town
		end
	end
	return -1
end

local function townName(town : Engine.Entity) : string
	local name = api.engine.getComponent(town, api.type.ComponentType.NAME) as Engine.Component.Name
	return name ~= nil and name.name or tostring(town)
end

-- debug mode: resets the reputation of the clicked town
local function onSelect(entity : Engine.Entity)
	if not debugMode() then
		return
	end
	local town = townOf(entity)
	if town < 0 then
		debugPrint(string.format("%s debug: selected entity %s is not a town", MOD_TAG, tostring(entity)))
		return
	end
	api.cmd.sendCommand(api.cmd.makeScriptingSendEventCmd("", "Towns", "decreaseReputation", { townEntity = town, amount = 1.0 }))
	debugPrint(string.format("%s debug: reputation of %s (%d) reset", MOD_TAG, townName(town), town))
end

local script : GameScriptWithGui<State, GuiState> = {}

-- Installs the wrapper in the simulation's Lua states. Not done when the
-- file is loaded: there ug_require resolves the path inside this mod
-- ("glcrte_terraforming_reputation_1::/game_mechanics/...") and fails; in
-- update and the GUI functions it finds the base game's module (seen in-game).
-- GUI events like select reach guiHandleEvent only if the script subscribed
-- to them, like the base game's achievements script does.
function script.update(_userParams : table, state : GameScriptState<State>, _dt : number) : any
	if not state:hasEventSubscriptions() then
		state:subscribeToEvent("select")
	end
	installInGame()
	return nil
end

-- installs the wrapper in the GUI's Lua state, for the reputation preview
function script.guiUpdate(_userParams : table, _state : GameScriptStateReadOnly<State>, _guiState : GameScriptState<GuiState>)
	installInGame()
end

function script.guiHandleEvent(_userParams : table, _state : GameScriptStateReadOnly<State>, _guiState : GameScriptState<GuiState>,
		_src : string, id : string, name : string, param : any) : any
	installInGame()
	if id == "mainView" and name == "select" then
		local ok, err : boolean, any = pcall(onSelect, param as Engine.Entity)
		if not ok then
			reportError(err)
		end
	end
	return nil
end

-- exposed for tests
;(script as any as {string : any})["rules"] = {
	FACTORS = FACTORS,
	ORIGINAL_KEY = ORIGINAL_KEY,
	factorForIndex = factorForIndex,
	reduceImpact = reduceImpact,
	install = install,
}

return script
