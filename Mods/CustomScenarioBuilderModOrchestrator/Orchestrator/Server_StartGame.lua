require("Application");

---Server_StartGame hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    CustomScenarioBuilderModOrchestratorApplication.ResolveStructurePlaceholders(game, standing);

    CustomScenarioBuilderModOrchestratorApplication.ResolveBuiltInSpecialUnitPlaceholders(game, standing);

    -- other mods will do something similar in Server_StartGame but for their own special units
end
