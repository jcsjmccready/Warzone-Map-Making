require("Application");
require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    -- picks up any CustomScenarioBuilderModOrchestrator Placeholders meant for this mod, so they're there on turn 0
    CustomScenarioBuilder.Register(CustomScenarioBuilder.PlacementType.SpecialUnit, "Tank", TankCardApplication.ResolveCustomScenarioBuilderPlaceholder);
    CustomScenarioBuilder.ResolvePlacements(game, standing);
end
