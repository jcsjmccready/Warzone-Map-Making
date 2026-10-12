require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local poiStateDropDowns = {}; -- name -> dropdown wrapper (see CreateDropDown), key is one of POI_STATE_OPTIONS

    local placementRowsContainer; -- forward declared, AddPlacementRow below needs to close over it before it's created
    local placementStatusLabel; -- forward declared, AddPlacementRow below needs to close over it before it's created
    local addPlacementBtn; -- forward declared, the POI Config dropdowns below need to close over it before it's created
    local placementRows = {}; -- { Container, Dropdown, TerritoryField }

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
    end

    ---Destroys every current placement row, leaving the list empty
    local function ClearPlacementRows()
        for i = #placementRows, 1, -1 do
            UI.Destroy(placementRows[i].Container);
            table.remove(placementRows, i);
        end
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

        local row; -- forward declared, the delete button below needs to close over it before it's created

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

        row = { Container = rowHorz, Dropdown = dropdown, TerritoryField = territoryField };

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

    ---- POI Config
    UI.CreateLabel(mainModUI).SetText('POI Config').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('You can enable/disable the POIs in this section, as well as configure if they modify the fog level on the territory they are on.');

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
    UI.CreateLabel(mainModUI).SetText('Each row places one POI on the named territory at the start of the game.');
    UI.CreateLabel(mainModUI).SetText('Structures are ordered alphabetically on territories.');
    UI.CreateLabel(mainModUI).SetText('POIs with conflicting fog levels on the same territory will be resolved in the order they are placed, with the first one taking effect.');

    placementStatusLabel = UI.CreateLabel(mainModUI).SetText("");

    -- The header row is added as the first child of placementRowsContainer, below, rather than as a sibling of it -
    -- that way it shares the exact same layout context as the rows and its columns line up with theirs
    placementRowsContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);

    local headerHorz = UI.CreateHorizontalLayoutGroup(placementRowsContainer).SetFlexibleWidth(1);
    UI.CreateLabel(headerHorz).SetText("POI").SetAlignment(WL.TextAlignmentOptions.Center)
    .SetPreferredWidth(120)
    .SetMinWidth(0)
    .SetFlexibleWidth(0);

    UI.CreateLabel(headerHorz).SetText("Territory Name").SetAlignment(WL.TextAlignmentOptions.Left)
    .SetPreferredWidth(0)
    .SetMinWidth(0)
    .SetFlexibleWidth(1);

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

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    ---- Planning
    UI.CreateLabel(mainModUI).SetText('Planning Mode').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('Planning mode lets a game-maker place POIs in game and then import the placement data into the mod config.');
    UI.CreateLabel(mainModUI).SetText('When enabled, the in-game mod menu in the bottom left lets you place configured POIs.');
    UI.CreateLabel(mainModUI).SetText('You can then export the placement data, copy it, exit the game/return to this config and paste the data into the text box below.');
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

        ---Actually overwrites the placement rows from the pasted data - only called once the player confirms
        local function DoOverwritePlacementConfiguration()
            local placements = DeserializePlacementData(planningDataField.GetText());
            if (placements == nil) then
                overwriteStatusLabel.SetText("Couldn't read that data: " .. IO.Reader.GetError()).SetColor(ERROR_COLOUR);
                return;
            end

            ClearPlacementRows();
            local skippedCount = 0;
            for _, placement in ipairs(placements) do
                if (IsPoIEnabled(placement.Name)) then
                    AddPlacementRow(placement.Name, placement.TerritoryName);
                else
                    skippedCount = skippedCount + 1;
                end
            end

            local message = "Placement configuration overwritten with " .. #placementRows .. " entr" .. (#placementRows == 1 and "y" or "ies") .. ".";
            if (skippedCount > 0) then
                message = message .. " Skipped " .. skippedCount .. " for a disabled POI.";
            end
            overwriteStatusLabel.SetText(message);
        end

        planningDataField.SetOnValueChanged(function()
            local text = planningDataField.GetText();
            overwriteConfigBtn.SetInteractable(text ~= nil and text ~= "");
        end);

        overwriteConfigBtn.SetOnClick(function()
            overwriteConfigBtn.SetInteractable(false);

            confirmHeading = UI.CreateVerticalLayoutGroup(confirmContainer).SetFlexibleWidth(1);
            UI.CreateLabel(confirmHeading).SetText("This will overwrite the current placement configuration. Are you sure?");

            local confirmHorz = UI.CreateHorizontalLayoutGroup(confirmHeading).SetFlexibleWidth(1);
            UI.CreateButton(confirmHorz)
                .SetText("Yes")
                .SetColor(BUTTON_COLOURS.DarkGreen)
                .SetFlexibleWidth(1)
                .SetOnClick(function()
                    UI.Destroy(confirmHeading);
                    overwriteConfigBtn.SetInteractable(true);
                    DoOverwritePlacementConfiguration();
                end);
            UI.CreateButton(confirmHorz)
                .SetText("No")
                .SetColor(BUTTON_COLOURS.Red)
                .SetFlexibleWidth(1)
                .SetOnClick(function()
                    UI.Destroy(confirmHeading);
                    overwriteConfigBtn.SetInteractable(true);
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
    PoIConfigureState = {
        StateDropDowns = poiStateDropDowns,
        PlacementRows = placementRows,
        IsPlanningModeCheckBox = isPlanningModeCheckBox,
    };
end
