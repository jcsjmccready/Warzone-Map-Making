require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    if (not reconEnabled.GetIsChecked() and not surveillanceEnabled.GetIsChecked()) then
        alert("At least one card type (Reconnaissance or Surveillance) must be selected");
        return;
    end

    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;
    Mod.Settings.ReconnaissanceEnabled = reconEnabled.GetIsChecked();

    if (Mod.Settings.ReconnaissanceEnabled) then
        Mod.Settings.MonitorCities = monitorCities.GetIsChecked();
        Mod.Settings.MonitorTerritories = monitorTerritories.GetIsChecked();
        Mod.Settings.EffectStrength = effectStrength.GetValue();

        if (Mod.Settings.MonitorCities) then
            Mod.Settings.CityIncomeModePerCity = cityIncomeModePerCity.GetIsChecked();
            Mod.Settings.CityIncomeModePerTerritoryWithCity = cityIncomeModePerTerritoryWithCity.GetIsChecked();
        elseif (Mod.Settings.MonitorTerritories) then
            Mod.Settings.TerritoryIncomeModePerTerritory = true; -- replace this logic if we ever extend the territory income mode to have more than one option
        end

        if (Mod.Settings.EffectStrength < 1) then
            alert("Reconnaissance effect strength cannot be less than 1");
            return;
        end
    end

    Mod.Settings.SurveillanceEnabled = surveillanceEnabled.GetIsChecked();

    if (Mod.Settings.SurveillanceEnabled) then
        Mod.Settings.SurveillanceMonitorCities = surveillanceMonitorCities.GetIsChecked();
        Mod.Settings.SurveillanceMonitorTerritories = surveillanceMonitorTerritories.GetIsChecked();
        Mod.Settings.SurveillanceEffectStrength = surveillanceEffectStrength.GetValue();

        if (Mod.Settings.SurveillanceMonitorCities) then
            Mod.Settings.SurveillanceCityIncomeModePerCity = surveillanceCityIncomeModePerCity.GetIsChecked();
            Mod.Settings.SurveillanceCityIncomeModePerTerritoryWithCity = surveillanceCityIncomeModePerTerritoryWithCity.GetIsChecked();
        elseif (Mod.Settings.SurveillanceMonitorTerritories) then
            Mod.Settings.SurveillanceTerritoryIncomeModePerTerritory = true; -- replace this logic if we ever extend the territory income mode to have more than one option
        end

        if (Mod.Settings.SurveillanceEffectStrength < 1) then
            alert("Surveillance effect strength cannot be less than 1");
            return;
        end
    end
end
