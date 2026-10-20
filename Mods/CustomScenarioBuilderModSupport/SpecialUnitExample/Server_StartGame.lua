require("Utilities");
require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
	-- Resolves any CustomScenarioBuilderModOrchestrator Placeholder configured with Type "Special Unit" and
	-- Placement Name "SpecialUnitExample" into a real SpecialUnitExample, so it's there on turn 0. See
	-- CustomScenarioBuilder.lua for how this works.
	CustomScenarioBuilder.RegisterSpecialUnit("SpecialUnitExample", function(placeholder, territoryStanding)
		-- placeholder comes with all special unit fields filled out per what was exported, these can be mapped onto the real unit.
		local specialUnitExample = BuildSpecialUnitExample(territoryStanding.OwnerPlayerID, placeholder.SpecialUnit);
		CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, { AddSpecialUnits = { specialUnitExample } });
	end);

	-- do one of the above per special unit type this mod wants to resolve, then call the resolver as below to actually do the work

	CustomScenarioBuilder.ResolvePlacements(game, standing);
end
