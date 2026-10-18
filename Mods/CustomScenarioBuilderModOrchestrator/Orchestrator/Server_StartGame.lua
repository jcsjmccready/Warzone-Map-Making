require("Application");

---Server_StartGame hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    -- Resolving WL.StructureType fields needs a server hook, so this is where Planning Mode's vanilla structure
    -- names get published for Client_PresentMenuUI's map scan to read instead of resolving them itself.
    CustomScenarioBuilderModOrchestratorApplication.PublishVanillaStructureNames(game);

    -- A Placeholder configured for a Structure - vanilla (e.g. "City") or modded (recreated from its stored
    -- StructureID) - has no other mod registered to claim it, so CSBMO resolves it into the real structure itself.
    CustomScenarioBuilderModOrchestratorApplication.ResolveStructurePlaceholders(game, standing);
end
