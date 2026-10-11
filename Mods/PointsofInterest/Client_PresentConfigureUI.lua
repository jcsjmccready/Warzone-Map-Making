require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local poiStateDropDowns = {}; -- name -> dropdown wrapper (see CreateDropDown), key is one of POI_STATE_OPTIONS

    local placementRowsContainer; -- forward declared, AddPlacementRow below needs to close over it before it's created
    local placementStatusLabel; -- forward declared, AddPlacementRow below needs to close over it before it's created
    local addPlacementBtn; -- forward declared, the POI Config dropdowns below need to close over it before it's created
    local placementRows = {}; -- { Container, Dropdown, TerritoryField, MoveDownBtn }

    ---Builds the {Key,Text} option list of currently-enabled POIs, for the placement row dropdowns
    ---@return { Key: string, Text: string }[]
    local function GetEnabledOptions()
        local options = {};
        for _, name in ipairs(NATO_NAMES) do
            if (poiStateDropDowns[name].GetKey() ~= "Disabled") then
                table.insert(options, { Key = name, Text = name });
            end
        end
        return options;
    end

    ---Greys out the add-placement button whenever no POI is currently enabled
    local function UpdateAddPlacementButtonState()
        addPlacementBtn.SetInteractable(#GetEnabledOptions() > 0);
    end

    ---Disables each row's move-down button once it's the last row, since there's nothing below it to swap with
    local function UpdateMoveButtonStates()
        for i, row in ipairs(placementRows) do
            row.MoveDownBtn.SetInteractable(i < #placementRows);
        end
    end

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
        UpdateMoveButtonStates();
    end

    ---Removes every placement row whose POI is name - called when that POI gets disabled above, since its rows would
    ---otherwise be left pointing at a POI no one can select anymore
    ---@param name string
    local function RemovePlacementRowsFor(name)
        for i = #placementRows, 1, -1 do
            if (placementRows[i].Dropdown.GetKey() == name) then
                UI.Destroy(placementRows[i].Container);
                table.remove(placementRows, i);
            end
        end
        UpdateMoveButtonStates();
    end

    ---Moves the row at index down one place in the list. Rows never actually reorder in the UI - there's no API for
    ---that - instead the two adjacent rows swap their POI and territory name values, which has the same effect
    ---@param index integer
    local function SwapPlacementRowsDown(index)
        local rowA = placementRows[index];
        local rowB = placementRows[index + 1];
        if (rowA == nil or rowB == nil) then return; end;

        local keyA = rowA.Dropdown.GetKey();
        local keyB = rowB.Dropdown.GetKey();
        rowA.Dropdown.SetKey(keyB);
        rowB.Dropdown.SetKey(keyA);
        rowA.Dropdown.Button.SetColor(GetPoIStateColor(poiStateDropDowns[keyB].GetKey()));
        rowB.Dropdown.Button.SetColor(GetPoIStateColor(poiStateDropDowns[keyA].GetKey()));

        local territoryA = rowA.TerritoryField.GetText();
        local territoryB = rowB.TerritoryField.GetText();
        rowA.TerritoryField.SetText(territoryB);
        rowB.TerritoryField.SetText(territoryA);
    end

    ---Re-colours every placement row currently showing name, to match its (possibly just-changed) fog level
    ---@param name string
    local function RefreshPlacementRowColorsFor(name)
        local color = GetPoIStateColor(poiStateDropDowns[name].GetKey());
        for _, row in ipairs(placementRows) do
            if (row.Dropdown.GetKey() == name) then
                row.Dropdown.Button.SetColor(color);
            end
        end
    end

    ---Adds a new placement row. defaultName is kept only if it's still an enabled POI, otherwise falls back to
    ---whichever enabled POI sorts first
    ---@param defaultName string | nil
    ---@param defaultTerritoryName string | nil
    local function AddPlacementRow(defaultName, defaultTerritoryName)
        local options = GetEnabledOptions();
        if (#options == 0) then
            placementStatusLabel.SetText("Enable at least one POI above before adding a placement.").SetColor(ERROR_COLOUR);
            return;
        end
        placementStatusLabel.SetText("");

        local initialKey = (defaultName ~= nil and OptionsContainKey(options, defaultName)) and defaultName or options[1].Key;

        local rowHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);

        local row; -- forward declared, the move-down button below needs to close over it before it's created
        local moveDownBtn = UI.CreateButton(rowHorz)
            .SetText("V")
            .SetPreferredWidth(40)
            .SetMinWidth(0)
            .SetFlexibleWidth(0)
            .SetColor(BUTTON_COLOURS.RoyalBlue)
            .SetOnClick(function()
                for i, candidate in ipairs(placementRows) do
                    if (candidate == row) then
                        SwapPlacementRowsDown(i);
                        break;
                    end
                end
            end);

        -- GetEnabledOptions itself, not a snapshot, so the row's dropdown always offers whatever is enabled at the
        -- time it's opened, even if a POI is enabled/disabled after this row was created
        local dropdown; -- forward declared, its own onChanged below needs to close over it before it's created
        dropdown = CreateDropDown(rowHorz, GetEnabledOptions, initialKey, function(key)
            dropdown.Button.SetColor(GetPoIStateColor(poiStateDropDowns[key].GetKey()));
        end);
        dropdown.Button.SetPreferredWidth(120).SetMinWidth(0).SetFlexibleWidth(0);
        dropdown.Button.SetColor(GetPoIStateColor(poiStateDropDowns[initialKey].GetKey()));

        local territoryField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Territory Name")
            .SetText(defaultTerritoryName or "")
            .SetPreferredWidth(0)
            .SetMinWidth(0)
            .SetFlexibleWidth(1);

        row = { Container = rowHorz, Dropdown = dropdown, TerritoryField = territoryField, MoveDownBtn = moveDownBtn };

        UI.CreateButton(rowHorz)
            .SetText("X")
            .SetColor(BUTTON_COLOURS.Red)
            .SetPreferredWidth(40)
            .SetMinWidth(0)
            .SetFlexibleWidth(0)
            .SetOnClick(function() RemovePlacementRow(row); end);

        table.insert(placementRows, row);
        UpdateMoveButtonStates();
    end

    ---- POI Config
    UI.CreateLabel(mainModUI).SetText('POI Config').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('If multiple POIs with conflicting fog levels end up on the same territory, No Fog takes priority over Heavy Fog.').SetColor(BUTTON_COLOURS.DarkGray);

    -- Two columns side by side (first half of the alphabet, then the second) so this section doesn't take up
    -- as much vertical space with all 26 letters
    local columnsHorz = UI.CreateHorizontalLayoutGroup(mainModUI).SetFlexibleWidth(1);
    local leftColumn = UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1);
    local rightColumn = UI.CreateVerticalLayoutGroup(columnsHorz).SetFlexibleWidth(1);
    local halfwayIndex = math.ceil(#NATO_NAMES / 2);

    for i, name in ipairs(NATO_NAMES) do
        local column = (i <= halfwayIndex) and leftColumn or rightColumn;
        local row = UI.CreateHorizontalLayoutGroup(column);
        UI.CreateLabel(row).SetText(name).SetPreferredWidth(80);

        local initialKey = IsPoIEnabled(name) and GetConfiguredVisibility(name) or "Disabled";

        local dropdown; -- forward declared, its own onChanged below needs to close over it before it's created
        dropdown = CreateDropDown(row, POI_STATE_OPTIONS, initialKey, function(key)
            dropdown.Button.SetColor(GetPoIStateColor(key));
            if (key == "Disabled") then
                RemovePlacementRowsFor(name);
            else
                RefreshPlacementRowColorsFor(name);
            end
            UpdateAddPlacementButtonState();
        end);
        dropdown.Button.SetPreferredWidth(110).SetMinWidth(0).SetFlexibleWidth(0);
        dropdown.Button.SetColor(GetPoIStateColor(initialKey));
        poiStateDropDowns[name] = dropdown;
    end

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    ---- Territory POI Placement
    UI.CreateLabel(mainModUI).SetText('Territory POI Placement').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('Each row places one POI on the named territory at the start of the game.').SetColor(BUTTON_COLOURS.DarkGray);
    UI.CreateLabel(mainModUI).SetText('Multiple of the same POI can exist on the same territory.').SetColor(BUTTON_COLOURS.DarkGray);

    placementStatusLabel = UI.CreateLabel(mainModUI).SetText("");

    -- The header row is added as the first child of placementRowsContainer, below, rather than as a sibling of it -
    -- that way it shares the exact same layout context as the rows and its columns line up with theirs
    placementRowsContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);

    local headerHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);
    UI.CreateEmpty(headerHorz).SetPreferredWidth(40).SetMinWidth(0).SetFlexibleWidth(0); -- lines up with each row's move-down button
    UI.CreateLabel(headerHorz).SetText("POI").SetColor(TEXT_DEFAULT_COLOUR).SetAlignment(WL.TextAlignmentOptions.Center).SetPreferredWidth(120).SetMinWidth(0).SetFlexibleWidth(0);
    UI.CreateLabel(headerHorz).SetText("Territory Name").SetColor(TEXT_DEFAULT_COLOUR).SetAlignment(WL.TextAlignmentOptions.Left).SetPreferredWidth(0).SetMinWidth(0).SetFlexibleWidth(1);
    addPlacementBtn = UI.CreateButton(headerHorz)
        .SetText("+")
        .SetPreferredWidth(40)
        .SetMinWidth(0)
        .SetFlexibleWidth(0)
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function() AddPlacementRow(nil, nil); end);
    UpdateAddPlacementButtonState();

    for _, placement in ipairs(Mod.Settings.PoIPlacements or {}) do
        if (IsPoIEnabled(placement.Name)) then
            AddPlacementRow(placement.Name, placement.TerritoryName);
        end
    end

    -- Client_SaveConfigureUI reads this back once the player saves
    PoIConfigureState = {
        StateDropDowns = poiStateDropDowns,
        PlacementRows = placementRows,
    };
end
