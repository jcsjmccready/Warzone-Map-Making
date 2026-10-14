require("Utilities");

CustomScenarioBuilderModOrchestratorApplication = {};

---@class PlaceholderPlacementSetting # One configured start-of-game placement, from Mod.Settings.PlaceholderPlacements
---@field Type string | nil # One of PLACEMENT_TYPE_OPTIONS's keys ("Structure" or "SpecialUnit"). Tracking data only, recording what the game-maker eventually wants this placeholder replaced with - every placement is always placed as the same Placeholder special unit, regardless of this value. Missing/nil is treated as DEFAULT_PLACEMENT_TYPE, for settings saved before this field existed
---@field TerritoryName string # Matched case-insensitively against the map's territory names at game creation - see FindTerritoryIDByName
---@field PlacementName string | nil # Optional free-text note so the game-maker can tell placeholders apart until each one is mapped to a real mod structure/special unit

---@class CustomScenarioBuilderModOrchestratorPublicGameData # Mirrors the bits of private state that client hooks need to read
---@field PlacementWarnings string[] | nil # Set once by PlacePlaceholders - territory names from Mod.Settings.PlaceholderPlacements that couldn't be found on the map. Read by Client_GameRefresh to alert the game-maker
---@field NotUsingCustomScenario boolean | nil # Set once by PlacePlaceholders if Placeholder Placement is configured but settings.CustomScenario is nil - the game isn't using the Custom Scenario distribution, so nothing can be placed. Read by Client_GameRefresh to alert the game-maker
---@field VanillaStructureNames table<EnumStructureType, string> | nil # Set once by PublishVanillaStructureNames - WL.StructureType.<field> -> its VANILLA_STRUCTURE_TYPES display name, precomputed since resolving it needs a server hook. Read by Client_PresentMenuUI's Planning Mode map scan, which otherwise has no way to name a structure ID it finds back
---@field NoSpareSlotForNeutralPlacements boolean | nil # Set once by PlacePlaceholders - true if a neutral (non-player-start) territory needed a Slot borrowed/invented for it, but every slot up to MAX_KNOWN_VALID_SLOT is already in use. Read by Client_GameRefresh to alert the game-maker

---@class CustomScenarioBuilderModOrchestratorPlayerGameData # Per-player mod data. Set server-side via Server_GameCustomMessage
---@field SeenPlacementWarnings boolean | nil # Set once Client_GameRefresh has alerted this player about PlacementWarnings, so it only ever alerts them once
---@field SeenNotCustomScenarioWarning boolean | nil # Set once Client_GameRefresh has alerted this player about NotUsingCustomScenario, so it only ever alerts them once
---@field SeenUnreplacedPlaceholdersWarning boolean | nil # Set once Client_GameRefresh has alerted this player about a Placeholder nothing ever resolved, so it only ever alerts them once
---@field SeenPlanningModeWarning boolean | nil # Set once Client_GameRefresh has warned this player that Mod.Settings.IsPlanningMode is still enabled, so it only ever warns them once
---@field SeenNoSpareSlotWarning boolean | nil # Set once Client_GameRefresh has warned this player about NoSpareSlotForNeutralPlacements, so it only ever warns them once

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

    -- Under the "Custom Scenario" distribution mode, the engine ignores a territory's CustomScenario data
    -- entirely unless that territory has a Slot assigned (confirmed by testing: a neutral territory with no
    -- Slot got no structures/special units placed on it at all, while a player-start territory - which already
    -- has a Slot from the normal distribution - worked). Slot has to be an integer, not the letter the client
    -- displays it as ("Found string of (C), expected Integer").
    -- game.Game.Players[*].Slot is unset for everyone this early in the hook lifecycle, so "already claimed" is
    -- read instead from the pre-existing entries in territories itself - a player-start territory already
    -- carries its owner's real Slot from the normal distribution before this function ever touches it.
    -- If every existing slot is already claimed, the next sequential one (one past the highest in use) is
    -- invented and added to scenario.SlotsAvailable - confirmed working even for a slot the game wasn't
    -- originally created with, so game-makers don't need to set up a spare slot themselves. One shared slot is
    -- reused for every neutral territory here, the same way a real player's own Slot ends up on every one of
    -- their several starting territories - one spare slot is enough for any number of neutral placements, not
    -- one per territory.
    local maxSlot = -1;
    for _, slot in ipairs(scenario.SlotsAvailable or {}) do
        if (slot > maxSlot) then maxSlot = slot; end
    end

    local sharedNeutralSlot = maxSlot + 1;
    local slotLimitReached = sharedNeutralSlot > MAX_KNOWN_VALID_SLOT;
    if (not slotLimitReached) then
        table.insert(scenario.SlotsAvailable, sharedNeutralSlot);
    end

    local missingTerritoryNames = {};
    local neutralPlacementsSkipped = false; -- true if a neutral territory needed sharedNeutralSlot but slotLimitReached
    for _, placement in ipairs(Mod.Settings.PlaceholderPlacements or {}) do
        local territoryID = FindTerritoryIDByName(game, placement.TerritoryName);

        if (territoryID == nil) then
            table.insert(missingTerritoryNames, placement.TerritoryName);
        else
            local scenarioTerritory = territories[territoryID]
                or { TerritoryID = territoryID, InitialArmies = 0, SpecialUnits = {} };

            if (scenarioTerritory.Slot == nil) then
                if (slotLimitReached) then
                    neutralPlacementsSkipped = true;
                else
                    scenarioTerritory.Slot = sharedNeutralSlot;
                end
            end

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
    pub.NoSpareSlotForNeutralPlacements = neutralPlacementsSkipped;
    Mod.PublicGameData = pub;
