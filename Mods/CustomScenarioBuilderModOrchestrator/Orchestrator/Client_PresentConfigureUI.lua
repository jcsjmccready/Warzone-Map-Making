require("Utilities");
require("Templates");

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

    ---Destroys every current placement row, leaving the list empty - used when Planning Mode's imported data
    ---overwrites the existing configuration
    local function ClearPlacementRows()
        for i = #placementRows, 1, -1 do
            UI.Destroy(placementRows[i].Container);
            table.remove(placementRows, i);
        end
    end

    ---Adds a new placement row
    ---@param defaultType string | nil
    ---@param defaultPlacementName string | nil
    ---@param defaultTerritoryName string | nil
    local function AddPlacementRow(defaultType, defaultPlacementName, defaultTerritoryName)
        local rowHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);

        local typeDropdown; -- forward declared, its own onChanged below needs to close over it before it's created
        typeDropdown = CreateDropDown(rowHorz, PLACEMENT_TYPE_DROPDOWN_OPTIONS, defaultType or DEFAULT_PLACEMENT_TYPE, function(key)
            typeDropdown.Button.SetColor(GetPlacementTypeColor(key));
        end);
        typeDropdown.Button.SetPreferredWidth(TYPE_FIELD_WIDTH).SetMinWidth(0).SetFlexibleWidth(0);
        typeDropdown.Button.SetColor(GetPlacementTypeColor(defaultType or DEFAULT_PLACEMENT_TYPE));

        local placementNameField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Placement Name")
            .SetText(defaultPlacementName or "")
            .SetPreferredWidth(PLACEMENT_NAME_FIELD_WIDTH)
            .SetMinWidth(0)
            .SetFlexibleWidth(0);

        local territoryField = UI.CreateTextInputField(rowHorz)
            .SetPlaceholderText("Territory Name")
            .SetText(defaultTerritoryName or "")
            .SetPreferredWidth(TERRITORY_NAME_FIELD_WIDTH)
            .SetMinWidth(0)
            .SetFlexibleWidth(0);

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
    UI.CreateLabel(mainModUI).SetText('Structure/Special Unit Placement').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('Each row places a special unit/structure on the named territory at the start of the game.');
    UI.CreateLabel(mainModUI).SetText('Placement Name must match the name of the desired special unlike unit/structure, and Territory Name must match the name of a territory on the map.');

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    local addRowHorz = UI.CreateHorizontalLayoutGroup(mainModUI).SetFlexibleWidth(1);
    UI.CreateButton(addRowHorz)
        .SetText("Add Row")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1)
        .SetOnClick(function() AddPlacementRow(nil, nil, nil); end);

    UI.CreateButton(addRowHorz)
        .SetText("Add from Template")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1)
        .SetOnClick(function()
            local list = {};
            for _, template in ipairs(PLACEMENT_TEMPLATES) do
                table.insert(list, {
                    text = template.Text,
                    selected = function() AddPlacementRow(template.Type, template.PlacementName, nil); end,
                });
            end
            UI.PromptFromList("Select a template", list);
        end);

    -- The header row is added as the first child of placementRowsContainer, below, rather than as a sibling of it -
    -- that way it shares the exact same layout context as the rows and its columns line up with theirs
    placementRowsContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);

    local headerHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);
    UI.CreateLabel(headerHorz).SetText("Type").SetAlignment(WL.TextAlignmentOptions.Center)
        .SetPreferredWidth(TYPE_FIELD_WIDTH)
        .SetMinWidth(0)
        .SetFlexibleWidth(0);

    UI.CreateLabel(headerHorz).SetText("Placement Name")
    .SetAlignment(WL.TextAlignmentOptions.Left)
        .SetPreferredWidth(PLACEMENT_NAME_FIELD_WIDTH)
        .SetMinWidth(0)
        .SetFlexibleWidth(0);

    UI.CreateLabel(headerHorz).SetText("Territory Name")
    .SetAlignment(WL.TextAlignmentOptions.Left)
        .SetPreferredWidth(TERRITORY_NAME_FIELD_WIDTH)
        .SetMinWidth(0)
        .SetFlexibleWidth(0);

    for _, placement in ipairs(Mod.Settings.PlaceholderPlacements or {}) do
        AddPlacementRow(placement.Type, placement.PlacementName, placement.TerritoryName);
    end

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    ---- Planning
    UI.CreateLabel(mainModUI).SetText('Planning Mode').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('Planning mode is a convenience option, providing an alternative method of entering where to place structures/special units on the map.');
    UI.CreateLabel(mainModUI).SetText('When enabled, launch into a game and using the mod-menu in the bottom left, export the placement data. Then return to this config and paste the data into the text box below.');
    UI.CreateLabel(mainModUI).SetText('Additionally, using the mod-menu you can place vanilla structures on the map.');
    UI.CreateLabel(mainModUI).SetText('Clicking the overwrite button will replace your existing placement configuration.');

    local planningModeHeading; -- the destroyable wrapper holding the paste box + button, nil while Is Planning Mode is unchecked

    local isPlanningModeCheckBox = UI.CreateCheckBox(mainModUI).SetText('Is Planning Mode').SetIsChecked(Mod.Settings.IsPlanningMode or false);
    local planningModeContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);

    ---Builds the paste box and its overwrite button, shown while Is Planning Mode is checked
    local function Create_PlanningModeUI()
        planningModeHeading = UI.CreateVerticalLayoutGroup(planningModeContainer).SetFlexibleWidth(1);

        local planningDataField = UI.CreateTextInputField(planningModeHeading)
            .SetPlaceholderText("Paste to import placement data")
            .SetMultiLine(true)
            .SetPreferredHeight(100)
            .SetFlexibleWidth(1);

        local overwriteStatusLabel = UI.CreateLabel(planningModeHeading).SetText("");

        local overwriteConfigBtn = UI.CreateButton(planningModeHeading)
            .SetText("Overwrite Placement Configuration")
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetInteractable(false);

        -- No dialog/modal API is available in this hook, so the confirmation is an inline Yes/No row that replaces
        -- itself with the result, instead of a floating popup
        local confirmContainer = UI.CreateVerticalLayoutGroup(planningModeHeading).SetFlexibleWidth(1);
        local confirmHeading; -- the destroyable Yes/No prompt, nil while not confirming
        local isConfirmPending = false; -- blocks re-triggering the button while confirmHeading is already showing

        ---Actually overwrites the placement rows from the pasted data - only called once the player confirms
        local function DoOverwritePlacementConfiguration()
            local placements = DeserializePlacementData(planningDataField.GetText());
            if (placements == nil) then
                overwriteStatusLabel.SetText("Couldn't read that data").SetColor(ERROR_COLOUR);
                return;
            end

            ClearPlacementRows();
            for _, placement in ipairs(placements) do
                AddPlacementRow(placement.Type, placement.PlacementName, placement.TerritoryName);
            end

            overwriteStatusLabel.SetText("Placement configuration overwritten with " .. #placementRows .. " entr" .. (#placementRows == 1 and "y" or "ies") .. ".");
        end

        ---Re-applies whether the button should be interactable - text-driven, but never while a confirm is pending
        local function UpdateOverwriteButtonInteractable()
            local text = planningDataField.GetText();
            overwriteConfigBtn.SetInteractable(not isConfirmPending and text ~= nil and text ~= "");
        end

        planningDataField.SetOnValueChanged(UpdateOverwriteButtonInteractable);

        overwriteConfigBtn.SetOnClick(function()
            isConfirmPending = true;
            UpdateOverwriteButtonInteractable();

            confirmHeading = UI.CreateVerticalLayoutGroup(confirmContainer).SetFlexibleWidth(1);
            UI.CreateLabel(confirmHeading).SetText("This will overwrite the current placement configuration. Are you sure?");

            local confirmHorz = UI.CreateHorizontalLayoutGroup(confirmHeading).SetFlexibleWidth(1);
            UI.CreateButton(confirmHorz)
                .SetText("Yes")
                .SetColor(BUTTON_COLOURS.DarkGreen)
                .SetFlexibleWidth(1)
                .SetOnClick(function()
                    UI.Destroy(confirmHeading);
                    isConfirmPending = false;
                    UpdateOverwriteButtonInteractable();
                    DoOverwritePlacementConfiguration();
                end);
            UI.CreateButton(confirmHorz)
                .SetText("No")
                .SetColor(BUTTON_COLOURS.Red)
                .SetFlexibleWidth(1)
                .SetOnClick(function()
                    UI.Destroy(confirmHeading);
                    isConfirmPending = false;
                    UpdateOverwriteButtonInteractable();
                end);
        end);
    end

    isPlanningModeCheckBox.SetOnValueChanged(function()
        if (isPlanningModeCheckBox.GetIsChecked()) then
            Create_PlanningModeUI();
        else
            UI.Destroy(planningModeHeading);
        end
    end);

    -- one time check for loading up from settings
    if (isPlanningModeCheckBox.GetIsChecked()) then
        Create_PlanningModeUI();
    end

    -- Client_SaveConfigureUI reads this back once the player saves
    PlaceholderConfigureState = {
        PlacementRows = placementRows,
        IsPlanningModeCheckBox = isPlanningModeCheckBox,
    };
end
