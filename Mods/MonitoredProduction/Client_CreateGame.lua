---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (Mod.Settings.MonitorCities and not settings.CommerceGame) then
        alert("This mod must be used in a Commerce game when set to monitor Cities, since it grants extra gold.");
    end

    if (settings.Cards == nil or settings.Cards[WL.CardID.Reconnaissance] == nil) then
        alert("The Reconnaissance card must be enabled for this mod to work.");
    end
end
