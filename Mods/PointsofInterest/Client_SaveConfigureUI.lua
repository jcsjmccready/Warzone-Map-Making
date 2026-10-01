require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    Mod.Settings.PoICost = poiCost.GetValue();
    if (Mod.Settings.PoICost < 0) then
        alert("Cost of a Point of Interest cannot be less than 0");
        return;
    end

    local visibility = {};
    for _, name in ipairs(NATO_NAMES) do
        visibility[name] = visibilityDropDowns[name].GetKey();
    end
    Mod.Settings.PoIVisibility = visibility;
end
