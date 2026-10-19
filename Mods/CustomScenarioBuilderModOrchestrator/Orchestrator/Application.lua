require("Utilities");

CustomScenarioBuilderModOrchestratorApplication = {};

---@class PlaceholderPlacementSetting # One configured start-of-game placement, from Mod.Settings.PlaceholderPlacements
---@field Type string | nil # One of PLACEMENT_TYPE_OPTIONS's keys. Missing/nil means DEFAULT_PLACEMENT_TYPE
---@field TerritoryName string # Matched case-insensitively against the map's territory names
---@field PlacementName string | nil
---@field StructureID string | nil # Type=Structure only. Full raw struct id for a modded structure. nil means vanilla
---@field SpecialUnitFields table<string, string> | nil # Type=SpecialUnit only. Every CustomSpecialUnitClass field, stringified

---@class CustomScenarioBuilderModOrchestratorPublicGameData # State PlacePlaceholders sets server-side for Client_GameRefresh to read
---@field PlacementWarnings string[] | nil # Configured TerritoryNames that couldn't be found on the map
---@field NotUsingCustomScenario boolean | nil # True if Placeholder Placement is configured but settings.CustomScenario is nil, so nothing can be placed
---@field NoSpareSlotForNeutralPlacements boolean | nil # True if a neutral territory needed a Slot but every slot up to MAX_KNOWN_VALID_SLOT is in use

---@class CustomScenarioBuilderModOrchestratorPlayerGameData # Per-player "already warned about this" flags, set via Server_GameCustomMessage once Client_GameRefresh has shown each warning once
---@field SeenPlacementWarnings boolean | nil
---@field SeenNotCustomScenarioWarning boolean | nil
---@field SeenUnreplacedPlaceholdersWarning boolean | nil
---@field SeenPlanningModeWarning boolean | nil
---@field SeenNoSpareSlotWarning boolean | nil

---Builds a Placeholder custom special unit: a stand-in for a structure or special unit from another mod.
---@param ownerID PlayerID
---@param placementType string # One of PLACEMENT_TYPE_OPTIONS's keys
---@param placementName string | nil
---@param specialUnitFields table<string, string> | nil # Type=SpecialUnit only - every relevant stored CustomSpecialUnitClass field value
---@param structureID string | nil # Type=Structure only - the raw struct id, nil for a vanilla structure
---@return CustomSpecialUnit
function CustomScenarioBuilderModOrchestratorApplication.BuildPlaceholder(ownerID, placementType, placementName, specialUnitFields, structureID)
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
    builder.ModData = EncodePlaceholderModData(placementType, placementName, structureID);
    if (placementName ~= nil and placementName ~= "") then
        builder.TextOverHeadOpt = string.sub(placementName, 1, 8);
    end

    -- ModData is reserved for the Type/PlacementName/StructureID encoding, not the player's data. ModID isn't
    -- actually writable on the builder despite being a documented CustomSpecialUnitClass field.
    if (specialUnitFields ~= nil) then
        for _, descriptor in ipairs(SPECIAL_UNIT_FIELD_DESCRIPTORS) do
            local value = specialUnitFields[descriptor.Key];
            if (value ~= nil and descriptor.Key ~= "ModData" and descriptor.Key ~= "ModID") then
                if (descriptor.Type == "boolean") then
                    builder[descriptor.Key] = (value == "true");
                elseif (descriptor.Type == "integer" or descriptor.Type == "number") then
                    local number = tonumber(value);
                    if (number ~= nil) then builder[descriptor.Key] = number; end
                else
                    builder[descriptor.Key] = value;
                end
            end
        end
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
                placement.PlacementName,
                placement.SpecialUnitFields,
                placement.StructureID);

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

---Resolves a Placeholder configured for a Structure into the real structure it stands in for -
---a vanilla one matched by name against VANILLA_STRUCTURE_TYPES or a modded one "c|<ModID>|<Name>"
---@param game GameServerHook
---@param standing GameStanding
function CustomScenarioBuilderModOrchestratorApplication.ResolveStructurePlaceholders(game, standing)
    for _, territoryStanding in pairs(standing.Territories) do
        -- re-read fresh each iteration: resolving a Placeholder below reassigns territoryStanding.NumArmies
        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.Name == PLACEHOLDER_NAME) then
                local placementType, placementName, structureID = DecodePlaceholderModData(specialUnit.ModData);

                local resolvedStructureType = nil;
                if (placementType == "Structure") then
                    if (structureID ~= nil) then
                        resolvedStructureType = structureID;
                    elseif (placementName ~= nil) then
                        local enumField = GetVanillaStructureEnumField(placementName);
                        if (enumField ~= nil) then
                            resolvedStructureType = WL.StructureType[enumField];
                        end
                    end
                end

                if (resolvedStructureType ~= nil) then
                    local remainingSpecialUnits = {};
                    for _, otherSpecialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
                        if (otherSpecialUnit.ID ~= specialUnit.ID) then
                            table.insert(remainingSpecialUnits, otherSpecialUnit);
                        end
                    end
                    territoryStanding.NumArmies = WL.Armies.Create(territoryStanding.NumArmies.NumArmies, remainingSpecialUnits);

                    local structures = {};
                    for existingStructureID, count in pairs(territoryStanding.Structures or {}) do
                        structures[existingStructureID] = count;
                    end
                    structures[resolvedStructureType] = (structures[resolvedStructureType] or 0) + 1;
                    territoryStanding.Structures = structures;
                end
            end
        end
    end
