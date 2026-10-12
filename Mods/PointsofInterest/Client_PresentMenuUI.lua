require("Utilities");

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(500, 470.
);
    setScrollable(false, true);

    MenuGame = game;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Placement Planning Mode").SetColor(SUBHEADING_COLOUR);

    if (not Mod.Settings.IsPlanningMode) then
        UI.CreateLabel(vert).SetText("Used for planning mode. Nothing here to see...").SetColor(BUTTON_COLOURS.DarkGray);
        return;
    end

    UI.CreateLabel(vert).SetText("You can queue build orders to place POIs on to the map.");

    if (game.Us == nil) then
        UI.CreateLabel(vert).SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    local options = {};
    for _, name in ipairs(NATO_NAMES) do
        if (IsPoIEnabled(name)) then
            table.insert(options, { Key = name, Text = name });
        end
    end

    if (#options == 0) then
        UI.CreateLabel(vert).SetText("Enable at least one POI in the mod config first.").SetColor(ERROR_COLOUR);
        return;
    end

    local initialKey = options[1].Key;

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    MenuVisibilityLabel = UI.CreateLabel(vert);
    MenuStructureDropDown = CreateDropDown(horz, options, initialKey, function(name)
        local visibility = GetConfiguredVisibility(name);
        MenuVisibilityLabel.SetText("POI Visibility: " .. GetVisibilityText(visibility)).SetColor(GetPoIStateColor(visibility));
    end);

    local initialVisibility = GetConfiguredVisibility(initialKey);
    MenuVisibilityLabel.SetText("POI Visibility: " .. GetVisibilityText(initialVisibility)).SetColor(GetPoIStateColor(initialVisibility));

    MenuTargetTerritoryBtn = UI.CreateButton(horz)
        .SetText("Create Build Order")
        .SetOnClick(MenuTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);

    UI.CreateEmpty(vert).SetPreferredHeight(10);

    ---- Extract Placement Configuration
    UI.CreateLabel(vert).SetText('Export Placement Configuration').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(vert).SetText("You can export the placement data from the POIs currently on the map and also include queued build orders.");
    UI.CreateLabel(vert).SetText("Copy the exported data and paste it into the mod config's Placement Configuration field to use it in future games.");

    local extractHorz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    UI.CreateButton(extractHorz)
        .SetText("Config from Map")
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetFlexibleWidth(1)
        .SetOnClick(function()
            MenuExtractedConfigField.SetText(SerializePlacementData(GetPlacementsFromMap(game)));
        end);
    UI.CreateButton(extractHorz)
        .SetText("Config from Map + Queued Orders")
        .SetColor(BUTTON_COLOURS.RoyalBlue)
        .SetFlexibleWidth(1)
        .SetOnClick(function()
            local placements = GetPlacementsFromMap(game);
            for _, placement in ipairs(GetQueuedOrderPlacements(game)) do
                table.insert(placements, placement);
            end
            MenuExtractedConfigField.SetText(SerializePlacementData(placements));
        end);

    MenuExtractedConfigField = UI.CreateTextInputField(vert)
        .SetPlaceholderText("Copy exported placement data...")
        .SetMultiLine(true)
        .SetPreferredHeight(100)
        .SetFlexibleWidth(1);
end

--Scans every territory on the map for NATO POI structures already built on it (one placement entry per structure
--instance, so a territory with two Alphas on it yields two Alpha entries) - "Config from Map". Reads structure IDs
--from Mod.PublicGameData.StructureIDs rather than calling WL.StructureType.Custom itself - that can only be called
--from a server hook (it throws "modContext.Token.ModExecuting is null" from client code), so Server_StartGame
--publishes them there instead - see PointsOfInterestApplication.PublishStructureIDs
---@param game GameClientHook
---@return PointsOfInterestPlacementSetting[]
function GetPlacementsFromMap(game)
    local placements = {};
    local structureIDs = (Mod.PublicGameData --[[@as PointsOfInterestPublicGameData]]).StructureIDs or {};

    for territoryID, territoryStanding in pairs(game.LatestStanding.Territories) do
        local structures = territoryStanding.Structures;
        if (structures ~= nil) then
            local territoryName = game.Map.Territories[territoryID].Name;
            for _, name in ipairs(NATO_NAMES) do
                local structureID = structureIDs[name];
                local count = (structureID ~= nil and structures[structureID]) or 0;
                for _ = 1, count do
                    table.insert(placements, { Name = name, TerritoryName = territoryName });
                end
            end
        end
    end
    return placements;
end

--Scans the player's current (not yet processed) order list for queued Points of Interest build orders, for
--"Config from Map + Queued Orders" - these haven't reached LatestStanding yet, so GetPlacementsFromMap misses them
---@param game GameClientHook
---@return PointsOfInterestPlacementSetting[]
function GetQueuedOrderPlacements(game)
    local placements = {};
    for _, order in ipairs(game.Orders) do
        if (order.proxyType == 'GameOrderCustom') then
            ---@cast order GameOrderCustom
            local name, territoryID = ParseBuildPayload(order.Payload);
            if (name ~= nil) then
                table.insert(placements, { Name = name, TerritoryName = game.Map.Territories[territoryID].Name });
            end
        end
    end
    return placements;
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

    MenuGame.HighlightTerritories({ terrDetails.ID });
end
