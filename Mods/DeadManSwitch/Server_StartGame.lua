require("Application");
require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local pub = Mod.PublicGameData or {};
    pub.DmsStructureID = WL.StructureType.Custom("Dead Man's Switch");
    Mod.PublicGameData = pub;

    -- picks up any CustomScenarioBuilderModOrchestrator Placeholders meant for this mod, so they're there on turn 0
    CustomScenarioBuilder.Register(CustomScenarioBuilder.PlacementType.Structure, "Dead Man's Switch", DeadManSwitchApplication.ResolveCustomScenarioBuilderPlaceholder);
    CustomScenarioBuilder.ResolvePlacements(game, standing);
end
