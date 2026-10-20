require("Application.Utilities");
require("Application.PlaceholderModData");

-- Planning Mode in-game order payloads (Build/Delete/Move/Clone)
-- Marks a GameOrderCustom payload as a Planning Mode build request - "<prefix>{"StructureName":"...",
-- "TerritoryID":"..."}" using the same table format as ModData. Lets a game-maker place a vanilla structure
-- directly via the in-game mod menu, without needing the Custom Scenario distribution.
local PLANNING_MODE_PAYLOAD_PREFIX = "CSBMSPlanningBuild~";

---@param structureName string # one of VANILLA_STRUCTURE_TYPES's Name values
---@param territoryID TerritoryID
---@return string
function BuildPlanningPayload(structureName, territoryID)
    return PLANNING_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        StructureName = structureName,
        TerritoryID = tostring(territoryID),
    });
end

---@param payload string | nil
---@return string | nil structureName
---@return TerritoryID | nil territoryID
function ParsePlanningPayload(payload)
    if (type(payload) ~= "string" or string.sub(payload, 1, #PLANNING_MODE_PAYLOAD_PREFIX) ~= PLANNING_MODE_PAYLOAD_PREFIX) then
        return nil, nil;
    end

    local fields = DecodeFlatTable(string.sub(payload, #PLANNING_MODE_PAYLOAD_PREFIX + 1));
    if (fields == nil or fields.StructureName == nil or fields.TerritoryID == nil) then
        return nil, nil;
    end

    return fields.StructureName, tonumber(fields.TerritoryID);
end

-- Marks a GameOrderCustom payload as a Planning Mode delete request - removes one structure/special unit
-- instance already standing on the map, chosen from a PromptFromList of what's currently on the clicked territory.
local DELETE_MODE_PAYLOAD_PREFIX = "CSBMSPlanningDelete~";

---@param territoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or a raw custom EnumStructureType string ("c|<ModID>|<Name>")
---@return string
function BuildDeleteStructurePayload(territoryID, structureName)
    return DELETE_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        Type = "Structure",
        TerritoryID = tostring(territoryID),
        Identifier = structureName,
    });
end

---@param territoryID TerritoryID
---@param specialUnitID GUID
---@return string
function BuildDeleteSpecialUnitPayload(territoryID, specialUnitID)
    return DELETE_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        Type = "SpecialUnit",
        TerritoryID = tostring(territoryID),
        Identifier = specialUnitID,
    });
end

---@param payload string | nil
---@return ("Structure" | "SpecialUnit") | nil type
---@return TerritoryID | nil territoryID
---@return string | nil identifier # StructureName (Structure) or SpecialUnitID (SpecialUnit)
function ParseDeletePayload(payload)
    if (type(payload) ~= "string" or string.sub(payload, 1, #DELETE_MODE_PAYLOAD_PREFIX) ~= DELETE_MODE_PAYLOAD_PREFIX) then
        return nil, nil, nil;
    end

    local fields = DecodeFlatTable(string.sub(payload, #DELETE_MODE_PAYLOAD_PREFIX + 1));
    if (fields == nil) then return nil, nil, nil; end

    local placementType = fields.Type;
    local territoryID = tonumber(fields.TerritoryID);
    local identifier = fields.Identifier;
    if ((placementType ~= "Structure" and placementType ~= "SpecialUnit") or territoryID == nil or type(identifier) ~= "string" or identifier == "") then
        return nil, nil, nil;
    end

    return placementType, territoryID, identifier;
end

-- Marks a GameOrderCustom payload as a Planning Mode move request - relocates one structure/special unit
-- instance already standing on the map from one territory to another, chosen via two territory clicks.
local MOVE_MODE_PAYLOAD_PREFIX = "CSBMSPlanningMove~";

---@param fromTerritoryID TerritoryID
---@param toTerritoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or a raw custom EnumStructureType string ("c|<ModID>|<Name>")
---@return string
function BuildMoveStructurePayload(fromTerritoryID, toTerritoryID, structureName)
    return MOVE_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        Type = "Structure",
        FromTerritoryID = tostring(fromTerritoryID),
        ToTerritoryID = tostring(toTerritoryID),
        Identifier = structureName,
    });
end

---@param fromTerritoryID TerritoryID
---@param toTerritoryID TerritoryID
---@param specialUnitID GUID
---@return string
function BuildMoveSpecialUnitPayload(fromTerritoryID, toTerritoryID, specialUnitID)
    return MOVE_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        Type = "SpecialUnit",
        FromTerritoryID = tostring(fromTerritoryID),
        ToTerritoryID = tostring(toTerritoryID),
        Identifier = specialUnitID,
    });
