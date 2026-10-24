require('CustomScenarioBuilder');
require('Utilities');

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    -- Example usage of FindStructurePlacements: finds every territory with a CustomStructureExample on it,
    -- Due to a race condition wity this hook between any mod and the CustomScenarioBuilder mod, they *may* not actually be replaced yet. But will be.

    -- Simply an example usage that shows the output of TerritoryId -> Count of CustomStructureExample structures on that territory
    local placementsByName = {};
    local structureCountByTerritoryId = CustomScenarioBuilder.FindStructurePlacements(standing, "CustomStructureExample");
    print("CustomStructureExample placements (TerritoryID -> Count):");
    DumpTable(structureCountByTerritoryId);
    for territoryID, count in pairs(structureCountByTerritoryId) do
        placementsByName[game.Map.Territories[territoryID].Name] = count;
    end

    local pub = Mod.PublicGameData or {};
    pub.CustomStructureExamplePlacements = placementsByName;
    Mod.PublicGameData = pub;
end
