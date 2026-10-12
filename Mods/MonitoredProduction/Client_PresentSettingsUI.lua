require('Utilities')

---Client_PresentSettingsUI hook
---@param rootParent RootParent
function Client_PresentSettingsUI(rootParent)
    MigrateModSettings();

    local descriptionVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(descriptionVGroup).SetText("Vision cards can be used to increase/decrease the income of territory owners");

    UI.CreateVerticalLayoutGroup(rootParent);

    local modVGroup = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    if (Mod.Settings.ReconnaissanceEnabled or Mod.Settings.MonitorCities or Mod.Settings.MonitorTerritories) then
        UI.CreateLabel(modVGroup).SetText("Reconnaissance:").SetColor(SUBHEADING_COLOUR);

        local unitText = GetMonitoredUnitText(Mod.Settings.MonitorCities, Mod.Settings.CityIncomeModePerCity, Mod.Settings.CityIncomeModePerTerritoryWithCity, Mod.Settings.MonitorTerritories);
        CreateStrengthLabels(modVGroup, Mod.Settings.EffectStrength or 0, Mod.Settings.OpponentEffectStrength or 0, unitText);
    end

    if (Mod.Settings.SurveillanceEnabled) then
        UI.CreateLabel(modVGroup).SetText("Surveillance:").SetColor(SUBHEADING_COLOUR2);

        local unitText = GetMonitoredUnitText(Mod.Settings.SurveillanceMonitorCities, Mod.Settings.SurveillanceCityIncomeModePerCity, Mod.Settings.SurveillanceCityIncomeModePerTerritoryWithCity, Mod.Settings.SurveillanceMonitorTerritories);
        CreateStrengthLabels(modVGroup, Mod.Settings.SurveillanceEffectStrength or 0, Mod.Settings.SurveillanceOpponentEffectStrength or 0, unitText);
    end
end

--returns e.g. "gold per city", or nil when the monitoring settings are incomplete
function GetMonitoredUnitText(monitorCities, perCity, perTerritoryWithCity, monitorTerritories)
    if (monitorCities) then
        if (perCity) then
            return "gold per city";
        elseif (perTerritoryWithCity) then
            return "gold per territory with a city";
        end
    elseif (monitorTerritories) then
        return "income per territory";
    end
    return nil;
end

function CreateStrengthLabels(parent, strength, opponentStrength, unitText)
    if (unitText == nil) then
        return;
    end

    if (strength ~= 0) then
        UI.CreateLabel(parent).SetText(FormatChange(strength) .. " " .. unitText .. " you or your team own");
    end

    if (opponentStrength ~= 0) then
        UI.CreateLabel(parent).SetText(FormatChange(opponentStrength) .. " " .. unitText .. " an opponent owns");
    end

    if (strength < 0 or opponentStrength < 0) then
        UI.CreateLabel(parent).SetText("Reductions cannot take a player below 0").SetColor(BUTTON_COLOURS.DarkGray);
    end
end

--returns the value with an explicit sign, e.g. "+5" or "-3"
function FormatChange(value)
    if (value > 0) then
        return "+" .. value;
    end
    return tostring(value);
end
