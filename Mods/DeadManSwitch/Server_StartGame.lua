require("Application");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local pub = Mod.PublicGameData or {};
    pub.DmsStructureID = WL.StructureType.Custom("Dead Man's Switch");
    Mod.PublicGameData = pub;

    -- A CustomScenarioBuilderModOrchestrator Placeholder configured with Type "Structure" and Placement Name
    -- "Dead Man's Switch" is resolved into a real one by CSBMS itself - see CustomScenarioBuilder.lua's header.
    -- Use CustomScenarioBuilder.FindStructurePlacements if this mod ever needs to know where they ended up.
end
