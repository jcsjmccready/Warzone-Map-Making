require("Utilities");

---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    MigrateModSettings();

    -- fallback to the pre-Surveillance legacy fields when ReconnaissanceEnabled is unset
    local reconEnabled = Mod.Settings.ReconnaissanceEnabled or Mod.Settings.MonitorCities or Mod.Settings.MonitorTerritories;

    if (not reconEnabled and not Mod.Settings.SurveillanceEnabled) then
        alert("At least one card type (Reconnaissance or Surveillance) must be selected in the mod settings.");
    end

    if (reconEnabled) then
        if (Mod.Settings.MonitorCities and not settings.CommerceGame) then
            alert("This mod must be used in a Commerce game when set to monitor Cities for Reconnaissance, since it grants extra gold.");
        end

        if (settings.Cards == nil or settings.Cards[WL.CardID.Reconnaissance] == nil) then
            alert("The Reconnaissance card must be enabled for this mod to work.");
        end
    end

    if (Mod.Settings.SurveillanceEnabled) then
        if (Mod.Settings.SurveillanceMonitorCities and not settings.CommerceGame) then
            alert("This mod must be used in a Commerce game when set to monitor Cities for Surveillance, since it grants extra gold.");
        end

        if (settings.Cards == nil or settings.Cards[WL.CardID.Surveillance] == nil) then
            alert("The Surveillance card must be enabled for this mod to work.");
        end
    end
end
