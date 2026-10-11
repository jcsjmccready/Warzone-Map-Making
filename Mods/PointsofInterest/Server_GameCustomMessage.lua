require("Application");

---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table)
function Server_GameCustomMessage(game, playerID, payload, setReturn)
    if (payload == nil or payload.Action ~= "MarkPlacementWarningsSeen") then return; end;

    local allPlayerData = Mod.PlayerGameData or {};
    local playerData = allPlayerData[playerID] or {} --[[@as PointsOfInterestPlayerGameData]];
    playerData.SeenPlacementWarnings = true;
    allPlayerData[playerID] = playerData;
    Mod.PlayerGameData = allPlayerData;
end
