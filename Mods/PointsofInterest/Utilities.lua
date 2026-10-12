require("IO.Writer");
require("IO.Reader");

CURRENT_SETTINGS_VERSION = 1;

--NATO phonetic alphabet, A-Z. Each name is both the custom structure's name and its image filename
NATO_NAMES = {
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima", "Mike",
    "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "X-ray", "Yankee", "Zulu",
};

--Visibility options shown in the configure UI, in display order. Key is what is stored in Mod.Settings
VISIBILITY_OPTIONS = {
    { Key = "NoFog", Text = "No Fog" },
    { Key = "LightFog", Text = "Light Fog" },
    { Key = "Fog", Text = "Fog" },
    { Key = "Default", Text = "Default" },
};
DEFAULT_VISIBILITY = "Default";

-- VISIBILITY_OPTIONS + Disabled entry
POI_STATE_OPTIONS = { { Key = "Disabled", Text = "Disabled" } };
for _, option in ipairs(VISIBILITY_OPTIONS) do
    table.insert(POI_STATE_OPTIONS, option);
end

--FogMod priority. Below 9000 so a FogMod can never hide a player's own territories
FOG_MOD_PRIORITY = 8000;

PAYLOAD_PREFIX = "PointsOfInterest_";

---@param key string
---@return string
function GetVisibilityText(key)
    for _, option in ipairs(VISIBILITY_OPTIONS) do
        if (option.Key == key) then
            return option.Text;
        end
    end
    return key;
end

---@param key string # one of POI_STATE_OPTIONS
---@return string # hex colour string
function GetPoIStateColor(key)
    if (key == "Disabled") then
        return BUTTON_COLOURS.Charcoal;
    elseif (key == "NoFog") then
        return BUTTON_COLOURS.DarkGreen;
    elseif (key == "LightFog") then
        return BUTTON_COLOURS.Peach;
    elseif (key == "Fog") then
        return BUTTON_COLOURS.Cinnamon;
    end
    return BUTTON_COLOURS.RoyalBlue; -- Default
end

--Converts a stored visibility key into the standing fog level a FogMod should apply.
---@param key string
---@return EnumStandingFogLevel | nil
function GetStandingFogLevel(key)
    if (key == "NoFog") then
        return WL.StandingFogLevel.Visible;
    elseif (key == "LightFog") then
        return WL.StandingFogLevel.OwnerOnly;
    elseif (key == "Fog") then
        return WL.StandingFogLevel.Fogged;
    end
    return nil;
end

---@param name string
---@return boolean
function IsNatoName(name)
    for _, natoName in ipairs(NATO_NAMES) do
        if (natoName == name) then
            return true;
        end
    end
    return false;
end

