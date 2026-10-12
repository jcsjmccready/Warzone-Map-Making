require("Utilities");

---@param game GameClientHook
function Client_GameRefresh(game)
    if (game.Us == nil) then return; end; -- spectators didn't configure anything, nothing to alert them about

    local playerData = Mod.PlayerGameData --[[@as PointsOfInterestPlayerGameData]];

    local pub = Mod.PublicGameData --[[@as PointsOfInterestPublicGameData]];
    local warnings = pub and pub.PlacementWarnings;
    local showPlacementWarnings = warnings ~= nil and #warnings > 0 and not (playerData ~= nil and playerData.SeenPlacementWarnings);
    local showPlanningModeWarning = Mod.Settings.IsPlanningMode and not (playerData ~= nil and playerData.SeenPlanningModeWarning);

    if (not showPlacementWarnings and not showPlanningModeWarning) then return; end;

    -- UI.Alert only shows the latest call, so both warnings have to go in a single call rather than two separate
    -- ones - otherwise whichever fires second silently replaces the first
    local messageParts = {};
    if (showPlacementWarnings) then
        table.insert(messageParts, table.concat(warnings, "\n"));
    end
    if (showPlanningModeWarning) then
        table.insert(messageParts, "Points of Interest: Planning Mode is enabled. Remember to disable it before starting a real game.");
    end
    UI.Alert(table.concat(messageParts, "\n\n"));

    -- tells the server to remember this player has seen whichever of these applied, so they aren't shown again
    if (showPlacementWarnings) then
        game.SendGameCustomMessage("Points of Interest", { Action = "MarkPlacementWarningsSeen" }, function(_) end);
    end
    if (showPlanningModeWarning) then
        game.SendGameCustomMessage("Points of Interest", { Action = "MarkPlanningModeWarningSeen" }, function(_) end);
    end
end
