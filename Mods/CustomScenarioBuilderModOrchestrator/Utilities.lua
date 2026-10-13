CURRENT_SETTINGS_VERSION = 1;

-- The name (and SpecialUnitImages filename) of this mod's stand-in special unit. Placed on configured
-- territories at game creation, to later be swapped out for a structure or special unit from another mod
-- once that cross-mod replacement step is built.
PLACEHOLDER_NAME = "Placeholder";
PLACEHOLDER_IMAGE_FILENAME = "Placeholder.png";

--What a placement row's Type dropdown can be set to. Key is what is stored in Mod.Settings.PlaceholderPlacements
PLACEMENT_TYPE_OPTIONS = {
    { Key = "Structure", Text = "Structure" },
    { Key = "SpecialUnit", Text = "Special Unit" },
};
DEFAULT_PLACEMENT_TYPE = "SpecialUnit";

-- Encoded into every placed Placeholder's own ModData field, so any other mod can read what it's standing in for
-- without needing access to this mod's own Settings (Mod.* storages are private per-mod; ModData lives on the
-- unit itself and survives the unit being cloned, e.g. during combat). Uses the same quoted-string, "{key:value}"
-- table format as the IO package's IO.Writer/IO.Reader elsewhere in this codebase, but written out by hand here -
-- see CustomScenarioBuilder.lua, the copy-paste integration file other mods carry to decode this, which must stay
-- in sync with this exact format without requiring either mod to carry the IO package.
---@param s string
---@return string
local function EncodeModDataString(s)
    return "\"" .. string.gsub(string.gsub(s, "\\", "\\\\"), "\"", "\\\"") .. "\"";
end

---@param placementType string
---@param placementName string | nil
---@return string
function EncodePlaceholderModData(placementType, placementName)
    local fields = { Type = placementType };
    if (placementName ~= nil and placementName ~= "") then
        fields.PlacementName = placementName;
    end

    local pairsList = {};
    for key, value in pairs(fields) do
        table.insert(pairsList, EncodeModDataString(key) .. ":" .. EncodeModDataString(value));
    end
    return "{" .. table.concat(pairsList, ",") .. "}";
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

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;
SUBHEADING_COLOUR2 = BUTTON_COLOURS.LightBlue;