---@param letter string # Must be a single letter A-Z, case-insensitive`
---@return string | nil # nil if letter isn't exactly one A-Z letter
function GetNatoNameForLetter(letter)
    if (type(letter) ~= "string" or #letter ~= 1) then return nil; end

    local upper = string.upper(letter);
    local index = string.byte(upper) - string.byte("A") + 1;
    if (index < 1 or index > #NATO_NAMES) then return nil; end

    return NATO_NAMES[index];
end

---@param name string # Must be a valid NATO alphabet name, the caller is expected to have validated this
---@return string # The first letter of the name, uppercased
function GetLetterForNatoName(name)
    return string.sub(name, 1, 1);
end

--Returns the configured visibility key for a structure, defaulting if unset
---@param name string
---@return string
function GetConfiguredVisibility(name)
    local visibility = Mod.Settings.PoIVisibility;
    return (visibility ~= nil and visibility[name]) or DEFAULT_VISIBILITY;
end

--Returns whether a POI is enabled. Unset (nil) is treated as disabled, so a letter has to be opted into explicitly
---@param name string
---@return boolean
function IsPoIEnabled(name)
    local enabled = Mod.Settings.PoIEnabled;
    return enabled ~= nil and enabled[name] == true;
end

---@param options { Key: string, Text: string }[]
---@param key string
---@return boolean
function OptionsContainKey(options, key)
    for _, option in ipairs(options) do
        if (option.Key == key) then
            return true;
        end
    end
    return false;
end

---@param str string
---@return string
function TrimString(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"));
end

--Finds the TerritoryID of the territory whose name matches territoryName, case-insensitively. Used to resolve the
--free-text territory names stored in Mod.Settings.PoIPlacements against the actual map at game start
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
--opens a list prompt when clicked. options can be a static list, or a function returning one - use a function when
--the available options can change after the dropdown is created (e.g. a list that depends on other live UI state),
--so the list shown on each click is never stale.
---@param parent UIObject
---@param options { Key: string, Text: string }[] | fun(): { Key: string, Text: string }[]
---@param initialKey string
---@param onChanged fun(key: string) | nil
---@return { GetKey: fun(): string, SetKey: fun(key: string), Button: Button }
function CreateDropDown(parent, options, initialKey, onChanged)
    local selectedKey = initialKey;

    ---@return { Key: string, Text: string }[]
    local function ResolveOptions()
        if (type(options) == "function") then return options(); end
        return options;
    end

    local button = UI.CreateButton(parent).SetText(GetOptionText(ResolveOptions(), selectedKey));

    ---Updates the selected key and button text. Only fires onChanged for a real user selection (triggerOnChanged),
    ---not for a programmatic SetKey call (e.g. two rows swapping their values to "move" in a list)
    ---@param key string
    ---@param triggerOnChanged boolean
    local function ApplySelection(key, triggerOnChanged)
        selectedKey = key;
        button.SetText(GetOptionText(ResolveOptions(), key));
        if (triggerOnChanged and onChanged ~= nil) then
            onChanged(key);
        end
    end

    button.SetOnClick(function()
        local list = {};
        for _, option in ipairs(ResolveOptions()) do
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

function GetOptionText(options, key)
    for _, option in ipairs(options) do
        if (option.Key == key) then
            return option.Text;
        end
    end
    return key;
end

--Extracts the structure name and territory from a build order payload, or nil if it isn't one
---@param payload string
---@return string | nil, TerritoryID | nil
function ParseBuildPayload(payload)
    -- [%a%-]+ rather than %a+: X-ray is the one NATO name with a non-letter character in it
    local name, territoryID = string.match(payload or "", "^" .. PAYLOAD_PREFIX .. "([%a%-]+)_(%d+)$");
    if (name == nil) then
        return nil, nil;
    end
    return name, tonumber(territoryID);
end

---Serializes a list of placements into a pasteable string, grouped by letter (letter -> territory names)
---@param placements PointsOfInterestPlacementSetting[]
---@return string
function SerializePlacementData(placements)
    local grouped = {};
    for _, placement in ipairs(placements) do
        local letter = GetLetterForNatoName(placement.Name);
        local territoryNames = grouped[letter] or {};
        table.insert(territoryNames, placement.TerritoryName);
        grouped[letter] = territoryNames;
    end
    return IO.Writer.Write(grouped);
end

---Parses a string produced by SerializePlacementData back into a list of placements. Returns nil if the errored
---@param text string
---@return PointsOfInterestPlacementSetting[] | nil
function DeserializePlacementData(text)
    local parsed = IO.Reader.Read(text, "table");
    if (type(parsed) ~= "table" or (not IO.Util.TableIsEmpty(parsed) and IO.Util.IsArray(parsed))) then return nil; end

    local placements = {};
    for letter, territoryNames in pairs(parsed) do
        local name = type(letter) == "string" and GetNatoNameForLetter(letter);
        if (not name or type(territoryNames) ~= "table" or not IO.Util.IsArray(territoryNames)) then
            return nil;
        end
        for _, territoryName in ipairs(territoryNames) do
            if (type(territoryName) ~= "string") then return nil; end
            table.insert(placements, { Name = name, TerritoryName = territoryName });
        end
    end
    return placements;
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

--given 0-255 RGB integers, return a single 24-bit integer, useful for annotations
function GetColourInteger (red, green, blue)
	return red*256^2 + green*256 + blue;
end

--given a hex colour string like "#RRGGBB", return a single 24-bit integer
function GetColourIntegerFromHex(hexColour)
    local normalized = string.gsub(hexColour, "#", "");
    return tonumber(normalized, 16);
end

TEXT_DEFAULT_COLOUR = "#CCCCCC";
BUTTON_COLOURS = GetButtonColors();
ERROR_COLOUR = BUTTON_COLOURS.Red;
SUBHEADING_COLOUR = BUTTON_COLOURS.Yellow;
SUBHEADING_COLOUR2 = BUTTON_COLOURS.LightBlue;