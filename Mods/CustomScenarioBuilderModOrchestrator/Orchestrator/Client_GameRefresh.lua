require("Utilities");

--For every configured placement, checks whether its territory still has a Placeholder special unit on it - meaning
--no installed mod ever claimed it via CustomScenarioBuilder.ReplacePlaceholder. IsVisibleToAllPlayers is set on
--every Placeholder (see BuildPlaceholder), so this doesn't need to account for fog.
---@param game GameClientHook
---@return string[] # One "Territory Name: PlacementName [Type]" line per still-unreplaced placement, alphabetical by territory name
local function GetUnreplacedPlacementLines(game)
    local unreplaced = {};
    for _, placement in ipairs(SortPlacementsByTerritoryName(Mod.Settings.PlaceholderPlacements or {})) do
        local territoryID = FindTerritoryIDByName(game, placement.TerritoryName);
        local territoryStanding = territoryID ~= nil and game.LatestStanding.Territories[territoryID];
        if (territoryStanding ~= nil) then
            for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
                if (specialUnit.Name == PLACEHOLDER_NAME) then
                    table.insert(unreplaced, FormatPlacementLine(placement));
                    break;
                end
            end
        end
    end
    return unreplaced;
end

---@param game GameClientHook
function Client_GameRefresh(game)
    if (game.Us == nil) then return; end; -- spectators didn't configure anything, nothing to alert them about

    local playerData = Mod.PlayerGameData --[[@as CustomScenarioBuilderModOrchestratorPlayerGameData]];
    local pub = Mod.PublicGameData --[[@as CustomScenarioBuilderModOrchestratorPublicGameData]];

    local warnings = pub and pub.PlacementWarnings;
    local showPlacementWarnings = warnings ~= nil and #warnings > 0 and not (playerData ~= nil and playerData.SeenPlacementWarnings);

    local showNotCustomScenarioWarning = (pub ~= nil and pub.NotUsingCustomScenario == true) and not (playerData ~= nil and playerData.SeenNotCustomScenarioWarning);

    local unreplacedLines = GetUnreplacedPlacementLines(game);
    local showUnreplacedPlaceholdersWarning = #unreplacedLines > 0 and not (playerData ~= nil and playerData.SeenUnreplacedPlaceholdersWarning);

    if (not showPlacementWarnings and not showNotCustomScenarioWarning and not showUnreplacedPlaceholdersWarning) then return; end;

    -- UI.Alert only shows the latest call, so every warning that applies has to go in a single call rather than
    -- separate ones - otherwise whichever fires second silently replaces the first
    local messageParts = {};
    if (showNotCustomScenarioWarning) then
        table.insert(messageParts, "Custom Scenario Builder (Mod Support): Placeholder Placement is configured, but this game isn't using the Custom Scenario distribution, so nothing will be placed.");
    end
    if (showPlacementWarnings) then
        table.insert(messageParts, "Custom Scenario Builder (Mod Support): the following territories could not be found:\n" .. table.concat(warnings, "\n"));
    end
    if (showUnreplacedPlaceholdersWarning) then
        table.insert(messageParts, "Custom Scenario Builder (Mod Support): the following Placeholders were never replaced by a mod:\n" .. table.concat(unreplacedLines, "\n"));
    end
    UI.Alert(table.concat(messageParts, "\n\n"));

    -- tells the server to remember this player has seen whichever of these applied, so they aren't shown again
    if (showNotCustomScenarioWarning) then
        game.SendGameCustomMessage("Custom Scenario Builder Mod Orchestrator", { Action = "MarkNotCustomScenarioWarningSeen" }, function(_) end);
    end
    if (showPlacementWarnings) then
        game.SendGameCustomMessage("Custom Scenario Builder Mod Orchestrator", { Action = "MarkPlacementWarningsSeen" }, function(_) end);
    end
    if (showUnreplacedPlaceholdersWarning) then
        game.SendGameCustomMessage("Custom Scenario Builder Mod Orchestrator", { Action = "MarkUnreplacedPlaceholdersWarningSeen" }, function(_) end);
    end
end
