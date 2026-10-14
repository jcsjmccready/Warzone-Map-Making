require("CustomScenarioBuilder");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    -- Resolves any CustomScenarioBuilderModOrchestrator Placeholder configured with Type "Structure" and Placement
    -- Name "Fort" into a real Fort, so it's there on turn 0. See CustomScenarioBuilder.lua for how this works.
    CustomScenarioBuilder.Register(CustomScenarioBuilder.PlacementType.Structure, "Fort", function(placeholder, territoryStanding)
        local structureID = WL.StructureType.Custom("Fort"); -- matches to StructureImages/Fort.png
        CustomScenarioBuilder.ReplacePlaceholder(placeholder, territoryStanding, { AddStructures = { [structureID] = 1 } });
    end);
    CustomScenarioBuilder.ResolvePlacements(game, standing);
end
