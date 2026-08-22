require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
MigrateModSettings();
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Grants gold if this is a Commerce game, otherwise armies*').SetColor(BUTTON_COLOURS.DarkGray);

    local reconHorz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(reconHorz).SetText('Apply to Reconnaissance Card:');
    reconEnabled = UI.CreateCheckBox(reconHorz)
        .SetIsChecked(Mod.Settings.ReconnaissanceEnabled or true)
        .SetText('');

    local surveillanceHorz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(surveillanceHorz).SetText('Apply to Surveillance Card:');
    surveillanceEnabled = UI.CreateCheckBox(surveillanceHorz)
        .SetIsChecked(Mod.Settings.SurveillanceEnabled or false)
        .SetText('');

    local reconConfigHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    local surveillanceConfigHeading = UI.CreateVerticalLayoutGroup(mainModUI);

    reconEnabled.SetOnValueChanged(function()
        if (reconEnabled.GetIsChecked()) then
            Create_ReconnaissanceConfig_UI(reconConfigHeading);
        else
            UI.Destroy(reconConfigContent);
        end
    end);

    surveillanceEnabled.SetOnValueChanged(function()
        if (surveillanceEnabled.GetIsChecked()) then
            Create_SurveillanceConfig_UI(surveillanceConfigHeading);
        else
            UI.Destroy(surveillanceConfigContent);
        end
    end);

    -- one time build up from settings
    if (reconEnabled.GetIsChecked()) then
        Create_ReconnaissanceConfig_UI(reconConfigHeading);
    end

    if (surveillanceEnabled.GetIsChecked()) then
        Create_SurveillanceConfig_UI(surveillanceConfigHeading);
    end
end

function Create_ReconnaissanceConfig_UI(rootParent)
    reconConfigContent = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(reconConfigContent).SetText('Reconnaissance Settings:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(reconConfigContent);
    UI.CreateLabel(horz).SetText('Temporary income gained per instance of friendly reconned item:').SetPreferredWidth(290);
    effectStrength = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.EffectStrength or 5);

    local monitorHeading = UI.CreateVerticalLayoutGroup(reconConfigContent);
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

    local monitorSubOptionsHeading = UI.CreateVerticalLayoutGroup(reconConfigContent);

    monitorCities.SetOnValueChanged(function()
        if (monitorCities.GetIsChecked()) then
            monitorCities.SetInteractable(false);
            Create_ReconCityIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
        else
            monitorCities.SetInteractable(true);
            UI.Destroy(cityIncomeModeHeading);
        end
    end);

    monitorTerritories.SetOnValueChanged(function()
        if (monitorTerritories.GetIsChecked()) then
            monitorTerritories.SetInteractable(false);
            Create_ReconTerritoryIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
        else
            monitorTerritories.SetInteractable(true);
            UI.Destroy(territoryIncomeModeHeading);
        end
    end);

    -- one time build up from settings
    if (monitorCities.GetIsChecked()) then
        monitorCities.SetInteractable(false);
        Create_ReconCityIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
    else
        monitorTerritories.SetInteractable(false);
        Create_ReconTerritoryIncomeMode_SubOptions_UI(monitorSubOptionsHeading);
    end
end

function Create_ReconCityIncomeMode_SubOptions_UI(rootParent)
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

function Create_ReconTerritoryIncomeMode_SubOptions_UI(rootParent)
    territoryIncomeModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(territoryIncomeModeHeading).SetText('Increased income per reconned:');
    local territoryIncomeModeGroup = UI.CreateRadioButtonGroup(territoryIncomeModeHeading);

    territoryIncomeModePerTerritory = UI.CreateRadioButton(territoryIncomeModeHeading).SetGroup(territoryIncomeModeGroup)
    .SetText('Territory')
    .SetIsChecked(true)
    .SetInteractable(false);
end

