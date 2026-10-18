---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    -- Nothing to do here any more - a CustomScenarioBuilderModOrchestrator Placeholder configured with Type
    -- "Structure" and Placement Name "Fort" is now resolved into a real Fort by CSBMO itself (see
    -- CustomScenarioBuilder.lua's header). Use CustomScenarioBuilder.FindStructurePlacements if this mod ever
    -- needs to know where its Forts ended up.
end
