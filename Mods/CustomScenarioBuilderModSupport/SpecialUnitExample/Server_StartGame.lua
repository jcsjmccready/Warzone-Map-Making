require("Utilities");
require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
	-- Resolves any CustomScenarioBuilderModOrchestrator Placeholder configured with Type "Special Unit" and
	-- Placement Name "SpecialUnitExample" into a real SpecialUnitExample, so it's there on turn 0. See
	-- CustomScenarioBuilder.lua for how this works.
	CustomScenarioBuilder.Register("SpecialUnitExample", function(placeholder, territoryStanding)
		-- Owned by Neutral, a SpecialUnitExample placed this way couldn't be moved by anyone - match the normal
		-- card-play flow (Server_AdvanceTurn.lua's BuildSpecialUnitExamples) and own it by whichever player
		-- actually controls the territory. placeholder.SpecialUnit is passed through too, to demonstrate that
		-- the Placeholder already carries every field needed to build its own replacement.
		local specialUnitExample = BuildSpecialUnitExample(territoryStanding.OwnerPlayerID, placeholder.SpecialUnit);
		CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, { AddSpecialUnits = { specialUnitExample } });
	end);
	CustomScenarioBuilder.ResolvePlacements(game, standing);
end
