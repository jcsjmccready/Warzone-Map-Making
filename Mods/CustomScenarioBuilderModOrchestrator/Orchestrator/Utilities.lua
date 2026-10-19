-- Pulls in every mod CSBMO can build a special unit for itself - required here, rather than only from
-- Server_StartGame, so PlacementHasBuiltInSupport is accurate everywhere Utilities is required, including
-- client-side UI icons.
require("BuiltInSupport.BuiltInSupport");

CURRENT_SETTINGS_VERSION = 1;

-- Custom Scenario Slots display as letters (A, B, ... Z, AA, AB, ...), 0-indexed integers underneath (A=0). "OJ"
-- (399) is the highest ever observed in practice, used as the ceiling past which a new Slot risks "InvalidSlot".
MAX_KNOWN_VALID_SLOT = 399;

-- The name (and SpecialUnitImages filename) of this mod's stand-in special unit, placed on configured
-- territories at game creation and later swapped out for the real structure/special unit.
PLACEHOLDER_NAME = "Placeholder";
PLACEHOLDER_IMAGE_FILENAME = "Placeholder.png";

--What a placement row's Type dropdown can be set to. Key is what is stored in Mod.Settings.PlaceholderPlacements
PLACEMENT_TYPE_OPTIONS = {
    { Key = "Structure", Text = "Structure" },
    { Key = "SpecialUnit", Text = "Special Unit" },
};
DEFAULT_PLACEMENT_TYPE = "SpecialUnit";

-- Same options/keys as PLACEMENT_TYPE_OPTIONS, just with shorter Text - used only for the Type dropdown button in
-- Client_PresentConfigureUI, which is too narrow to fit "Special Unit". Everywhere else (settings summary, alerts)
-- keeps using PLACEMENT_TYPE_OPTIONS's full text via FormatPlacementLine.
PLACEMENT_TYPE_DROPDOWN_OPTIONS = {
    { Key = "Structure", Text = "Struct" },
    { Key = "SpecialUnit", Text = "Unit" },
};

TYPE_FIELD_WIDTH = 80;
PLACEMENT_NAME_FIELD_WIDTH = 160;
TERRITORY_NAME_FIELD_WIDTH = 200;
ICON_SIZE = 28; -- the icons are square, so this is applied to both their width and height
LIST_VIEW_ICON_SIZE = 20; -- smaller than ICON_SIZE, used for the status icons in the Placement list view's rows

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

-- Encoded into every placed Placeholder's own ModData field, so any other mod can read what it's standing in for
-- without needing access to this mod's own Settings (Mod.* storages are private per-mod; ModData lives on the
-- unit itself and survives the unit being cloned, e.g. during combat). Uses the same quoted-string, "{key:value}"
-- table format as the IO package's IO.Writer/IO.Reader elsewhere in this codebase, but written out by hand here so
-- neither this mod nor the copy-paste integration file other mods carry to decode it need to carry the IO package.
-- Both sides must stay in sync with this exact format.
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

---@param text string
---@return string[]
local function SplitLines(text)
    local lines = {};
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        table.insert(lines, (string.gsub(line, "\r$", "")));
    end
    return lines;
end

-- Planning Mode's exported data groups placements by territory, one line each, e.g.
-- {"TerritoryName":"Meowth","Values":[{"Type":"S","Name":"Arena"}]} - a separate, slightly more general format
-- (adds array-of-object support) from EncodeModDataTable/DecodeModDataTable, kept apart so ModData's own format,
-- which other mods' CustomScenarioBuilder.lua copies already decode, never changes.

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

---Parses a raw custom structure EnumStructureType string ("c|<ModID>|<Name>") into its display Name. Returns nil
---if structureID isn't in that format (i.e. it's a vanilla structure name instead, which has no StructureID).
---@param structureID string
---@return string | nil
function ParseCustomStructureName(structureID)
    return string.match(structureID, "^c|[^|]*|(.*)$");
end

---Parses a string produced by SerializePlacementData back into a list of placements. Returns nil if any
---non-blank line isn't well-formed. A Structure whose Name is a raw custom EnumStructureType string
---("c|<ModID>|<Name>", as GetPlacementsFromMap exports a modded structure) has its Name split back apart - the
---full string goes into StructureID, and just <Name> into PlacementName - so the Edit view shows the two fields
---the same way it would if the row had been filled in by hand.
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

-- The vanilla (non-custom) structures, for Planning Mode's placement menu and build orders. EnumField is the
-- WL.StructureType field name, resolvable only in a server hook.
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

-- The Placement Placement list view's status icons - filenames in UIImages. The plain (non-Bg) variant is the
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