function Create_SurveillanceConfig_UI(rootParent)
    surveillanceConfigContent = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(surveillanceConfigContent).SetText('Surveillance Settings:').SetColor(BUTTON_COLOURS.LightBlue);

    local horz = UI.CreateHorizontalLayoutGroup(surveillanceConfigContent);
    UI.CreateLabel(horz).SetText('Temporary income gained per instance of friendly surveilled item:').SetPreferredWidth(290);
    surveillanceEffectStrength = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.SurveillanceEffectStrength or 5);

    local surveillanceMonitorHeading = UI.CreateVerticalLayoutGroup(surveillanceConfigContent);
    UI.CreateLabel(surveillanceMonitorHeading).SetText('Monitoring Category:');
    local surveillanceMonitorGroup = UI.CreateRadioButtonGroup(surveillanceMonitorHeading);

    surveillanceMonitorCities = UI.CreateRadioButton(surveillanceMonitorHeading)
    .SetGroup(surveillanceMonitorGroup)
    .SetText('Cities')
    .SetIsChecked(Mod.Settings.SurveillanceMonitorCities or true);

    surveillanceMonitorTerritories = UI.CreateRadioButton(surveillanceMonitorHeading)
    .SetGroup(surveillanceMonitorGroup)
    .SetText('Territories')
    .SetIsChecked(Mod.Settings.SurveillanceMonitorTerritories or false);

    local surveillanceMonitorSubOptionsHeading = UI.CreateVerticalLayoutGroup(surveillanceConfigContent);

    surveillanceMonitorCities.SetOnValueChanged(function()
        if (surveillanceMonitorCities.GetIsChecked()) then
            surveillanceMonitorCities.SetInteractable(false);
            Create_SurveillanceCityIncomeMode_SubOptions_UI(surveillanceMonitorSubOptionsHeading);
        else
            surveillanceMonitorCities.SetInteractable(true);
            UI.Destroy(surveillanceCityIncomeModeHeading);
        end
    end);

    surveillanceMonitorTerritories.SetOnValueChanged(function()
        if (surveillanceMonitorTerritories.GetIsChecked()) then
            surveillanceMonitorTerritories.SetInteractable(false);
            Create_SurveillanceTerritoryIncomeMode_SubOptions_UI(surveillanceMonitorSubOptionsHeading);
        else
            surveillanceMonitorTerritories.SetInteractable(true);
            UI.Destroy(surveillanceTerritoryIncomeModeHeading);
        end
    end);

    -- one time build up from settings
    if (surveillanceMonitorCities.GetIsChecked()) then
        surveillanceMonitorCities.SetInteractable(false);
        Create_SurveillanceCityIncomeMode_SubOptions_UI(surveillanceMonitorSubOptionsHeading);
    else
        surveillanceMonitorTerritories.SetInteractable(false);
        Create_SurveillanceTerritoryIncomeMode_SubOptions_UI(surveillanceMonitorSubOptionsHeading);
    end
end

function Create_SurveillanceCityIncomeMode_SubOptions_UI(rootParent)
    surveillanceCityIncomeModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(surveillanceCityIncomeModeHeading).SetText('Increased gold per surveilled:');
    local surveillanceCityIncomeModeGroup = UI.CreateRadioButtonGroup(surveillanceCityIncomeModeHeading);

    surveillanceCityIncomeModePerCity = UI.CreateRadioButton(surveillanceCityIncomeModeHeading).SetGroup(surveillanceCityIncomeModeGroup)
    .SetText('City')
    .SetIsChecked(Mod.Settings.SurveillanceCityIncomeModePerCity or true);

    surveillanceCityIncomeModePerTerritoryWithCity = UI.CreateRadioButton(surveillanceCityIncomeModeHeading).SetGroup(surveillanceCityIncomeModeGroup)
    .SetText('Territory with a city')
    .SetIsChecked(Mod.Settings.SurveillanceCityIncomeModePerTerritoryWithCity or false);

    surveillanceCityIncomeModePerCity.SetOnValueChanged(function()
        if (surveillanceCityIncomeModePerCity.GetIsChecked()) then
            surveillanceCityIncomeModePerCity.SetInteractable(false);
        else
            surveillanceCityIncomeModePerCity.SetInteractable(true);
        end
    end);

    surveillanceCityIncomeModePerTerritoryWithCity.SetOnValueChanged(function()
        if (surveillanceCityIncomeModePerTerritoryWithCity.GetIsChecked()) then
            surveillanceCityIncomeModePerTerritoryWithCity.SetInteractable(false);
        else
            surveillanceCityIncomeModePerTerritoryWithCity.SetInteractable(true);
        end
    end);

    if (surveillanceCityIncomeModePerCity.GetIsChecked()) then
        surveillanceCityIncomeModePerCity.SetInteractable(false);
    else
        surveillanceCityIncomeModePerTerritoryWithCity.SetInteractable(false);
    end
end

function Create_SurveillanceTerritoryIncomeMode_SubOptions_UI(rootParent)
    surveillanceTerritoryIncomeModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(surveillanceTerritoryIncomeModeHeading).SetText('Increased income per surveilled:');
    local surveillanceTerritoryIncomeModeGroup = UI.CreateRadioButtonGroup(surveillanceTerritoryIncomeModeHeading);

    surveillanceTerritoryIncomeModePerTerritory = UI.CreateRadioButton(surveillanceTerritoryIncomeModeHeading).SetGroup(surveillanceTerritoryIncomeModeGroup)
    .SetText('Territory')
    .SetIsChecked(true)
    .SetInteractable(false);
end
