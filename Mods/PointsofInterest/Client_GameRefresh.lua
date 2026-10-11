require("Utilities");

---@param game GameClientHook
function Client_GameRefresh(game)

    -- alert the player if we couldn't place a POI

    if (game.Us == nil) then return; end; -- spectators didn't configure anything, nothing to alert them about

    local pub = Mod.PublicGameData --[[@as PointsOfInterestPublicGameData]];
    local warnings = pub and pub.PlacementWarnings;
    if (warnings == nil or #warnings == 0) then return; end;

    local playerData = Mod.PlayerGameData --[[@as PointsOfInterestPlayerGameData]];
    if (playerData ~= nil and playerData.SeenPlacementWarnings) then return; end;

    UI.Alert(table.concat(warnings, "\n"));

    -- tells the server to remember this player has seen the warnings, so Client_GameRefresh won't alert them again
    game.SendGameCustomMessage("Points of Interest", { Action = "MarkPlacementWarningsSeen" }, function(_) end);
end
