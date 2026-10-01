CURRENT_SETTINGS_VERSION = 1;

--NATO phonetic alphabet, A-Z. Each name is both the custom structure's name and its image filename
--(StructureImages/<Name>.png)
NATO_NAMES = {
    "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet", "Kilo", "Lima", "Mike",
    "November", "Oscar", "Papa", "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey", "Xray", "Yankee", "Zulu",
};

--Visibility options shown in the configure UI, in display order. Key is what is stored in Mod.Settings
VISIBILITY_OPTIONS = {
    { Key = "NoFog", Text = "No Fog" },
    { Key = "Default", Text = "Default" },
    { Key = "HeavyFog", Text = "Heavy Fog" },
};
DEFAULT_VISIBILITY = "Default";

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

--Converts a stored visibility key into the standing fog level a FogMod should apply. Returns nil for Default, which
--makes no changes so the lobby's own fog settings decide what is shown
---@param key string
---@return EnumStandingFogLevel | nil
function GetStandingFogLevel(key)
    if (key == "NoFog") then
        return WL.StandingFogLevel.Visible;
    elseif (key == "HeavyFog") then
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

--Returns the configured visibility key for a structure, defaulting if unset
---@param name string
---@return string
function GetConfiguredVisibility(name)
    local visibility = Mod.Settings.PoIVisibility;
    return (visibility ~= nil and visibility[name]) or DEFAULT_VISIBILITY;
end

--Creates a dropdown-style control (Warzone has no native dropdown): a button showing the current choice which
--opens a list prompt when clicked.
---@param parent UIObject
---@param options { Key: string, Text: string }[]
---@param initialKey string
---@param onChanged fun(key: string) | nil
---@return { GetKey: fun(): string, Button: Button }
function CreateDropDown(parent, options, initialKey, onChanged)
    local selectedKey = initialKey;
    local button = UI.CreateButton(parent).SetText(GetOptionText(options, selectedKey));

    button.SetOnClick(function()
        local list = {};
        for _, option in ipairs(options) do
            table.insert(list, {
                text = option.Text,
                selected = function()
                    selectedKey = option.Key;
                    button.SetText(option.Text);
                    if (onChanged ~= nil) then
                        onChanged(option.Key);
                    end
                end,
            });
        end
        UI.PromptFromList("Select an option", list);
    end);

    return {
        GetKey = function() return selectedKey; end,
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
    local name, territoryID = string.match(payload or "", "^" .. PAYLOAD_PREFIX .. "(%a+)_(%d+)$");
    if (name == nil) then
        return nil, nil;
    end
    return name, tonumber(territoryID);
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