require("Utilities");

---@enum PointsOfInterestAction
PointsOfInterestActions = {
    AddPointOfInterest = "AddPointOfInterest",
    RemovePointOfInterest = "RemovePointOfInterest",
};

---Builds a Point of Interest on a territory, exactly as if a player had bought it through the commerce menu.
---@class PointsOfInterestAddPointOfInterestDto
---@field Action "AddPointOfInterest"
---@field Letter string # Required. A single letter A-Z (case-insensitive), mapped to its NATO alphabet structure name, e.g. "b" -> Bravo.
---@field TerritoryID TerritoryID # Required. The territory to build on.

---Removes one Point of Interest instance from a territory, reverting the structure and any FogMod it applied.
---@class PointsOfInterestRemovePointOfInterestDto
---@field Action "RemovePointOfInterest"
---@field TerritoryID TerritoryID # Required. The territory to remove a Point of Interest from.
---@field Letter string | nil # Optional. A single letter A-Z (case-insensitive). If given, only removes the instance with the matching NATO name; otherwise removes whichever Point of Interest is found first on the territory, regardless of name.

PointsOfInterestApplication = {};

---Publishes every NATO letter's custom StructureType ID to PublicGameData for access elsewhere
---@param game GameServerHook
function PointsOfInterestApplication.PublishStructureIDs(game)
    local structureIDs = {};
    for _, name in ipairs(NATO_NAMES) do
        structureIDs[name] = WL.StructureType.Custom(name);
    end

    local pub = Mod.PublicGameData or {} --[[@as PointsOfInterestPublicGameData]];
    pub.StructureIDs = structureIDs;
    Mod.PublicGameData = pub;
end

---@class PointOfInterestInstance # One already-built Point of Interest, tracked so it can later be identified for removal
---@field StructureName string # One of the NATO alphabet names
---@field Visibility string # The visibility key (see VISIBILITY_OPTIONS) that was configured for this structure name at build time
---@field TerritoryID TerritoryID
---@field FogModID GUID | nil # Set if Visibility resolved to a fog level, so the FogMod can be removed again

---@class PointsOfInterestPrivateGameData
---@field PointsOfInterest PointOfInterestInstance[] | nil
---@field InitialPlacementsDone boolean | nil # Set once PlaceInitialPointsOfInterest has run, so it never re-places on a later Server_StartGame
---@field InitialVisibilityApplied boolean | nil # Set once ApplyInitialPointOfInterestVisibility has run, so it never re-applies on a later Server_AdvanceTurn_Start

---@class PointsOfInterestPublicGameData # Mirrors the bits of PrivateGameData that client hooks need to read
---@field PlacementWarnings string[] | nil # Set once by PlaceInitialPointsOfInterest - territory names from Mod.Settings.PoIPlacements that couldn't be found on the map. Read by Client_GameRefresh to alert the player
---@field StructureIDs table<string, EnumStructureType> | nil # NATO name -> WL.StructureType.Custom(name), precomputed in Server_StartGame. WL.StructureType.Custom can only be called from a server hook ("modContext.Token.ModExecuting is null" otherwise) - client code (e.g. Client_PresentMenuUI's map scan) has to read the ID from here instead of calling it directly

---@class PointsOfInterestPlayerGameData # Per-player mod data. Set server-side via Server_GameCustomMessage
---@field SeenPlacementWarnings boolean | nil # Set once Client_GameRefresh has alerted this player about PlacementWarnings, so it only ever alerts them once
---@field SeenPlanningModeWarning boolean | nil # Set once Client_GameRefresh has warned this player that Mod.Settings.IsPlanningMode is still on, so it only ever warns them once

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID # Player who paid for it. Only used to attribute the order, ownership is irrelevant
---@param name string # Must be a valid NATO alphabet name
---@param territoryID TerritoryID # Must be a valid territory on the map, the caller is expected to have validated this
function PointsOfInterestApplication.AddPointOfInterest(game, addNewOrder, playerID, name, territoryID)
    local territoryDetails = game.Map.Territories[territoryID];
    local visibility = GetConfiguredVisibility(name);

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.AddStructuresOpt = { [WL.StructureType.Custom(name)] = 1 };

    local event = WL.GameOrderEvent.Create(playerID, "Built " .. name .. " on " .. territoryDetails.Name, {}, { territoryModification });
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create(name, 8, GetColourIntegerFromHex(GetPoIStateColor(visibility))) };
    event.Icon = "Build";

    -- Visible to every player, since Points of Interest belong to the lobby rather than to a player
    local fogModID = nil;
    local fogLevel = GetStandingFogLevel(visibility);
    if (fogLevel ~= nil) then
        local fogMod = WL.FogMod.Create(name .. " Point of Interest", fogLevel, FOG_MOD_PRIORITY, { territoryID }, nil);
        event.FogModsOpt = { fogMod };
        fogModID = fogMod.ID;
    end

    addNewOrder(event);

    local priv = Mod.PrivateGameData --[[@as PointsOfInterestPrivateGameData]];
    local pointsOfInterest = priv.PointsOfInterest or {};
    table.insert(pointsOfInterest, {
        StructureName = name,
        Visibility = visibility,
        TerritoryID = territoryID,
        FogModID = fogModID,
    });
    priv.PointsOfInterest = pointsOfInterest;
    Mod.PrivateGameData = priv;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param territoryID TerritoryID
