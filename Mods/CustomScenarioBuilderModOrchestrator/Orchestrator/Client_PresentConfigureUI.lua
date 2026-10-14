require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local placementRowsContainer; -- forward declared, AddPlacementRow below needs to close over it before it's created
    local placementRows = {}; -- { Container, TypeDropdown, PlacementNameField, TerritoryField }

    ---Removes a placement row from the UI and from the rows list
    ---@param row table
    local function RemovePlacementRow(row)
        for i, candidate in ipairs(placementRows) do
            if (candidate == row) then
                table.remove(placementRows, i);
                break;
            end
        end
        UI.Destroy(row.Container);
    end

    ---Adds a new placement row
    ---@param defaultType string | nil
    ---@param defaultPlacementName string | nil
    ---@param defaultTerritoryName string | nil
    local function AddPlacementRow(defaultType, defaultPlacementName, defaultTerritoryName)
        local rowHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);

        local typeDropdown = CreateDropDown(rowHorz, PLACEMENT_TYPE_OPTIONS, defaultType or DEFAULT_PLACEMENT_TYPE, nil);
        typeDropdown.Button.SetPreferredWidth(110).SetMinWidth(0).SetFlexibleWidth(0);

        local placementNameField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Placement Name (optional)")
            .SetText(defaultPlacementName or "")
            .SetPreferredWidth(0)
            .SetMinWidth(0)
            .SetFlexibleWidth(1);

        local territoryField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Territory Name")
            .SetText(defaultTerritoryName or "")
            .SetPreferredWidth(0)
            .SetMinWidth(0)
            .SetFlexibleWidth(1);

        local row = { Container = rowHorz, TypeDropdown = typeDropdown, PlacementNameField = placementNameField, TerritoryField = territoryField };

        UI.CreateButton(rowHorz)
            .SetText("X")
            .SetColor(BUTTON_COLOURS.Red)
            .SetPreferredWidth(40)
            .SetMinWidth(0)
            .SetFlexibleWidth(0)
            .SetOnClick(function() RemovePlacementRow(row); end);

        table.insert(placementRows, row);
    end

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    ---- Placeholder Placement
    UI.CreateLabel(mainModUI).SetText('Placeholder Placement').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('Each row places a Placeholder special unit on the named territory at the start of the game.');
    UI.CreateLabel(mainModUI).SetText('Placeholders stand in for a structure or special unit from another mod. Type and Placement Name are just for your own tracking - every placement is placed as the same Placeholder special unit either way, until resolving it to the real thing is supported.');

    -- The header row is added as the first child of placementRowsContainer, below, rather than as a sibling of it -
    -- that way it shares the exact same layout context as the rows and its columns line up with theirs
    placementRowsContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);

    local headerHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);
    UI.CreateLabel(headerHorz).SetText("Type").SetAlignment(WL.TextAlignmentOptions.Center)
        .SetPreferredWidth(110)
        .SetMinWidth(0)
        .SetFlexibleWidth(0);

    UI.CreateLabel(headerHorz).SetText("Placement Name").SetAlignment(WL.TextAlignmentOptions.Left)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1);

    UI.CreateLabel(headerHorz).SetText("Territory Name").SetAlignment(WL.TextAlignmentOptions.Left)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1);

    UI.CreateButton(headerHorz)
        .SetText("+")
        .SetPreferredWidth(40)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function() AddPlacementRow(nil, nil, nil); end);

    for _, placement in ipairs(Mod.Settings.PlaceholderPlacements or {}) do
        AddPlacementRow(placement.Type, placement.PlacementName, placement.TerritoryName);
    end

    -- Client_SaveConfigureUI reads this back once the player saves
    PlaceholderConfigureState = {
        PlacementRows = placementRows,
    };
end
