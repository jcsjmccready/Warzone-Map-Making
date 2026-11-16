---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (not Mod.Settings.SpyPlaneEnableLineFlight and not Mod.Settings.SpyPlaneEnableCircleFlight) then
        alert("You must enable at least one flight type (Line or Circle) for the Spy Plane card.");
    end
end