end

---@param payload string | nil
---@return ("Structure" | "SpecialUnit") | nil type
---@return TerritoryID | nil fromTerritoryID
---@return TerritoryID | nil toTerritoryID
---@return string | nil identifier # StructureName (Structure) or SpecialUnitID (SpecialUnit)
function ParseMovePayload(payload)
    if (type(payload) ~= "string" or string.sub(payload, 1, #MOVE_MODE_PAYLOAD_PREFIX) ~= MOVE_MODE_PAYLOAD_PREFIX) then
        return nil, nil, nil, nil;
    end

    local fields = DecodeFlatTable(string.sub(payload, #MOVE_MODE_PAYLOAD_PREFIX + 1));
    if (fields == nil) then return nil, nil, nil, nil; end

    local placementType = fields.Type;
    local fromTerritoryID = tonumber(fields.FromTerritoryID);
    local toTerritoryID = tonumber(fields.ToTerritoryID);
    local identifier = fields.Identifier;
    if ((placementType ~= "Structure" and placementType ~= "SpecialUnit") or fromTerritoryID == nil or toTerritoryID == nil or type(identifier) ~= "string" or identifier == "") then
        return nil, nil, nil, nil;
    end

    return placementType, fromTerritoryID, toTerritoryID, identifier;
end

-- Marks a GameOrderCustom payload as a Planning Mode clone request - duplicates one structure/special unit
-- instance already standing on the map, adding the copy onto the same territory it's already on.
local CLONE_MODE_PAYLOAD_PREFIX = "CSBMSPlanningClone~";

---@param territoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or a raw custom EnumStructureType string ("c|<ModID>|<Name>")
---@return string
function BuildCloneStructurePayload(territoryID, structureName)
    return CLONE_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        Type = "Structure",
        TerritoryID = tostring(territoryID),
        Identifier = structureName,
    });
end

---@param territoryID TerritoryID
---@param specialUnitID GUID
---@return string
function BuildCloneSpecialUnitPayload(territoryID, specialUnitID)
    return CLONE_MODE_PAYLOAD_PREFIX .. EncodeFlatTable({
        Type = "SpecialUnit",
        TerritoryID = tostring(territoryID),
        Identifier = specialUnitID,
    });
end

---@param payload string | nil
---@return ("Structure" | "SpecialUnit") | nil type
---@return TerritoryID | nil territoryID
---@return string | nil identifier # StructureName (Structure) or SpecialUnitID (SpecialUnit)
function ParseClonePayload(payload)
    if (type(payload) ~= "string" or string.sub(payload, 1, #CLONE_MODE_PAYLOAD_PREFIX) ~= CLONE_MODE_PAYLOAD_PREFIX) then
        return nil, nil, nil;
    end

    local fields = DecodeFlatTable(string.sub(payload, #CLONE_MODE_PAYLOAD_PREFIX + 1));
    if (fields == nil) then return nil, nil, nil; end

    local placementType = fields.Type;
    local territoryID = tonumber(fields.TerritoryID);
    local identifier = fields.Identifier;
    if ((placementType ~= "Structure" and placementType ~= "SpecialUnit") or territoryID == nil or type(identifier) ~= "string" or identifier == "") then
        return nil, nil, nil;
    end

    return placementType, territoryID, identifier;
end
