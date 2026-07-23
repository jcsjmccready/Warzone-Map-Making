---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID # Creates a custom card. Can be invoked multiple times to create multiple cards. Every invokation will return the CardID of the just created card, make sure to save this in the settings of your mod
function Client_SaveConfigureUI(alert, addCard)

    Mod.Settings.MonitorCities = monitorCities.GetIsChecked();
    Mod.Settings.MonitorTerritories = monitorTerritories.GetIsChecked();

    if (Mod.Settings.MonitorCities) then
        Mod.Settings.CityIncomeModePerCity = cityIncomeModePerCity.GetIsChecked();
        Mod.Settings.CityIncomeModePerTerritoryWithCity = cityIncomeModePerTerritoryWithCity.GetIsChecked();
    elseif(Mod.Settings.MonitorTerritories) then
        Mod.Settings.TerritoryIncomeModePerTerritory = territoryIncomeModePerTerritory.GetIsChecked();
    end

    Mod.Settings.EffectStrength = effectStrength.GetValue();

    if (Mod.Settings.EffectStrength < 1) then
        alert("Effect strength cannot be less than 1");
        return;
    end
end
