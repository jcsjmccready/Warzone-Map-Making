require("Application");

---Server_StartGame hook
---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    -- Resolving WL.StructureType fields needs a server hook, so this is where Planning Mode's vanilla structure
    -- names get published for Client_PresentMenuUI's map scan to read instead of resolving them itself.
    CustomScenarioBuilderModOrchestratorApplication.PublishVanillaStructureNames(game);

    -- A Placeholder configured for a vanilla structure name (e.g. "City") has no other mod registered to claim
    -- it - CSBMO resolves those itself, the same way a consumer mod resolves its own.
    CustomScenarioBuilderModOrchestratorApplication.ResolveVanillaStructurePlaceholders(game, standing);
end
