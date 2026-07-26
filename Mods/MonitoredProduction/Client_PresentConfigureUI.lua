require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Grants gold if this is a Commerce game, otherwise armies*').SetColor(BUTTON_COLOURS.DarkGray);

    UI.CreateLabel(mainModUI).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Temporary income gained per instance of friendly reconned item:').SetPreferredWidth(290);
    effectStrength = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.EffectStrength or 5);

    local monitorHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(monitorHeading).SetText('Monitoring Category:');
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
            monitorCities.SetInteractable(false);
            Create_CityIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
        else
            monitorCities.SetInteractable(true);
            UI.Destroy(cityIncomeModeHeading);
        end
    end);

    monitorTerritories.SetOnValueChanged(function()
        if (monitorTerritories.GetIsChecked()) then
            monitorTerritories.SetInteractable(false);
            Create_TerritoryIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
        else
            monitorTerritories.SetInteractable(true);
            UI.Destroy(territoryIncomeModeHeading);
        end
    end);

    -- one time build up from settings
    if (monitorCities.GetIsChecked()) then
        monitorCities.SetInteractable(false);
        Create_CityIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
    else
        monitorTerritories.SetInteractable(false);
        Create_TerritoryIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
    end
end

function Create_CityIncomeMode_SubOptions_UI(rootParent)
    cityIncomeModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(cityIncomeModeHeading).SetText('Increased gold per reconned:');
    local cityIncomeModeGroup = UI.CreateRadioButtonGroup(cityIncomeModeHeading);

    cityIncomeModePerCity = UI.CreateRadioButton(cityIncomeModeHeading).SetGroup(cityIncomeModeGroup)
    .SetText('City')
    .SetIsChecked(Mod.Settings.CityIncomeModePerCity or true);

    cityIncomeModePerTerritoryWithCity = UI.CreateRadioButton(cityIncomeModeHeading).SetGroup(cityIncomeModeGroup)
    .SetText('Territory with a city')
    .SetIsChecked(Mod.Settings.CityIncomeModePerTerritoryWithCity or false);

    cityIncomeModePerCity.SetOnValueChanged(function()
        if (cityIncomeModePerCity.GetIsChecked()) then
            cityIncomeModePerCity.SetInteractable(false);
        else
            cityIncomeModePerCity.SetInteractable(true);
        end
    end);

    cityIncomeModePerTerritoryWithCity.SetOnValueChanged(function()
        if (cityIncomeModePerTerritoryWithCity.GetIsChecked()) then
            cityIncomeModePerTerritoryWithCity.SetInteractable(false);
        else
            cityIncomeModePerTerritoryWithCity.SetInteractable(true);
        end
    end);

    if (cityIncomeModePerCity.GetIsChecked()) then
        cityIncomeModePerCity.SetInteractable(false);
    else
        cityIncomeModePerTerritoryWithCity.SetInteractable(false);
    end
end

function Create_TerritoryIncomeMode_SubOptions_UI(rootParent)
    territoryIncomeModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(territoryIncomeModeHeading).SetText('Increased income per reconned:');
    local territoryIncomeModeGroup = UI.CreateRadioButtonGroup(territoryIncomeModeHeading);

    --only one option currently exists, so it's permanently checked and non-interactable, same as BarbedWire's
    --single-option "Acquiring type: Card" radio
    territoryIncomeModePerTerritory = UI.CreateRadioButton(territoryIncomeModeHeading).SetGroup(territoryIncomeModeGroup)
    .SetText('Territory')
    .SetIsChecked(true)
    .SetInteractable(false);
end
