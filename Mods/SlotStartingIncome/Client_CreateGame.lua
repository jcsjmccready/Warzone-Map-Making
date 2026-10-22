---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (#(Mod.Settings.Rows or {}) == 0) then return; end

    if (settings.CustomScenario == nil) then
        alert("Slot Starting Income rows are configured, but this game isn't using the Custom Scenario distribution, so no slot can be matched to a player.");
    end
end
