require("Utilities");

CustomScenarioBuilderModOrchestratorApplication = {};

---@class PlaceholderPlacementSetting # One configured start-of-game placement, from Mod.Settings.PlaceholderPlacements
---@field Type string | nil # One of PLACEMENT_TYPE_OPTIONS's keys. Missing/nil means DEFAULT_PLACEMENT_TYPE
---@field TerritoryName string # Matched case-insensitively against the map's territory names - see FindTerritoryIDByName
---@field PlacementName string | nil
---@field StructureID string | nil # Type=Structure only. Full raw EnumStructureType ("c|<ModID>|<Name>") for a modded structure. nil means vanilla - PlacementName is then matched against VANILLA_STRUCTURE_TYPES
---@field SpecialUnitFields table<string, string> | nil # Type=SpecialUnit only. Every CustomSpecialUnitClass field, stringified

---@class CustomScenarioBuilderModOrchestratorPublicGameData # State PlacePlaceholders/PublishVanillaStructureNames set server-side for Client_GameRefresh/Client_PresentMenuUI to read
---@field PlacementWarnings string[] | nil # Configured TerritoryNames that couldn't be found on the map
---@field NotUsingCustomScenario boolean | nil # True if Placeholder Placement is configured but settings.CustomScenario is nil, so nothing can be placed
---@field VanillaStructureNames table<EnumStructureType, string> | nil # WL.StructureType.<field> -> its VANILLA_STRUCTURE_TYPES display name, precomputed since resolving it needs a server hook
---@field NoSpareSlotForNeutralPlacements boolean | nil # True if a neutral territory needed a Slot but every slot up to MAX_KNOWN_VALID_SLOT is in use

---@class CustomScenarioBuilderModOrchestratorPlayerGameData # Per-player "already warned about this" flags, set via Server_GameCustomMessage once Client_GameRefresh has shown each warning once
---@field SeenPlacementWarnings boolean | nil
---@field SeenNotCustomScenarioWarning boolean | nil
---@field SeenUnreplacedPlaceholdersWarning boolean | nil
---@field SeenPlanningModeWarning boolean | nil
---@field SeenNoSpareSlotWarning boolean | nil

---Builds a Placeholder custom special unit: a stand-in for a structure or special unit from another mod.
---Type/PlacementName are encoded into ModData rather than keyed by the unit's ID, since cloning a special unit
---(e.g. during an attack) keeps its ModData but gives the clone a new ID.
---@param ownerID PlayerID
---@param placementType string # One of PLACEMENT_TYPE_OPTIONS's keys
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

    -- A territory's CustomScenario data is silently ignored unless it has a Slot, so a neutral territory (one
    -- with no Slot of its own) borrows one shared invented Slot - the next integer past the highest one already
    -- in scenario.SlotsAvailable.
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
    local neutralPlacementsSkipped = false;
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
        -- re-read fresh each iteration: resolving a Placeholder below reassigns territoryStanding.NumArmies
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
