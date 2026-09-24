---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (Mod.Settings.isAcquiringTypeCard ~= nil and not Mod.Settings.isAcquiringTypeCard and not settings.CommerceGame) then
        alert("Barbed Wire is set to be acquired via Commerce, but this game is not a Commerce game.");
    end

    local bombCardEnabled = settings.Cards ~= nil and settings.Cards[WL.CardID.Bomb] ~= nil;
    if (Mod.Settings.BarbedWireBombDestroys and not bombCardEnabled) then
        alert("Barbed Wire is set to be destroyed by bombs, but the Bomb card is not enabled in this game.");
    end
    if (Mod.Settings.CaltropBombDestroys and not bombCardEnabled) then
        alert("Caltrops are set to be destroyed by bombs, but the Bomb card is not enabled in this game.");
    end
end
