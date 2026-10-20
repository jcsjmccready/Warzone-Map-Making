require("Utilities");
require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
	-- Resolves any CustomScenarioBuilderModOrchestrator Placeholder configured with Type "Special Unit" and
	-- Placement Name "Tank" into a real Tank, so it's there on turn 0. See CustomScenarioBuilder.lua for how this works.
	CustomScenarioBuilder.Register("Tank", function(placeholder, territoryStanding)
		-- Owned by Neutral, a Tank placed this way couldn't be moved by anyone - match the normal card-play
		-- flow (Server_AdvanceTurn.lua's BuildTanks) and own it by whichever player actually controls the territory
		local tank = BuildTank(territoryStanding.OwnerPlayerID);
		CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, { AddSpecialUnits = { tank } });
	end);
	CustomScenarioBuilder.ResolvePlacements(game, standing);
end
