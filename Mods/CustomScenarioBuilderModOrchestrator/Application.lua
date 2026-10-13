require("Utilities");

CustomScenarioBuilderModOrchestratorApplication = {};

---@class PlaceholderPlacementSetting # One configured start-of-game placement, from Mod.Settings.PlaceholderPlacements
---@field Type string | nil # One of PLACEMENT_TYPE_OPTIONS's keys ("Structure" or "SpecialUnit"). Tracking data only, recording what the game-maker eventually wants this placeholder replaced with - every placement is always placed as the same Placeholder special unit, regardless of this value. Missing/nil is treated as DEFAULT_PLACEMENT_TYPE, for settings saved before this field existed
---@field TerritoryName string # Matched case-insensitively against the map's territory names at game creation - see FindTerritoryIDByName
---@field PlacementName string | nil # Optional free-text note so the game-maker can tell placeholders apart until each one is mapped to a real mod structure/special unit

---@class CustomScenarioBuilderModOrchestratorPublicGameData # Mirrors the bits of private state that client hooks need to read
---@field PlacementWarnings string[] | nil # Set once by PlacePlaceholders - territory names from Mod.Settings.PlaceholderPlacements that couldn't be found on the map. Read by Client_GameRefresh to alert the game-maker
---@field NotUsingCustomScenario boolean | nil # Set once by PlacePlaceholders if Placeholder Placement is configured but settings.CustomScenario is nil - the game isn't using the Custom Scenario distribution, so nothing can be placed. Read by Client_GameRefresh to alert the game-maker

---@class CustomScenarioBuilderModOrchestratorPlayerGameData # Per-player mod data. Set server-side via Server_GameCustomMessage
---@field SeenPlacementWarnings boolean | nil # Set once Client_GameRefresh has alerted this player about PlacementWarnings, so it only ever alerts them once
---@field SeenNotCustomScenarioWarning boolean | nil # Set once Client_GameRefresh has alerted this player about NotUsingCustomScenario, so it only ever alerts them once

---Builds a Placeholder custom special unit: a stand-in for a structure or special unit from another mod.
---@param ownerID PlayerID
---@param placementType string # One of PLACEMENT_TYPE_OPTIONS's keys ("Structure" or "SpecialUnit"). Encoded, with placementName, into the unit's own ModData field (see EncodePlaceholderModData) rather than keyed by the unit's ID in one of the Mod storages, since cloning a special unit (e.g. during an attack) keeps its ModData but gives the clone a new ID
---@param placementName string | nil
---@return CustomSpecialUnit
function CustomScenarioBuilderModOrchestratorApplication.BuildPlaceholder(ownerID, placementType, placementName)
    local builder = WL.CustomSpecialUnitBuilder.Create(ownerID);
    builder.Name = PLACEHOLDER_NAME;
    builder.IncludeABeforeName = true;
    builder.ImageFilename = PLACEHOLDER_IMAGE_FILENAME;
    builder.AttackPower = 0;
    builder.DefensePower = 0;
    builder.CombatOrder = 3415;
    builder.DamageToKill = 1;
    builder.DamageAbsorbedWhenAttacked = 0;
    builder.CanBeGiftedWithGiftCard = false;
    builder.CanBeTransferredToTeammate = false;
    builder.CanBeAirliftedToSelf = false;
    builder.CanBeAirliftedToTeammate = false;
    builder.IsVisibleToAllPlayers = true;
    builder.ModData = EncodePlaceholderModData(placementType, placementName);
    if (placementName ~= nil and placementName ~= "") then
        builder.TextOverHeadOpt = string.sub(placementName, 1, 8);
    end
    return builder.Build();
end

---Places every configured Placeholder onto the custom scenario's territories, always as the special unit -
---Type is tracking data only (see PlaceholderPlacementSetting), it doesn't change what gets placed.
---@param game GameServerHook
---@param settings GameSettings
function CustomScenarioBuilderModOrchestratorApplication.PlacePlaceholders(game, settings)
    local scenario = settings.CustomScenario;
    if (scenario == nil) then
        -- mod only works if we're using custom scenario distribution - alert if not
        local pub = Mod.PublicGameData or {} --[[@as CustomScenarioBuilderModOrchestratorPublicGameData]];
        pub.NotUsingCustomScenario = #(Mod.Settings.PlaceholderPlacements or {}) > 0;
        Mod.PublicGameData = pub;
        return;
    end

    -- CustomScenario.Territories is not writable, modify territories in place
    local territories = scenario.Territories;
    local ownerID = WL.PlayerID.Neutral;

    local missingTerritoryNames = {};
    for _, placement in ipairs(Mod.Settings.PlaceholderPlacements or {}) do
        local territoryID = FindTerritoryIDByName(game, placement.TerritoryName);

        if (territoryID == nil) then
            table.insert(missingTerritoryNames, placement.TerritoryName);
        else
            local scenarioTerritory = territories[territoryID]
                or { TerritoryID = territoryID, InitialArmies = 0, SpecialUnits = {} }; -- this should theoretically never happen

            local specialUnit = CustomScenarioBuilderModOrchestratorApplication.BuildPlaceholder(
                ownerID,
                placement.Type or DEFAULT_PLACEMENT_TYPE,
                placement.PlacementName);

            local specialUnits = scenarioTerritory.SpecialUnits or {};
            table.insert(specialUnits, specialUnit);
            scenarioTerritory.SpecialUnits = specialUnits;
            territories[territoryID] = scenarioTerritory;
        end
    end

    settings.CustomScenario = scenario;

    local pub = Mod.PublicGameData or {} --[[@as CustomScenarioBuilderModOrchestratorPublicGameData]];
    pub.PlacementWarnings = missingTerritoryNames;
    Mod.PublicGameData = pub;
end
