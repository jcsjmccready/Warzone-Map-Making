---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (settings.Cards == nil or settings.Cards[WL.CardID.Bomb] == nil) then
        alert("The Bomb card must be enabled for this mod to work.");
    end

    if (Mod.Settings.IsAcquiringTypeCard ~= nil and not Mod.Settings.IsAcquiringTypeCard and not settings.CommerceGame) then
        alert("Foxhole is set to be acquired via Commerce, but this game is not a Commerce game.");
    end
end