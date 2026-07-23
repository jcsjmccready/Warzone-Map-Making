require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Grants gold if this is a Commerce game, otherwise troops*').SetColor(BUTTON_COLOURS.DarkGray);

    UI.CreateLabel(mainModUI).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Effect strength').SetPreferredWidth(290);
    effectStrength = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.EffectStrength or 5);

    local monitorHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(monitorHeading).SetText('Monitor:');
    local monitorGroup = UI.CreateRadioButtonGroup(monitorHeading);

    monitorCities = UI.CreateRadioButton(monitorHeading)
    .SetGroup(monitorGroup)
    .SetText('Cities')
    .SetIsChecked(Mod.Settings.MonitorCities or true);

    monitorTerritories = UI.CreateRadioButton(monitorHeading)
    .SetGroup(monitorGroup)
    .SetText('Territories')
    .SetIsChecked(Mod.Settings.MonitorTerritories or false);

    local monitorSubOptionsHeading = UI.CreateVerticalLayoutGroup(mainModUI);

    monitorCities.SetOnValueChanged(function()
        if (monitorCities.GetIsChecked()) then
            Refresh_Monitor_SubOptions_UI(monitorSubOptionsHeading);
        end
    end);

    monitorTerritories.SetOnValueChanged(function()
        if (monitorTerritories.GetIsChecked()) then
            Refresh_Monitor_SubOptions_UI(monitorSubOptionsHeading);
        end
    end);

    -- one time build up from settings
    Refresh_Monitor_SubOptions_UI(monitorSubOptionsHeading);
end

--(re)builds the sub options for whichever of Cities/Territories is currently selected
function Refresh_Monitor_SubOptions_UI(rootParent)
    Destroy_Monitor_SubOptions_UI();

    monitorSubOptionsContent = UI.CreateVerticalLayoutGroup(rootParent);

    if (monitorCities.GetIsChecked()) then
        UI.CreateLabel(monitorSubOptionsContent).SetText('Increased gold per').SetColor(SUBHEADING_COLOUR2);
        local cityIncomeModeGroup = UI.CreateRadioButtonGroup(monitorSubOptionsContent);

        cityIncomeModePerCity = UI.CreateRadioButton(monitorSubOptionsContent).SetGroup(cityIncomeModeGroup)
        .SetText('City')
        .SetIsChecked(Mod.Settings.CityIncomeModePerCity or true);

        cityIncomeModePerTerritoryWithCity = UI.CreateRadioButton(monitorSubOptionsContent).SetGroup(cityIncomeModeGroup)
        .SetText('Territory with a city')
        .SetIsChecked(Mod.Settings.CityIncomeModePerTerritoryWithCity or false);
    else
        UI.CreateLabel(monitorSubOptionsContent).SetText('Increased gold/troops per').SetColor(SUBHEADING_COLOUR2);
        local territoryIncomeModeGroup = UI.CreateRadioButtonGroup(monitorSubOptionsContent);

        territoryIncomeModePerTerritory = UI.CreateRadioButton(monitorSubOptionsContent).SetGroup(territoryIncomeModeGroup)
        .SetText('Territory')
        .SetIsChecked(true);
    end
end

function Destroy_Monitor_SubOptions_UI()
    if (monitorSubOptionsContent ~= nil) then
        UI.Destroy(monitorSubOptionsContent);
        monitorSubOptionsContent = nil;
    end
    cityIncomeModePerCity = nil;
    cityIncomeModePerTerritoryWithCity = nil;
    territoryIncomeModePerTerritory = nil;
end
