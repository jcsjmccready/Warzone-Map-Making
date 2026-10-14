require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    ---@type PlaceholderPlacementSetting[]
    local placements = {};
    for _, row in ipairs(PlaceholderConfigureState.PlacementRows) do
        local territoryName = TrimString(row.TerritoryField.GetText() or "");
        if (territoryName == "") then
            alert("Every row needs a territory name");
            return;
        end

        local placementName = TrimString(row.PlacementNameField.GetText() or "");
        if (placementName == "") then
            alert("Every row needs a placement name");
            return;
        end

        table.insert(placements, { Type = row.TypeDropdown.GetKey(), TerritoryName = territoryName, PlacementName = placementName });
    end

    Mod.Settings.PlaceholderPlacements = placements;
    Mod.Settings.IsPlanningMode = PlaceholderConfigureState.IsPlanningModeCheckBox.GetIsChecked();
end