end

---Publishes every vanilla structure's resolved ID, keyed back to its display name, so Client_PresentMenuUI's
---Planning Mode map scan can name a structure ID it finds without needing to resolve WL.StructureType fields
---itself client-side.
---@param game GameServerHook
function CustomScenarioBuilderModOrchestratorApplication.PublishVanillaStructureNames(game)
    local names = {};
    for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
        local structureID = WL.StructureType[entry.EnumField];
        names[structureID] = entry.Name;
    end

    local pub = Mod.PublicGameData or {} --[[@as CustomScenarioBuilderModOrchestratorPublicGameData]];
    pub.VanillaStructureNames = names;
    Mod.PublicGameData = pub;
end

---@param game GameServerHook
---@param standing GameStanding
function CustomScenarioBuilderModOrchestratorApplication.ResolveVanillaStructurePlaceholders(game, standing)
    for _, territoryStanding in pairs(standing.Territories) do
        -- territoryStanding.NumArmies.SpecialUnits is read fresh on every iteration (rather than cached once
        -- before the loop) since resolving a Placeholder below reassigns territoryStanding.NumArmies - any earlier
        -- Placeholder resolved on this same territory must not be seen again
        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.Name == PLACEHOLDER_NAME) then
                local placementType, placementName = DecodePlaceholderModData(specialUnit.ModData);
                local enumField = (placementType == "Structure" and placementName ~= nil) and GetVanillaStructureEnumField(placementName) or nil;
                if (enumField ~= nil) then
                    local remainingSpecialUnits = {};
                    for _, otherSpecialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
                        if (otherSpecialUnit.ID ~= specialUnit.ID) then
                            table.insert(remainingSpecialUnits, otherSpecialUnit);
                        end
                    end
                    territoryStanding.NumArmies = WL.Armies.Create(territoryStanding.NumArmies.NumArmies, remainingSpecialUnits);

                    local structures = {};
                    for structureID, count in pairs(territoryStanding.Structures or {}) do
                        structures[structureID] = count;
                    end
                    local structureID = WL.StructureType[enumField];
                    structures[structureID] = (structures[structureID] or 0) + 1;
                    territoryStanding.Structures = structures;
                end
            end
        end
    end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param structureName string # one of VANILLA_STRUCTURE_TYPES's Name values
---@param territoryID TerritoryID
function CustomScenarioBuilderModOrchestratorApplication.AddVanillaStructure(game, addNewOrder, playerID, structureName, territoryID)
    local enumField = GetVanillaStructureEnumField(structureName);
    if (enumField == nil) then return; end

    local territoryDetails = game.Map.Territories[territoryID];
    if (territoryDetails == nil) then return; end

    local structureID = WL.StructureType[enumField];

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.AddStructuresOpt = { [structureID] = 1 };

    local event = WL.GameOrderEvent.Create(playerID, "Placed a " .. structureName .. " on " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create(structureName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
    event.Icon = "Build";
    addNewOrder(event);
end
