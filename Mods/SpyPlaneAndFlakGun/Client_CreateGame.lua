---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    local includesAirlift = settings.Cards ~= nil and settings.Cards[WL.CardID.Airlift] ~= nil;

    if (not includesAirlift and not Mod.Settings.IncludeSpyPlaneCard) then
        alert("You must either include the Airlift card or the Spy Plane card for this mod to work.");
    end
end
