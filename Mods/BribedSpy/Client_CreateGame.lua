---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (settings.Cards == nil or settings.Cards[WL.CardID.Spy] == nil) then
        alert("The Spy card must be enabled for this mod to work.");
    end
end
