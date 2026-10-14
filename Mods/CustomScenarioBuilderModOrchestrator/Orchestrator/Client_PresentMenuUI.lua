require("Utilities");

---Client_PresentMenuUI hook
---@param rootParent RootParent
---@param setMaxSize fun(width: number, height: number) # Sets the max size of the dialog
---@param setScrollable fun(horizontallyScrollable: boolean, verticallyScrollable: boolean) # Set whether the dialog is scrollable both horizontal and vertically
---@param game GameClientHook
---@param close fun() # Zero parameter function that closes the dialog
function Client_PresentMenuUI(rootParent, setMaxSize, setScrollable, game, close)
    setMaxSize(500, 470);
    setScrollable(false, true);

    MenuGame = game;

    local vert = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(vert).SetText("Placeholder Planning Mode").SetColor(SUBHEADING_COLOUR);

    if (not Mod.Settings.IsPlanningMode) then
        UI.CreateLabel(vert).SetText("Used for planning mode. Nothing here to see...").SetColor(BUTTON_COLOURS.DarkGray);
        return;
    end

    UI.CreateLabel(vert).SetText("You can place a vanilla structure on a territory as a visual marker, then export the map's layout into a Placeholder Placement config.");

    if (game.Us == nil) then
        UI.CreateLabel(vert).SetText("Spectators can't create orders.").SetColor(ERROR_COLOUR);
        return;
    end

    local options = {};
    for _, entry in ipairs(VANILLA_STRUCTURE_TYPES) do
        table.insert(options, { Key = entry.Name, Text = entry.Name });
    end

    local horz = UI.CreateHorizontalLayoutGroup(vert).SetFlexibleWidth(1);
    MenuStructureDropDown = CreateDropDown(horz, options, options[1].Key, nil);
    MenuTargetTerritoryBtn = UI.CreateButton(horz)
        .SetText("Create Build Order")
        .SetOnClick(MenuTargetTerritoryClicked)
        .SetFlexibleWidth(1)
        .SetColor(BUTTON_COLOURS.DarkGreen);

    UI.CreateEmpty(vert).SetPreferredHeight(10);

    ---- Extract Placement Configuration
    UI.CreateLabel(vert).SetText('Export Placement Configuration').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(vert).SetText("Exports every structure CSBMO recognizes (vanilla structures only - a custom structure from another mod has no name once placed) and every custom special unit currently on the map, by its own name.");
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

--Scans every territory on the map for existing structures and custom special units, exporting one placement entry
--per instance - "Config from Map". Structures: only vanilla types CSBMO knows the name of (see
--VANILLA_STRUCTURE_TYPES/PublishVanillaStructureNames) can be identified this way, since a custom structure from
--another mod has no accessible name once placed, only an opaque type ID. Special units: any CustomSpecialUnit's
--own Name field is readable directly, regardless of which mod created it.
---@param game GameClientHook
---@return PlaceholderPlacementSetting[]
function GetPlacementsFromMap(game)
    local vanillaStructureNames = (Mod.PublicGameData or {}).VanillaStructureNames or {};
    local placements = {};

    for territoryID, territoryStanding in pairs(game.LatestStanding.Territories) do
        local territoryName = game.Map.Territories[territoryID].Name;

        for structureID, count in pairs(territoryStanding.Structures or {}) do
            local structureName = vanillaStructureNames[structureID];
            if (structureName ~= nil) then
                for _ = 1, count do
                    table.insert(placements, { Type = "Structure", PlacementName = structureName, TerritoryName = territoryName });
                end
            end
        end

        for _, specialUnit in ipairs(territoryStanding.NumArmies.SpecialUnits or {}) do
            if (specialUnit.Name ~= nil) then
                table.insert(placements, { Type = "SpecialUnit", PlacementName = specialUnit.Name, TerritoryName = territoryName });
            end
        end
    end

    return placements;
end

--Scans the player's current (not yet processed) order list for queued Planning Mode build orders, for
--"Config from Map + Queued Orders" - these haven't reached LatestStanding yet, so GetPlacementsFromMap misses them
---@param game GameClientHook
---@return PlaceholderPlacementSetting[]
function GetQueuedOrderPlacements(game)
    local placements = {};
    for _, order in ipairs(game.Orders) do
        if (order.proxyType == 'GameOrderCustom') then
            ---@cast order GameOrderCustom
            local structureName, territoryID = ParsePlanningPayload(order.Payload);
            if (structureName ~= nil) then
                table.insert(placements, { Type = "Structure", PlacementName = structureName, TerritoryName = game.Map.Territories[territoryID].Name });
            end
        end
    end
    return placements;
end

--- Initiate territory selection for building the selected vanilla structure
function MenuTargetTerritoryClicked()
    MenuTargetTerritoryBtn.SetInteractable(false);
    UI.InterceptNextTerritoryClick(MenuTerritoryClicked);
end

-- Territory on click callback. Any territory is valid: ownership and visibility don't matter for planning markers
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

    local structureName = MenuStructureDropDown.GetKey();
    local order = WL.GameOrderCustom.Create(
        MenuGame.Us.ID,
        "Place " .. structureName .. " on " .. terrDetails.Name,
        BuildPlanningPayload(structureName, terrDetails.ID),
        nil,
        WL.TurnPhase.Attacks);

    -- Re-assign rather than mutate in place: Orders is a snapshot, so table.insert on the value returned by
    -- MenuGame.Orders alone wouldn't persist the new order back to the game.
    local orders = MenuGame.Orders;
    table.insert(orders, order);
    MenuGame.Orders = orders;

    MenuGame.HighlightTerritories({ terrDetails.ID });
end
