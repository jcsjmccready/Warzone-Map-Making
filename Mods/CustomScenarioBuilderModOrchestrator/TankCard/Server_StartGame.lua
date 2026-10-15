require("Utilities");
require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
	-- Resolves any CustomScenarioBuilderModOrchestrator Placeholder configured with Type "Special Unit" and
	-- Placement Name "Tank" into a real Tank, so it's there on turn 0. See CustomScenarioBuilder.lua for how this works.
	CustomScenarioBuilder.Register(CustomScenarioBuilder.PlacementType.SpecialUnit, "Tank", function(placeholder, territoryStanding)
		local tank = BuildTank(WL.PlayerID.Neutral);
		CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, { AddSpecialUnits = { tank } });
	end);
	CustomScenarioBuilder.ResolvePlacements(game, standing);
end