end

---Resolves a Placeholder configured for a SpecialUnit we explicitly support (because the mod no longer receives updates)
---@param game GameServerHook
---@param standing GameStanding
function CustomScenarioBuilderModOrchestratorApplication.ResolveBuiltInSpecialUnitPlaceholders(game, standing)
    for _, territoryStanding in pairs(standing.Territories) do
        -- re-read fresh each iteration: resolving a Placeholder below reassigns territoryStanding.NumArmies
        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.Name == PLACEHOLDER_NAME) then
                local placementType, placementName = DecodePlaceholderModData(specialUnit.ModData);
                local builtInUnit = (placementType == "SpecialUnit") and BuiltInSupport.Find(placementName) or nil;

                if (builtInUnit ~= nil) then
                    local remainingSpecialUnits = {};
                    for _, otherSpecialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
                        if (otherSpecialUnit.ID ~= specialUnit.ID) then
                            table.insert(remainingSpecialUnits, otherSpecialUnit);
                        end
                    end

                    local newUnit = builtInUnit.Build(territoryStanding.OwnerPlayerID);
                    table.insert(remainingSpecialUnits, newUnit);

                    territoryStanding.NumArmies = WL.Armies.Create(territoryStanding.NumArmies.NumArmies, remainingSpecialUnits);
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

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param territoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or the raw struct id
function CustomScenarioBuilderModOrchestratorApplication.RemoveStructure(game, addNewOrder, playerID, territoryID, structureName)
    local territoryDetails = game.Map.Territories[territoryID];
    if (territoryDetails == nil) then return; end

    local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
    if (territory == nil or territory.Structures == nil) then return; end

    local enumField = GetVanillaStructureEnumField(structureName);
    local structures = {};
    local matchedKey = nil;
    for key, count in pairs(territory.Structures) do
        structures[key] = count;
        if ((enumField ~= nil and key == WL.StructureType[enumField]) or (enumField == nil and tostring(key) == structureName)) then
            matchedKey = key;
        end
    end

    if (matchedKey == nil or (structures[matchedKey] or 0) <= 0) then return; end
    structures[matchedKey] = structures[matchedKey] - 1;

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.SetStructuresOpt = structures;

    local event = WL.GameOrderEvent.Create(playerID, "Removed a " .. structureName .. " from " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.Icon = "Destroyed";
    addNewOrder(event);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param territoryID TerritoryID
---@param specialUnitID GUID
function CustomScenarioBuilderModOrchestratorApplication.RemoveSpecialUnit(game, addNewOrder, playerID, territoryID, specialUnitID)
    local territoryDetails = game.Map.Territories[territoryID];
    if (territoryDetails == nil) then return; end

    local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
    local specialUnitName = "special unit";
    for _, specialUnit in ipairs(((territory or {}).NumArmies or {}).SpecialUnits or {}) do
        if (specialUnit.ID == specialUnitID) then
            specialUnitName = specialUnit.Name;
            break;
        end
    end

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.RemoveSpecialUnitsOpt = { specialUnitID };

    local event = WL.GameOrderEvent.Create(playerID, "Removed a " .. specialUnitName .. " from " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.Icon = "Destroyed";
    addNewOrder(event);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param fromTerritoryID TerritoryID
---@param toTerritoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or the raw struct id
function CustomScenarioBuilderModOrchestratorApplication.MoveStructure(game, addNewOrder, playerID, fromTerritoryID, toTerritoryID, structureName)
    local fromDetails = game.Map.Territories[fromTerritoryID];
    local toDetails = game.Map.Territories[toTerritoryID];
    if (fromDetails == nil or toDetails == nil) then return; end

    local territory = game.ServerGame.LatestTurnStanding.Territories[fromTerritoryID];
    if (territory == nil or territory.Structures == nil) then return; end

    local enumField = GetVanillaStructureEnumField(structureName);
    local structures = {};
    local matchedKey = nil;
    for key, count in pairs(territory.Structures) do
        structures[key] = count;
        if ((enumField ~= nil and key == WL.StructureType[enumField]) or (enumField == nil and tostring(key) == structureName)) then
            matchedKey = key;
        end
    end

    if (matchedKey == nil or (structures[matchedKey] or 0) <= 0) then return; end
    structures[matchedKey] = structures[matchedKey] - 1;

    local fromModification = WL.TerritoryModification.Create(fromTerritoryID);
    fromModification.SetStructuresOpt = structures;

    local toModification = WL.TerritoryModification.Create(toTerritoryID);
    toModification.AddStructuresOpt = { [matchedKey] = 1 };

    local event = WL.GameOrderEvent.Create(playerID, "Moved a " .. structureName .. " from " .. fromDetails.Name .. " to " .. toDetails.Name, {}, { fromModification, toModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(toDetails.MiddlePointX, toDetails.MiddlePointY, toDetails.MiddlePointX, toDetails.MiddlePointY);
    event.Icon = "Build";
    addNewOrder(event);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param fromTerritoryID TerritoryID
---@param toTerritoryID TerritoryID
---@param specialUnitID GUID
function CustomScenarioBuilderModOrchestratorApplication.MoveSpecialUnit(game, addNewOrder, playerID, fromTerritoryID, toTerritoryID, specialUnitID)
    local fromDetails = game.Map.Territories[fromTerritoryID];
    local toDetails = game.Map.Territories[toTerritoryID];
    if (fromDetails == nil or toDetails == nil) then return; end

    local territory = game.ServerGame.LatestTurnStanding.Territories[fromTerritoryID];
    local specialUnitObject = nil;
    for _, specialUnit in ipairs(((territory or {}).NumArmies or {}).SpecialUnits or {}) do
        if (specialUnit.ID == specialUnitID) then
            specialUnitObject = specialUnit;
            break;
        end
    end
    if (specialUnitObject == nil) then return; end

    local fromModification = WL.TerritoryModification.Create(fromTerritoryID);
    fromModification.RemoveSpecialUnitsOpt = { specialUnitID };

    local toModification = WL.TerritoryModification.Create(toTerritoryID);
    toModification.AddSpecialUnits = { specialUnitObject };

    local event = WL.GameOrderEvent.Create(playerID, "Moved a " .. specialUnitObject.Name .. " from " .. fromDetails.Name .. " to " .. toDetails.Name, {}, { fromModification, toModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(toDetails.MiddlePointX, toDetails.MiddlePointY, toDetails.MiddlePointX, toDetails.MiddlePointY);
    event.Icon = "Build";
    addNewOrder(event);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param territoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or the raw custom EnumStructureType string ("c|<ModID>|<Name>")
function CustomScenarioBuilderModOrchestratorApplication.CloneStructure(game, addNewOrder, playerID, territoryID, structureName)
    local territoryDetails = game.Map.Territories[territoryID];
    if (territoryDetails == nil) then return; end

    local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
    if (territory == nil or territory.Structures == nil) then return; end

    local enumField = GetVanillaStructureEnumField(structureName);
    local matchedKey = nil;
    for key, _ in pairs(territory.Structures) do
        if ((enumField ~= nil and key == WL.StructureType[enumField]) or (enumField == nil and tostring(key) == structureName)) then
            matchedKey = key;
            break;
        end
    end
    if (matchedKey == nil) then return; end

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.AddStructuresOpt = { [matchedKey] = 1 };

    local event = WL.GameOrderEvent.Create(playerID, "Cloned a " .. structureName .. " on " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.Icon = "Build";
    addNewOrder(event);
end

---Only works for a CustomSpecialUnit - there's no mod API to mint a fresh copy of a vanilla special unit
---(Commander/Boss1-4), so cloning one of those is silently a no-op.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param territoryID TerritoryID
---@param specialUnitID GUID
function CustomScenarioBuilderModOrchestratorApplication.CloneSpecialUnit(game, addNewOrder, playerID, territoryID, specialUnitID)
    local territoryDetails = game.Map.Territories[territoryID];
    if (territoryDetails == nil) then return; end

    local territory = game.ServerGame.LatestTurnStanding.Territories[territoryID];
    local specialUnitObject = nil;
    for _, specialUnit in ipairs(((territory or {}).NumArmies or {}).SpecialUnits or {}) do
        if (specialUnit.ID == specialUnitID) then
            specialUnitObject = specialUnit;
            break;
        end
    end
    if (specialUnitObject == nil or specialUnitObject.proxyType ~= "CustomSpecialUnit") then return; end

    local clonedUnit = WL.CustomSpecialUnitBuilder.CreateCopy(specialUnitObject).Build();

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.AddSpecialUnits = { clonedUnit };

    local event = WL.GameOrderEvent.Create(playerID, "Cloned a " .. specialUnitObject.Name .. " on " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.Icon = "Build";
    addNewOrder(event);
end
