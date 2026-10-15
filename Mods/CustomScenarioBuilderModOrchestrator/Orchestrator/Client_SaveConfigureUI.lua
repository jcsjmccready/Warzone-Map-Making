require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    -- Territory/Placement Name are validated (and the plain PlaceholderPlacementSetting struct built) when a row
    -- is saved in the Edit view - PlaceholderConfigureState.Placements is already in the exact shape to persist
    Mod.Settings.PlaceholderPlacements = PlaceholderConfigureState.Placements;
    Mod.Settings.IsPlanningMode = PlaceholderConfigureState.IsPlanningModeValue;
end
