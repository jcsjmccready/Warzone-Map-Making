require("Utilities");

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(500, 400);
    setScrollable(false, true);

    MenuGame = game;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Points of Interest").SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(vert).SetText("Placed on any territory, free of charge. Belongs to the whole lobby and cannot be removed.").SetColor(BUTTON_COLOURS.DarkGray);

    if (game.Us == nil) then
        UI.CreateLabel(vert).SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    local options = {};
    for _, name in ipairs(NATO_NAMES) do
        table.insert(options, { Key = name, Text = name });
    end

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateLabel(horz).SetText("Structure:").SetMinWidth(40);
    MenuVisibilityLabel = UI.CreateLabel(vert).SetColor(BUTTON_COLOURS.DarkGray);
    MenuStructureDropDown = CreateDropDown(horz, options, NATO_NAMES[1], function(name)
        MenuVisibilityLabel.SetText("Visibility: " .. GetVisibilityText(GetConfiguredVisibility(name)));
    end);
    MenuVisibilityLabel.SetText("Visibility: " .. GetVisibilityText(GetConfiguredVisibility(NATO_NAMES[1])));

    MenuTargetTerritoryBtn = UI.CreateButton(vert)
        .SetText("Build on Territory")
        .SetOnClick(MenuTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);

    MenuAllTargetTerritoryBtn = UI.CreateButton(vert)
        .SetText("Build All Letters on Territory")
        .SetOnClick(MenuAllTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);
end

--Builds a free build order for name on territoryID
---@param name string
---@param territoryID TerritoryID
---@param territoryName string
---@return GameOrderCustom
function CreateBuildOrder(name, territoryID, territoryName)
    return WL.GameOrderCustom.Create(
        MenuGame.Us.ID,
        "Build " .. name .. " on " .. territoryName,
        PAYLOAD_PREFIX .. name .. "_" .. territoryID,
        nil,
        WL.TurnPhase.Attacks);
end

--- Initiate territory selection for building the selected letter
function MenuTargetTerritoryClicked()
    MenuGame.HighlightTerritories({}); --clear any territories highlighted from a previous selection
    MenuTargetTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(MenuTerritoryClicked);
end

-- Territory on click callback. Any territory is valid: ownership and visibility don't matter for Points of Interest
---@param terrDetails TerritoryDetailsVM | nil
function MenuTerritoryClicked(terrDetails)
    if UI.IsDestroyed(MenuTargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    MenuTargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Let the player try again.
        return;
    end

    local name = MenuStructureDropDown.GetKey();
    local order = CreateBuildOrder(name, terrDetails.ID, terrDetails.Name);

    -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
    -- MenuGame.Orders alone wouldn't persist the new order back to the game.
    local orders = MenuGame.Orders;
    table.insert(orders, order);
    MenuGame.Orders = orders;

    MenuGame.HighlightTerritories({});
end

--- Initiate territory selection for building every NATO letter on one territory
function MenuAllTargetTerritoryClicked()
    MenuGame.HighlightTerritories({});
    MenuAllTargetTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(MenuAllTerritoryClicked);
end

-- Territory on click callback for the "build all" button. Queues one build order per NATO letter.
---@param terrDetails TerritoryDetailsVM | nil
function MenuAllTerritoryClicked(terrDetails)
    if UI.IsDestroyed(MenuAllTargetTerritoryBtn) then
        -- Dialog was destroyed, so we don't need to intercept the click anymore
        return WL.CancelClickIntercept;
    end

    MenuAllTargetTerritoryBtn.SetInteractable(true);

    if (terrDetails == nil) then
        --The click request was cancelled. Let the player try again.
        return;
    end

    local orders = MenuGame.Orders;
    for _, name in ipairs(NATO_NAMES) do
        table.insert(orders, CreateBuildOrder(name, terrDetails.ID, terrDetails.Name));
    end
    MenuGame.Orders = orders;

    MenuGame.HighlightTerritories({});
end
