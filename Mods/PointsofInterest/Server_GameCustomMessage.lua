require("Application");

---Maps a custom message Action to the PointsOfInterestPlayerGameData flag it sets, once handled
local SEEN_FLAG_BY_ACTION = {
    MarkPlacementWarningsSeen = "SeenPlacementWarnings",
    MarkPlanningModeWarningSeen = "SeenPlanningModeWarning",
};

---@param game GameServerHook
---@param playerID PlayerID
---@param payload table
---@param setReturn fun(payload: table)
function Server_GameCustomMessage(game, playerID, payload, setReturn)
    local flag = payload ~= nil and SEEN_FLAG_BY_ACTION[payload.Action];
    if (not flag) then return; end;

    local allPlayerData = Mod.PlayerGameData or {};
    local playerData = allPlayerData[playerID] or {} --[[@as PointsOfInterestPlayerGameData]];
    playerData[flag] = true;
    allPlayerData[playerID] = playerData;
    Mod.PlayerGameData = allPlayerData;
end