---@param str string
---@return string
function TrimString(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"));
end


--Finds the TerritoryID of the territory whose name matches territoryName, case-insensitively. Used to resolve the
--free-text territory names stored in Mod.Settings.PlaceholderPlacements against the actual map at game creation
---@param game GameServerHook
---@param territoryName string
---@return TerritoryID | nil
function FindTerritoryIDByName(game, territoryName)
    local normalized = string.lower(TrimString(territoryName or ""));
    if (normalized == "") then return nil; end

    for territoryID, territoryDetails in pairs(game.Map.Territories) do
        if (string.lower(territoryDetails.Name) == normalized) then
            return territoryID;
        end
    end
    return nil;
end

--Creates a dropdown-style control (Warzone has no native dropdown): a button showing the current choice which
--opens a list prompt when clicked.
---@param parent UIObject
---@param options { Key: string, Text: string }[]
---@param initialKey string
---@param onChanged fun(key: string) | nil
---@return { GetKey: fun(): string, SetKey: fun(key: string), Button: Button }
function CreateDropDown(parent, options, initialKey, onChanged)
    local selectedKey = initialKey;
    local button; -- forward declared, ApplySelection below needs to close over it before it's created

    ---Only fires onChanged for a real user selection (triggerOnChanged), not for a programmatic SetKey call
    ---@param key string
    ---@param triggerOnChanged boolean
    local function ApplySelection(key, triggerOnChanged)
        selectedKey = key;
        button.SetText(GetOptionText(options, key));
        if (triggerOnChanged and onChanged ~= nil) then
            onChanged(key);
        end
    end

    button = UI.CreateButton(parent).SetText(GetOptionText(options, selectedKey));
    button.SetOnClick(function()
        local list = {};
        for _, option in ipairs(options) do
            table.insert(list, {
                text = option.Text,
                selected = function() ApplySelection(option.Key, true); end,
            });
        end
        UI.PromptFromList("Select an option", list);
    end);

    return {
        GetKey = function() return selectedKey; end,
        SetKey = function(key) ApplySelection(key, false); end,
        Button = button,
    };
end

---@param options { Key: string, Text: string }[]
---@param key string
---@return string
function GetOptionText(options, key)
    for _, option in ipairs(options) do
        if (option.Key == key) then
            return option.Text;
        end
    end
    return key;
end

function GetButtonColors()
    return {
        Blue = "#0000FF";
        Purple = "#59009D";
        Orange = "#FF7D00";
        DarkGray = "#606060";
        HotPink = "#FF697A";
        SeaGreen = "#00FF8C";
        Teal = "#009B9D";
        DarkMagenta = "#AC0059";
        Yellow = "#FFFF00";
        Ivory = "#FEFF9B";
        ElectricPurple = "#B70AFF";
        DeepPink = "#FF00B1";
        Aqua = "#4EFFFF";
        DarkGreen = "#008000";
        Red = "#FF0000";
        Green = "#00FF05";
        SaddleBrown = "#94652E";
        OrangeRed = "#FF4700";
        LightBlue = "#23A0FF";
        Orchid = "#FF87FF";
        Brown = "#943E3E";
        CopperRose = "#AD7E7E";
        Tan = "#FFAF56";
        Lime = "#8EBE57";
        TyrianPurple = "#990024";
        MardiGras = "#880085";
        RoyalBlue = "#4169E1";
        WildStrawberry = "#FF43A4";
        SmokyBlack = "#100C08";
        Goldenrod = "#DAA520";
        Cyan = "#00FFFF";
        Artichoke = "#8F9779";
        RainForest = "#00755E";
        Peach = "#FFE5B4";
        AppleGreen = "#8DB600";
        Viridian = "#40826D";
        Mahogany = "#C04000";
        PinkLace = "#FFDDF4";
        Bronze = "#CD7F32";
        WoodBrown = "#C19A6B";
        Tuscany = "#C09999";
        AcidGreen = "#B0BF1A";
        Amazon = "#3B7A57";
        ArmyGreen = "#4B5320";
        DonkeyBrown = "#664C28";
        Cordovan = "#893F45";
        Cinnamon = "#D2691E";
        Charcoal = "#36454F";
        Fuchsia = "#FF00FF";
        ScreaminGreen = "#76FF7A";
    };
end

--given a hex colour string like "#RRGGBB", return a single 24-bit integer, useful for annotations
---@param hexColour string
---@return integer
function GetColourIntegerFromHex(hexColour)
    local normalized = string.gsub(hexColour, "#", "");
    return tonumber(normalized, 16);
end

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;
SUBHEADING_COLOUR2 = BUTTON_COLOURS.LightBlue;
