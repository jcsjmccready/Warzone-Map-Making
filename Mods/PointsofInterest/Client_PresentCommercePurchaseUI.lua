require("Utilities");

---@param rootParent RootParent
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentCommercePurchaseUI(rootParent, game, close)
    CommerceGame = game;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(horz).SetText("Point of Interest").SetColor(BUTTON_COLOURS.Yellow).SetMinWidth(40);
    UI.CreateLabel(horz).SetText("Placed on any territory. Belongs to the whole lobby and cannot be removed");

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(horz).SetText("Cost: " .. (Mod.Settings.PoICost or 0) .. " gold").SetColor(BUTTON_COLOURS.Bronze);

    local options = {};
    for _, name in ipairs(NATO_NAMES) do
        table.insert(options, { Key = name, Text = name });
    end

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(horz).SetText("Structure:").SetMinWidth(40);
    CommerceVisibilityLabel = UI.CreateLabel(vert).SetColor(BUTTON_COLOURS.DarkGray);
    CommerceStructureDropDown = CreateDropDown(horz, options, NATO_NAMES[1], function(name)
        CommerceVisibilityLabel.SetText("Visibility: " .. GetVisibilityText(GetConfiguredVisibility(name)));
    end);
    CommerceVisibilityLabel.SetText("Visibility: " .. GetVisibilityText(GetConfiguredVisibility(NATO_NAMES[1])));

    CommerceTargetTerritoryBtn = UI.CreateButton(vert)
        .SetText("Build on Territory")
        .SetOnClick(CommerceTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);
end

--- Initiate territory selection for the purchase
function CommerceTargetTerritoryClicked()
    CommerceGame.HighlightTerritories({}); --clear any territories highlighted from a previous selection
    CommerceTargetTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(CommerceTerritoryClicked);
end

-- Territory on click callback. Any territory is valid: ownership and visibility don't matter for Points of Interest
---@param terrDetails TerritoryDetailsVM | nil
function CommerceTerritoryClicked(terrDetails)
    if UI.IsDestroyed(CommerceTargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    CommerceTargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Let the player try again.
        return;
    end

    local name = CommerceStructureDropDown.GetKey();
    local order = WL.GameOrderCustom.Create(
        CommerceGame.Us.ID,
        "Build " .. name .. " on " .. terrDetails.Name,
        PAYLOAD_PREFIX .. name .. "_" .. terrDetails.ID,
        { [WL.ResourceType.Gold] = Mod.Settings.PoICost or 0 },
        WL.TurnPhase.Attacks);

    -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
    -- CommerceGame.Orders alone wouldn't persist the new order back to the game.
    local orders = CommerceGame.Orders;
    table.insert(orders, order);
    CommerceGame.Orders = orders;

    CommerceGame.HighlightTerritories({});
end
