require("CommonUtils");
require("BuiltInSupport.BuiltInSupport");

-- General constants
CURRENT_SETTINGS_VERSION = 1;

-- Highest Custom Scenario Slot ("OJ") observed not to throw "InvalidSlot".
MAX_KNOWN_VALID_SLOT = 399;

PLACEHOLDER_NAME = "Placeholder";
PLACEHOLDER_IMAGE_FILENAME = "Placeholder.png";

-- Placement type & UI sizing
--What a placement row's Type dropdown can be set to. Key is what is stored in Mod.Settings.PlaceholderPlacements
PLACEMENT_TYPE_OPTIONS = {
    { Key = "Structure", Text = "Structure" },
    { Key = "SpecialUnit", Text = "Special Unit" },
};
DEFAULT_PLACEMENT_TYPE = "SpecialUnit";

-- Shorter-Text variant of PLACEMENT_TYPE_OPTIONS for the narrow Type dropdown button.
PLACEMENT_TYPE_DROPDOWN_OPTIONS = {
    { Key = "Structure", Text = "Struct" },
    { Key = "SpecialUnit", Text = "Unit" },
};

TYPE_FIELD_WIDTH = 80;
PLACEMENT_NAME_FIELD_WIDTH = 160;
TERRITORY_NAME_FIELD_WIDTH = 200;
ICON_SIZE = 28;
LIST_VIEW_ICON_SIZE = 20;

---@param key string # one of PLACEMENT_TYPE_OPTIONS's keys
---@return string # hex colour string
function GetPlacementTypeColor(key)
    if (key == "Structure") then
        return BUTTON_COLOURS.RoyalBlue;
    elseif (key == "SpecialUnit") then
        return BUTTON_COLOURS.Orchid;
    end
    return BUTTON_COLOURS.DarkGray;
end

-- Placement formatting & sorting
---Formats one placement as "Territory Name: PlacementName [Type]" for display - e.g. in Client_PresentSettingsUI
---and Client_GameRefresh's unreplaced-Placeholder warning.
---@param placement PlaceholderPlacementSetting
---@return string
function FormatPlacementLine(placement)
    local placementType = placement.Type or DEFAULT_PLACEMENT_TYPE;
    return placement.TerritoryName .. ": " .. (placement.PlacementName or "(no Placement Name)") .. " [" .. GetOptionText(PLACEMENT_TYPE_OPTIONS, placementType) .. "]";
end

---Same text as FormatPlacementLine, minus the bracketed "[Structure]"/"[Special Unit]" suffix - for callers that
---show that distinction as an icon instead.
---@param placement PlaceholderPlacementSetting
---@return string
function FormatPlacementText(placement)
    return placement.TerritoryName .. ": " .. (placement.PlacementName or "(no Placement Name)");
end

---Returns a shallow copy of placements sorted alphabetically (case-insensitive) by TerritoryName - the order rows
---were added in the configuration UI isn't a sensible display order.
---@param placements PlaceholderPlacementSetting[]
---@return PlaceholderPlacementSetting[]
function SortPlacementsByTerritoryName(placements)
    local sorted = {};
    for _, placement in ipairs(placements) do
        table.insert(sorted, placement);
    end
    table.sort(sorted, function(a, b) return string.lower(a.TerritoryName) < string.lower(b.TerritoryName); end);
    return sorted;
end

-- ModData encode/decode
-- Quoted-string, "{key:value}" table format, hand-encoded for the Placeholder's ModData field.
---@param s string
---@return string
local function EncodeModDataString(s)
    return "\"" .. string.gsub(string.gsub(s, "\\", "\\\\"), "\"", "\\\"") .. "\"";
end

---@param fields table<string, string>
---@return string
local function EncodeModDataTable(fields)
    local pairsList = {};
    for key, value in pairs(fields) do
        table.insert(pairsList, EncodeModDataString(key) .. ":" .. EncodeModDataString(value));
    end
    return "{" .. table.concat(pairsList, ",") .. "}";
end

---@param placementType string
---@param placementName string | nil
---@param structureID string | nil # Type=Structure only - the raw custom EnumStructureType string ("c|<ModID>|<Name>"), nil for a vanilla structure or a SpecialUnit
---@return string
function EncodePlaceholderModData(placementType, placementName, structureID)
    local fields = { Type = placementType };
    if (placementName ~= nil and placementName ~= "") then
        fields.PlacementName = placementName;
    end
    if (structureID ~= nil and structureID ~= "") then
        fields.StructureID = structureID;
    end
    return EncodeModDataTable(fields);
