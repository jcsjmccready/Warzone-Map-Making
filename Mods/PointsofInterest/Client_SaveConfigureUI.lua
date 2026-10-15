require("Utilities");

---Client_SaveConfigureUI hook
---@param alert fun(message: string) # Alert the player that something is wrong, for example, when a setting is not configured correctly. When invoked, cancels the player from saving and returning
---@param addCard fun(name: string, description: string, filename: string, piecesForWholeCard: integer, piecesPerTurn: integer, initialPieces: integer, cardWeight: number, duration: integer | nil, expireBehaviour: ActiveCardExpireBehaviorOptions): CardID
function Client_SaveConfigureUI(alert, addCard)
    Mod.Settings.Version = CURRENT_SETTINGS_VERSION;

    local enabled = {};
    local visibility = {};
    for _, name in ipairs(NATO_NAMES) do
        local key = PoIConfigureState.StateDropDowns[name].GetKey();
        enabled[name] = key ~= "Disabled";
        visibility[name] = (key ~= "Disabled") and key or DEFAULT_VISIBILITY;
    end

    ---@type PointsOfInterestPlacementSetting[]
    local placements = {};
    for _, row in ipairs(PoIConfigureState.PlacementRows) do
        local territoryName = row.TerritoryField.GetText() or "";
        if (territoryName == "") then
            alert("Every Territory POI Placement row needs a territory name");
            return;
        end
        table.insert(placements, { Name = row.Dropdown.GetKey(), TerritoryName = territoryName });
    end

    Mod.Settings.PoIEnabled = enabled;
    Mod.Settings.PoIVisibility = visibility;
    Mod.Settings.PoIPlacements = placements;
    Mod.Settings.IsPlanningMode = PoIConfigureState.IsPlanningModeCheckBox.GetIsChecked();
end
