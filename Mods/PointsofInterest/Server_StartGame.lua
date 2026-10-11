require("Application");

---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    PointsOfInterestApplication.PlaceInitialPointsOfInterest(game, standing);
end
