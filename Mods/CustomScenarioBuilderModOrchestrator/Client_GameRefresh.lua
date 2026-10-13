require("Utilities");

---@param game GameClientHook
function Client_GameRefresh(game)
    if (game.Us == nil) then return; end; -- spectators didn't configure anything, nothing to alert them about

    local playerData = Mod.PlayerGameData --[[@as CustomScenarioBuilderModOrchestratorPlayerGameData]];
    local pub = Mod.PublicGameData --[[@as CustomScenarioBuilderModOrchestratorPublicGameData]];

    local warnings = pub and pub.PlacementWarnings;
    local showPlacementWarnings = warnings ~= nil and #warnings > 0 and not (playerData ~= nil and playerData.SeenPlacementWarnings);

    local showNotCustomScenarioWarning = (pub ~= nil and pub.NotUsingCustomScenario == true) and not (playerData ~= nil and playerData.SeenNotCustomScenarioWarning);

    if (not showPlacementWarnings and not showNotCustomScenarioWarning) then return; end;

    -- UI.Alert only shows the latest call, so every warning that applies has to go in a single call rather than
    -- separate ones - otherwise whichever fires second silently replaces the first
    local messageParts = {};
    if (showNotCustomScenarioWarning) then
        table.insert(messageParts, "Custom Scenario Builder (Mod Support): Placeholder Placement is configured, but this game isn't using the Custom Scenario distribution, so nothing will be placed.");
    end
    if (showPlacementWarnings) then
        table.insert(messageParts, "Custom Scenario Builder (Mod Support): the following territories could not be found:\n" .. table.concat(warnings, "\n"));
    end
    UI.Alert(table.concat(messageParts, "\n\n"));

    -- tells the server to remember this player has seen whichever of these applied, so they aren't shown again
    if (showNotCustomScenarioWarning) then
        game.SendGameCustomMessage("Custom Scenario Builder Mod Orchestrator", { Action = "MarkNotCustomScenarioWarningSeen" }, function(_) end);
    end
    if (showPlacementWarnings) then
        game.SendGameCustomMessage("Custom Scenario Builder Mod Orchestrator", { Action = "MarkPlacementWarningsSeen" }, function(_) end);
    end
end
