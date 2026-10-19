require("Utilities");

---Client_CreateGame hook.
---@param settings GameSettings # Read-only GameSettings object
---@param alert fun(message: string) # When invoked, it will show a pop-up for the client with the message. It will also abort the game creation
function Client_CreateGame(settings, alert)
    if (#(Mod.Settings.PlaceholderPlacements or {}) == 0) then return; end

    local scenario = settings.CustomScenario;
    if (scenario == nil) then
        alert("Placement is configured, but this game isn't using the Custom Scenario distribution, so nothing will be placed.");
        return;
    end

    local maxSlot = -1;
    for _, slot in ipairs(scenario.SlotsAvailable or {}) do
        if (slot > maxSlot) then maxSlot = slot; end
    end

    if (maxSlot + 1 > MAX_KNOWN_VALID_SLOT) then
        alert("All possible slots (A-OJ) are used. One unused slot is required for this mod."); -- we need one for placing on neutral territories
    end
end
