---@param game GameServerHook
---@param standing GameStanding
function Server_StartGame(game, standing)
    local priv = Mod.PrivateGameData or {};
    priv.PointsOfInterest = priv.PointsOfInterest or {};
    Mod.PrivateGameData = priv;
end
