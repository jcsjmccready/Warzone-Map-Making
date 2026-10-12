require("Application");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    PointsOfInterestApplication.PublishStructureIDs(game);
    PointsOfInterestApplication.PlaceInitialPointsOfInterest(game, standing);
end
