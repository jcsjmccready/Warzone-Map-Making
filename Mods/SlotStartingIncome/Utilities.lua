CURRENT_SETTINGS_VERSION = 1;

--Highest slot a Custom Scenario can use without throwing "InvalidSlot" (A-OJ).
MAX_SLOT = 399;

MAX_VALUE_MODIFIER = 999999;

--Creates a dropdown-style control (Warzone has no native dropdown): a button showing the current choice which
--opens a list prompt when clicked. options may be a static { Key, Text }[] or a fun(): { Key, Text }[] that's
--re-evaluated every time the button is clicked, so the available choices can depend on other UI state.
---@param parent UIObject
---@param options ({ Key: any, Text: string }[]) | (fun(): { Key: any, Text: string }[])
---@param initialKey any
---@param onChanged fun(key: any) | nil
---@return { GetKey: fun(): any, SetKey: fun(key: any), Button: Button }
function CreateDropDown(parent, options, initialKey, onChanged)
    local selectedKey = initialKey;

    local function ResolveOptions()
        if (type(options) == "function") then return options(); end
        return options;
    end

    local button = UI.CreateButton(parent).SetText(GetOptionText(ResolveOptions(), selectedKey));

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

---@param options { Key: any, Text: string }[]
---@param key any
---@return string
function GetOptionText(options, key)
    for _, option in ipairs(options) do
        if (option.Key == key) then
            return option.Text;
        end
    end
    return tostring(key);
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
SUBHEADING_COLOUR = BUTTON_COLOURS.Artichoke;

--Converts a 0-based slot index into its spreadsheet-style display letter (A=0, Z=25, AA=26, ...).
---@param slot integer
---@return string
function SlotToLetter(slot)
    local col = slot + 1;
    local letter = "";
    while col > 0 do
        col = col - 1;
        letter = string.char(65 + (col % 26)) .. letter;
        col = math.floor(col / 26);
    end
    return letter;
end

--Every selectable slot (A-OJ) as a { Key, Text } option list for CreateDropDown.
---@return { Key: integer, Text: string }[]
function GetAllSlotOptions()
    local options = {};
    for slot = 0, MAX_SLOT do
        table.insert(options, { Key = slot, Text = SlotToLetter(slot) });
    end
    return options;
end

--Finds the PlayerID who owns a territory assigned to slot, or nil if no such territory is owned by a player yet.
--GamePlayer.Slot is unreliable (observed nil for every player, even after distribution), so this resolves slots
--via the scenario's own territory->slot map and the standing's actual territory ownership instead.
---@param game GameServerHook
---@param standing GameStanding
---@param slot integer
---@return PlayerID | nil
function FindPlayerIDForSlot(game, standing, slot)
    local scenario = game.Settings.CustomScenario;
    if (scenario == nil) then return nil; end

    for territoryID, scenarioTerritory in pairs(scenario.Territories) do
        if (scenarioTerritory.Slot == slot) then
            local territoryStanding = standing.Territories[territoryID];
            if (territoryStanding ~= nil and not territoryStanding.IsNeutral) then
                return territoryStanding.OwnerPlayerID;
            end
        end
    end
    return nil;
end