---@param name string | nil # If given, only removes an instance with this name
function PointsOfInterestApplication.RemovePointOfInterest(game, addNewOrder, territoryID, name)
    local priv = Mod.PrivateGameData --[[@as PointsOfInterestPrivateGameData]];
    local pointsOfInterest = priv.PointsOfInterest or {};

    local removeIndex = nil;
    for i, poi in ipairs(pointsOfInterest) do
        if (poi.TerritoryID == territoryID and (name == nil or poi.StructureName == name)) then
            removeIndex = i;
            break;
        end
    end
    if (removeIndex == nil) then return; end;

    local removed = table.remove(pointsOfInterest, removeIndex);
    priv.PointsOfInterest = pointsOfInterest;
    Mod.PrivateGameData = priv;

    local territoryModification = WL.TerritoryModification.Create(territoryID);
    territoryModification.AddStructuresOpt = { [WL.StructureType.Custom(removed.StructureName)] = -1 };

    local territoryDetails = game.Map.Territories[territoryID];
    local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, removed.StructureName .. " Point of Interest on " .. territoryDetails.Name .. " was removed", {}, { territoryModification });
    if (removed.FogModID ~= nil) then
        event.RemoveFogModsOpt = { removed.FogModID };
    end
    event.JumpToActionSpotOpt = WL.RectangleVM.Create(territoryDetails.MiddlePointX, territoryDetails.MiddlePointY, territoryDetails.MiddlePointX, territoryDetails.MiddlePointY);
    event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create(removed.StructureName .. " removed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
    event.Icon = "Destroyed";
    addNewOrder(event);
end

---@class PointsOfInterestPlacementSetting # One configured start-of-game placement, from Mod.Settings.PoIPlacements
---@field Name string # A NATO alphabet name, e.g. "Alpha". Only placed if IsPoIEnabled(Name) at game start
---@field TerritoryName string # Matched case-insensitively against the map's territory names at game start - see FindTerritoryIDByName

---@param game GameServerHook
---@param standing GameStanding
function PointsOfInterestApplication.PlaceInitialPointsOfInterest(game, standing)
    local priv = Mod.PrivateGameData --[[@as PointsOfInterestPrivateGameData]];
    if (priv.InitialPlacementsDone) then return; end;

    local pointsOfInterest = priv.PointsOfInterest or {};
    local missingTerritoryNamesByPoi = {}; -- POI name -> territory names that couldn't be found for it

    for _, placement in ipairs(Mod.Settings.PoIPlacements or {}) do
        if (IsNatoName(placement.Name) and IsPoIEnabled(placement.Name)) then
            local territoryID = FindTerritoryIDByName(game, placement.TerritoryName);

            if (territoryID == nil) then -- missing
                local missingForPoi = missingTerritoryNamesByPoi[placement.Name] or {};
                table.insert(missingForPoi, placement.TerritoryName);
                missingTerritoryNamesByPoi[placement.Name] = missingForPoi;
            else -- found
                local territory = standing.Territories[territoryID];
                local structureID = WL.StructureType.Custom(placement.Name);

                local structures = {};
                for key, value in pairs(territory.Structures or {}) do
                    structures[key] = value;
                end
                structures[structureID] = (structures[structureID] or 0) + 1;
                territory.Structures = structures;

                table.insert(pointsOfInterest, {
                    StructureName = placement.Name,
                    Visibility = GetConfiguredVisibility(placement.Name),
                    TerritoryID = territoryID,
                    FogModID = nil, -- filled in by ApplyInitialPointOfInterestVisibility, below, if a fog level applies
                });
            end
        end
    end

    priv.PointsOfInterest = pointsOfInterest;
    priv.InitialPlacementsDone = true;
    Mod.PrivateGameData = priv;

    -- "The following territories could not be found:\nAlpha: alpha1, alpha2, alpha3\nBravo: bravo1, bravo2"
    local warnings = {};
    if (next(missingTerritoryNamesByPoi) ~= nil) then
        table.insert(warnings, "The following territories could not be found:");
        for _, name in ipairs(NATO_NAMES) do
            local missingForPoi = missingTerritoryNamesByPoi[name];
            if (missingForPoi ~= nil) then
                table.insert(warnings, name .. ": " .. table.concat(missingForPoi, ", "));
            end
        end
    end

    local pub = Mod.PublicGameData or {} --[[@as PointsOfInterestPublicGameData]];
    pub.PlacementWarnings = warnings;
    Mod.PublicGameData = pub;
end

---Applies the FogMods for whichever initial placements configured a non-default visibility. Can only properly run once
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function PointsOfInterestApplication.ApplyInitialPointOfInterestVisibility(game, addNewOrder)
    local priv = Mod.PrivateGameData --[[@as PointsOfInterestPrivateGameData]];
    if (priv.InitialVisibilityApplied) then return; end;

    local pointsOfInterest = priv.PointsOfInterest or {};
    local fogMods = {};
    local territoryAnnotations = {};
    for _, poi in ipairs(pointsOfInterest) do
        if (poi.FogModID == nil) then
            local fogLevel = GetStandingFogLevel(poi.Visibility);
            if (fogLevel ~= nil) then
                local fogMod = WL.FogMod.Create(poi.StructureName .. " Point of Interest", fogLevel, FOG_MOD_PRIORITY, { poi.TerritoryID }, nil);
                table.insert(fogMods, fogMod);
                poi.FogModID = fogMod.ID;
                territoryAnnotations[poi.TerritoryID] = WL.TerritoryAnnotation.Create(poi.StructureName, 8, GetColourIntegerFromHex(GetPoIStateColor(poi.Visibility)));
            end
        end
    end

    if (#fogMods > 0) then
        local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "POIs placed", {}, {});
        event.FogModsOpt = fogMods;
        event.TerritoryAnnotationsOpt = territoryAnnotations;
        event.Icon = "Build";
        addNewOrder(event);
    end

    priv.PointsOfInterest = pointsOfInterest;
    priv.InitialVisibilityApplied = true;
    Mod.PrivateGameData = priv;
end