end

---Reads one quoted, backslash-escaped string starting at s[index] (which must be a quote).
---@param s string
---@param index integer
---@return string | nil value, integer | nil nextIndex # nextIndex is just past the closing quote. Both nil if malformed
local function DecodeModDataString(s, index)
    if (string.sub(s, index, index) ~= "\"") then return nil, nil; end

    local chars = {};
    local escaped = false;
    index = index + 1;
    while (index <= #s) do
        local c = string.sub(s, index, index);
        if (c == "\"" and not escaped) then
            return table.concat(chars), index + 1;
        end
        escaped = (c == "\\") and not escaped;
        table.insert(chars, c);
        index = index + 1;
    end
    return nil, nil; -- ran off the end without a closing quote
end

---Decodes a flat, string-keyed, string-valued table previously produced by EncodePlaceholderModData.
---@param s string
---@return table<string, string> | nil
local function DecodeModDataTable(s)
    if (string.sub(s, 1, 1) ~= "{" or string.sub(s, #s, #s) ~= "}") then return nil; end

    local fields = {};
    local index = 2;
    while (index < #s) do
        local key, afterKey = DecodeModDataString(s, index);
        if (key == nil or string.sub(s, afterKey, afterKey) ~= ":") then return nil; end

        local value, afterValue = DecodeModDataString(s, afterKey + 1);
        if (value == nil) then return nil; end

        fields[key] = value;
        index = afterValue;
        if (string.sub(s, index, index) == ",") then index = index + 1; end
    end
    return fields;
end

---Decodes a Placeholder special unit's own ModData field. Returns nil if modData
---isn't a well-formed encoding.
---@param modData string | nil
---@return string | nil placementType
---@return string | nil placementName
---@return string | nil structureID # Type=Structure only - nil for a vanilla structure or a SpecialUnit
function DecodePlaceholderModData(modData)
    if (type(modData) ~= "string" or modData == "") then return nil, nil, nil; end

    local fields = DecodeModDataTable(modData);
    if (fields == nil) then return nil, nil, nil; end

    return fields.Type, fields.PlacementName, fields.StructureID;
end

-- Planning Mode export/import
-- Planning Mode's export format - one JSON-like line per territory, e.g. {"TerritoryName":"Meowth","Values":[...]}.
---@param value string | table[] # a plain string, or an array of flat string-keyed, string-valued tables
---@return string
local function EncodeExportValue(value)
    if (type(value) == "string") then
        return EncodeModDataString(value);
    end

    local items = {};
    for _, item in ipairs(value) do
        table.insert(items, EncodeModDataTable(item));
    end
    return "[" .. table.concat(items, ",") .. "]";
end

---@param fields table<string, string | table[]>
---@return string
local function EncodeExportObject(fields)
    local pairsList = {};
    for key, value in pairs(fields) do
        table.insert(pairsList, EncodeModDataString(key) .. ":" .. EncodeExportValue(value));
    end
    return "{" .. table.concat(pairsList, ",") .. "}";
end

local DecodeExportValueAt, DecodeExportObjectAt, DecodeExportArrayAt; -- forward declared, these mutually recurse

---@param s string
---@param index integer
---@return string | table[] | nil value, integer | nil nextIndex
function DecodeExportValueAt(s, index)
    local c = string.sub(s, index, index);
    if (c == "\"") then return DecodeModDataString(s, index); end
    if (c == "[") then return DecodeExportArrayAt(s, index); end
    return nil, nil;
end

---@param s string
---@param index integer
---@return table<string, string | table[]> | nil value, integer | nil nextIndex
function DecodeExportObjectAt(s, index)
    if (string.sub(s, index, index) ~= "{") then return nil, nil; end
    index = index + 1;

    local fields = {};
    if (string.sub(s, index, index) == "}") then return fields, index + 1; end

    while (true) do
        local key, afterKey = DecodeModDataString(s, index);
        if (key == nil or string.sub(s, afterKey, afterKey) ~= ":") then return nil, nil; end

        local value, afterValue = DecodeExportValueAt(s, afterKey + 1);
        if (value == nil) then return nil, nil; end

        fields[key] = value;
        index = afterValue;
        if (string.sub(s, index, index) == ",") then
            index = index + 1;
        elseif (string.sub(s, index, index) == "}") then
            return fields, index + 1;
        else
            return nil, nil;
        end
    end
end

---@param s string
---@param index integer
---@return table[] | nil value, integer | nil nextIndex
function DecodeExportArrayAt(s, index)
    if (string.sub(s, index, index) ~= "[") then return nil, nil; end
    index = index + 1;

    local items = {};
    if (string.sub(s, index, index) == "]") then return items, index + 1; end

    while (true) do
        local item, afterItem = DecodeExportObjectAt(s, index);
        if (item == nil) then return nil, nil; end

        table.insert(items, item);
        index = afterItem;
        if (string.sub(s, index, index) == ",") then
            index = index + 1;
        elseif (string.sub(s, index, index) == "]") then
            return items, index + 1;
        else
            return nil, nil;
        end
    end
end

---Serializes a list of placements into a pasteable string for Planning Mode - one line per distinct TerritoryName.
---@param placements PlaceholderPlacementSetting[]
---@return string
function SerializePlacementData(placements)
    local order = {}; -- TerritoryName, in first-seen order
    local byTerritory = {}; -- TerritoryName -> { Type: "S" | "U", Name: string }[]
    for _, placement in ipairs(placements) do
        local group = byTerritory[placement.TerritoryName];
        if (group == nil) then
            group = {};
            byTerritory[placement.TerritoryName] = group;
            table.insert(order, placement.TerritoryName);
        end

        local placementType = placement.Type or DEFAULT_PLACEMENT_TYPE;
        local valueEntry = { Type = (placementType == "Structure") and "S" or "U", Name = placement.PlacementName or "" };
        for key, value in pairs(placement.SpecialUnitFields or {}) do
            valueEntry[key] = value;
        end
        table.insert(group, valueEntry);
    end

    local lines = {};
    for _, territoryName in ipairs(order) do
        table.insert(lines, EncodeExportObject({ TerritoryName = territoryName, Values = byTerritory[territoryName] }));
    end
    return table.concat(lines, "\n");
end

---Parses a raw custom structure EnumStructureType string ("c|<ModID>|<Name>") into its display Name.
---@param structureID string
---@return string | nil
function ParseCustomStructureName(structureID)
    return string.match(structureID, "^c|[^|]*|(.*)$");
end

---Parses a string produced by SerializePlacementData back into a list of placements. Returns nil if any
---non-blank line isn't well-formed.
---@param text string
---@return PlaceholderPlacementSetting[] | nil
function DeserializePlacementData(text)
    local placements = {};
    for _, line in ipairs(SplitLines(text or "")) do
        if (line ~= "") then
            local object, nextIndex = DecodeExportObjectAt(line, 1);
            if (object == nil or nextIndex ~= #line + 1) then return nil; end

            local territoryName = object.TerritoryName;
            local values = object.Values;
            if (type(territoryName) ~= "string" or territoryName == "" or type(values) ~= "table") then return nil; end

            for _, value in ipairs(values) do
                local typeChar = value.Type;
                local name = value.Name;
                if ((typeChar ~= "S" and typeChar ~= "U") or type(name) ~= "string") then return nil; end

                local placementName = name;
                local structureID = nil;
                local specialUnitFields = nil;
                if (typeChar == "S") then
                    local customName = ParseCustomStructureName(name);
                    if (customName ~= nil) then
                        structureID = name;
                        placementName = customName;
                    end
                else
                    specialUnitFields = {};
                    for _, descriptor in ipairs(SPECIAL_UNIT_FIELD_DESCRIPTORS) do
                        local fieldValue = value[descriptor.Key];
                        if (fieldValue ~= nil) then specialUnitFields[descriptor.Key] = tostring(fieldValue); end
                    end
                end

                table.insert(placements, {
                    Type = (typeChar == "S") and "Structure" or "SpecialUnit",
                    TerritoryName = territoryName,
                    PlacementName = (placementName ~= "") and placementName or nil,
                    StructureID = structureID,
                    SpecialUnitFields = specialUnitFields,
                });
            end
        end
    end
    return placements;
end

-- Vanilla structures
-- The vanilla (non-custom) structures, for Planning Mode's placement menu and build orders. EnumField is the
-- WL.StructureType field name.
---@type { Name: string, EnumField: string }[]
VANILLA_STRUCTURE_TYPES = {
    { Name = "Arena", EnumField = "Arena" },
    { Name = "Army Cache", EnumField = "ArmyCache" },
    { Name = "Army Camp", EnumField = "ArmyCamp" },
    { Name = "Attack", EnumField = "Attack" },
    { Name = "City", EnumField = "City" },
    { Name = "Crafter", EnumField = "Crafter" },
    { Name = "Dig Site", EnumField = "DigSite" },
    { Name = "Draft", EnumField = "Draft" },
    { Name = "Hospital", EnumField = "Hospital" },
    { Name = "Market", EnumField = "Market" },
    { Name = "Mercenary Camp", EnumField = "MercenaryCamp" },
    { Name = "Mine", EnumField = "Mine" },
    { Name = "Money Cache", EnumField = "MoneyCache" },
    { Name = "Mortar", EnumField = "Mortar" },
    { Name = "Power", EnumField = "Power" },
    { Name = "Recipe", EnumField = "Recipe" },
    { Name = "Resource Cache", EnumField = "ResourceCache" },
    { Name = "Smelter", EnumField = "Smelter" },
};

---@param structureName string
---@return string | nil # WL.StructureType's field name, or nil if structureName isn't one of VANILLA_STRUCTURE_TYPES
function GetVanillaStructureEnumField(structureName)
    for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
        if (entry.Name == structureName) then
            return entry.EnumField;
        end
    end
    return nil;
end

---@return table<EnumStructureType, string> # WL.StructureType.<Field> -> its VANILLA_STRUCTURE_TYPES display name
function GetVanillaStructureNames()
    local names = {};
    for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
        names[WL.StructureType[entry.EnumField]] = entry.Name;
    end
    return names;
end

-- Special unit fields
-- Every CustomSpecialUnitClass field the Placement Edit view exposes as its own typed input, driving both that
-- form and (later) resolution logic. ModID/Name/ID excluded - ModID isn't settable, Name is already PlacementName.
---@type { Key: string, Type: "integer"|"number"|"boolean"|"string", Label: string }[]
SPECIAL_UNIT_FIELD_DESCRIPTORS = {
    { Key = "AttackPower", Type = "integer", Label = "Attack Power" },
    { Key = "AttackPowerPercentage", Type = "number", Label = "Attack Power Percentage" },
    { Key = "CanBeAirliftedToSelf", Type = "boolean", Label = "Can Be Airlifted To Self" },
    { Key = "CanBeAirliftedToTeammate", Type = "boolean", Label = "Can Be Airlifted To Teammate" },
    { Key = "CanBeGiftedWithGiftCard", Type = "boolean", Label = "Can Be Gifted With Gift Card" },
    { Key = "CanBeTransferredToTeammate", Type = "boolean", Label = "Can Be Transferred To Teammate" },
    { Key = "CombatOrder", Type = "integer", Label = "Combat Order" },
    { Key = "DamageAbsorbedWhenAttacked", Type = "integer", Label = "Damage Absorbed When Attacked" },
    { Key = "DamageToKill", Type = "integer", Label = "Damage To Kill" },
    { Key = "DefensePower", Type = "integer", Label = "Defense Power" },
    { Key = "DefensePowerPercentage", Type = "integer", Label = "Defense Power Percentage" },
    { Key = "Health", Type = "integer", Label = "Health" },
    { Key = "IncludeABeforeName", Type = "boolean", Label = "Include \"A\" Before Name" },
    { Key = "IsVisibleToAllPlayers", Type = "boolean", Label = "Is Visible To All Players" },
    { Key = "ModData", Type = "string", Label = "Mod Data" },
    { Key = "ModID", Type = "integer", Label = "Mod ID" },
    { Key = "TextOverHeadOpt", Type = "string", Label = "Text Over Head" },
};

-- List view status icons & helpers
-- The Placement list view's status icons - filenames in UIImages. The plain (non-Bg) variant is the
-- placeholder default; swapping to a Bg variant later is a one-line change here.
ICON_STRUCTURE = "Structure.png";
ICON_SPECIAL_UNIT = "SpecialUnit.png";
ICON_VANILLA = "Vanilla.png";
ICON_MODDED = "Modded.png";
ICON_BUILT_IN_SUPPORT = "BuiltInSupport.png";
ICON_EDIT = "Edit.png";
ICON_MOVE = "Move.png";
ICON_COPY = "Copy.png";

---@param placement PlaceholderPlacementSetting
---@return boolean
function IsModdedStructure(placement)
    return placement.Type == "Structure" and placement.StructureID ~= nil;
end

---@param placement PlaceholderPlacementSetting
---@return boolean
function PlacementHasBuiltInSupport(placement)
    if (placement.Type ~= "SpecialUnit") then return false; end
    return BuiltInSupport.Find(placement.PlacementName) ~= nil;
end

-- Planning Mode in-game order payloads (Build/Delete/Move/Clone)
-- Marks a GameOrderCustom payload as a Planning Mode build request - "<prefix>{"StructureName":"...",
-- "TerritoryID":"..."}" using the same table format as ModData. Lets a game-maker place a vanilla structure
-- directly via the in-game mod menu, without needing the Custom Scenario distribution.
local PLANNING_MODE_PAYLOAD_PREFIX = "CSBMOPlanningBuild~";

---@param structureName string # one of VANILLA_STRUCTURE_TYPES's Name values
---@param territoryID TerritoryID
---@return string
function BuildPlanningPayload(structureName, territoryID)
    return PLANNING_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
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

    local fields = DecodeModDataTable(string.sub(payload, #PLANNING_MODE_PAYLOAD_PREFIX + 1));
    if (fields == nil or fields.StructureName == nil or fields.TerritoryID == nil) then
        return nil, nil;
    end

    return fields.StructureName, tonumber(fields.TerritoryID);
end

-- Marks a GameOrderCustom payload as a Planning Mode delete request - removes one structure/special unit
-- instance already standing on the map, chosen from a PromptFromList of what's currently on the clicked territory.
local DELETE_MODE_PAYLOAD_PREFIX = "CSBMOPlanningDelete~";

---@param territoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or a raw custom EnumStructureType string ("c|<ModID>|<Name>")
---@return string
function BuildDeleteStructurePayload(territoryID, structureName)
    return DELETE_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
        Type = "Structure",
        TerritoryID = tostring(territoryID),
        Identifier = structureName,
    });
end

---@param territoryID TerritoryID
---@param specialUnitID GUID
---@return string
function BuildDeleteSpecialUnitPayload(territoryID, specialUnitID)
    return DELETE_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
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

    local fields = DecodeModDataTable(string.sub(payload, #DELETE_MODE_PAYLOAD_PREFIX + 1));
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
local MOVE_MODE_PAYLOAD_PREFIX = "CSBMOPlanningMove~";

---@param fromTerritoryID TerritoryID
---@param toTerritoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or a raw custom EnumStructureType string ("c|<ModID>|<Name>")
---@return string
function BuildMoveStructurePayload(fromTerritoryID, toTerritoryID, structureName)
    return MOVE_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
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
    return MOVE_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
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

    local fields = DecodeModDataTable(string.sub(payload, #MOVE_MODE_PAYLOAD_PREFIX + 1));
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
local CLONE_MODE_PAYLOAD_PREFIX = "CSBMOPlanningClone~";

---@param territoryID TerritoryID
---@param structureName string # a VANILLA_STRUCTURE_TYPES Name, or a raw custom EnumStructureType string ("c|<ModID>|<Name>")
---@return string
function BuildCloneStructurePayload(territoryID, structureName)
    return CLONE_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
        Type = "Structure",
        TerritoryID = tostring(territoryID),
        Identifier = structureName,
    });
end

---@param territoryID TerritoryID
---@param specialUnitID GUID
---@return string
function BuildCloneSpecialUnitPayload(territoryID, specialUnitID)
    return CLONE_MODE_PAYLOAD_PREFIX .. EncodeModDataTable({
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

    local fields = DecodeModDataTable(string.sub(payload, #CLONE_MODE_PAYLOAD_PREFIX + 1));
    if (fields == nil) then return nil, nil, nil; end

    local placementType = fields.Type;
    local territoryID = tonumber(fields.TerritoryID);
    local identifier = fields.Identifier;
    if ((placementType ~= "Structure" and placementType ~= "SpecialUnit") or territoryID == nil or type(identifier) ~= "string" or identifier == "") then
        return nil, nil, nil;
    end

    return placementType, territoryID, identifier;
end