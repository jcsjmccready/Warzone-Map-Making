---Client_CreateGame hook. Used to check the game settings before actually creating the game
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (not Mod.Settings.SpyPlaneEnableLineFlight and not Mod.Settings.SpyPlaneEnableCircleFlight and not Mod.Settings.SpyPlaneEnablePathFlight) then
        alert("You must enable at least one flight type (Line, Circle, or Path) for the Spy Plane card.");
    end
end
