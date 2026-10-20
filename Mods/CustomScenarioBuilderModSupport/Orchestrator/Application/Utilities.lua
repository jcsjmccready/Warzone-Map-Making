require("Application.CommonUtils");
require("Application.BuiltInSupport.BuiltInSupport");

-- General constants
CURRENT_SETTINGS_VERSION = 1;

-- Highest Custom Scenario Slot ("OJ") observed not to throw "InvalidSlot".
MAX_KNOWN_VALID_SLOT = 399;

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

PLACEHOLDER_NAME = "Placeholder";
PLACEHOLDER_IMAGE_FILENAME = "Placeholder.png";
ICON_STRUCTURE = "Structure.png";
ICON_SPECIAL_UNIT = "SpecialUnit.png";
ICON_VANILLA = "Vanilla.png";
ICON_MODDED = "Modded.png";
ICON_BUILT_IN_SUPPORT = "BuiltInSupport.png";
ICON_EDIT = "Edit.png";
ICON_MOVE = "Move.png";
ICON_COPY = "Copy.png";

TYPE_FIELD_WIDTH = 80;
PLACEMENT_NAME_FIELD_WIDTH = 160;
TERRITORY_NAME_FIELD_WIDTH = 200;
ICON_SIZE = 28;
LIST_VIEW_ICON_SIZE = 20;

-- Special unit fields. ModID/Name/ID excluded
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

-- Applies every stringified SPECIAL_UNIT_FIELD_DESCRIPTORS value in fields onto a builder, converting each to its
-- real type. ModData/ModID are skipped - ModData is reserved for the Placeholder's own encoding, ModID isn't writable.
---@param builder CustomSpecialUnitBuilder
---@param fields table<string, string>
function ApplySpecialUnitFields(builder, fields)
    for _, descriptor in ipairs(SPECIAL_UNIT_FIELD_DESCRIPTORS) do
        local value = fields[descriptor.Key];
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

---Returns a shallow copy of placements sorted alphabetically (case-insensitive) by TerritoryName
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

---Parses a raw custom structure EnumStructureType string ("c|<ModID>|<Name>") into its display Name.
---@param structureID string
---@return string | nil
function CustomStructureToDisplayName(structureID)
    return string.match(structureID, "^c|[^|]*|(.*)$");
end

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