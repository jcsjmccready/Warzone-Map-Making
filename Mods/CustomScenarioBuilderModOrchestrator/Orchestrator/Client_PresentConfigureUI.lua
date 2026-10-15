require("Utilities");
require("Templates");

---@class PlacementConfigureUIState
---@field Placements PlaceholderPlacementSetting[]
---@field IsPlanningModeValue boolean # cached from the checkbox on change, since the checkbox itself may be destroyed (page navigated away) by the time Client_SaveConfigureUI reads this back
---@field NavContainer UIObject | nil # stable parent, created once
---@field NavContent UIObject | nil # destroyable, recreated by RenderNav every page change - the two Placement Mode/Planning Mode buttons, whichever is for the current page reading "Return" instead
---@field PageContainer UIObject | nil # stable parent, created once
---@field PageContent UIObject | nil # destroyable, recreated every ShowHomePage/ShowPlacementPage/ShowPlanningPage call
---@field ViewContainer UIObject | nil # stable parent (inside the Placement page), created once per ShowPlacementPage call
---@field ViewContent UIObject | nil # destroyable, recreated every ShowListView/ShowEditView call
---@field EditingIndex integer | nil # which State.Placements entry the Edit view is editing; nil while adding a new one
---@field EditExisting PlaceholderPlacementSetting | nil # the placement (or template prefill) the Edit view's fields were seeded from
---@field EditIsFromTemplate boolean # true when adding a new placement via "Add from Template" - hides the Structure ID field, since templates are always vanilla structures
---@field EditTypeDropdown table | nil # CreateDropDown's return value
---@field EditTerritoryField TextInputField | nil
---@field EditPlacementNameField TextInputField | nil
---@field EditFieldsParent UIObject | nil # stable parent for EditTypeFieldsContainer
---@field EditTypeFieldsContainer UIObject | nil # destroyable, rebuilt whenever Type changes
---@field EditStructureIDField TextInputField | nil # Type=Structure only
---@field EditSpecialUnitFieldControls table<string, table> # Type=SpecialUnit only: SPECIAL_UNIT_FIELD_DESCRIPTORS key -> its control
---@field EditStatusLabel Label | nil
---@field IsPlanningModeCheckBox CheckBox | nil
---@field PlanningModeContainer UIObject | nil # stable parent (inside the Planning page), created once per ShowPlanningPage call
---@field PlanningModeHeading UIObject | nil # the destroyable wrapper holding the paste box + button, nil while Is Planning Mode is unchecked
---@field PlanningDataField TextInputField | nil
---@field OverwriteStatusLabel Label | nil
---@field OverwriteConfigBtn Button | nil
---@field ConfirmContainer UIObject | nil
---@field ConfirmHeading UIObject | nil # the destroyable Yes/No prompt, nil while not confirming
---@field IsConfirmPending boolean # blocks re-triggering the button while ConfirmHeading is already showing
---@field IsPromptFromListOpen boolean # blocks opening a second UI.PromptFromList while one is already showing
---@field ShowHomePage fun() | nil
---@field ShowPlacementPage fun() | nil
---@field ShowPlanningPage fun() | nil
---@field ShowListView fun() | nil
---@field ShowEditView fun(index: integer | nil, prefill: PlaceholderPlacementSetting | nil, isFromTemplate: boolean | nil) | nil

---@type PlacementConfigureUIState
local State = {
    Placements = {},
    IsPlanningModeValue = false,
    EditIsFromTemplate = false,
    EditSpecialUnitFieldControls = {},
    IsConfirmPending = false,
    IsPromptFromListOpen = false,
};

---UI.Destroy's signature doesn't accept nil (unlike UI.IsDestroyed, which explicitly does) - calling it with a
---not-yet-created object crashes with a native NullReferenceException rather than a Lua-level error. Every
---destroyable container here starts out nil before its first render, so every UI.Destroy call goes through this.
---@param object UIObject | nil
local function DestroyIfExists(object)
    if (object ~= nil) then
        UI.Destroy(object);
    end
end

---Wraps UI.PromptFromList so a second one can't be opened on top of an already-showing one (e.g. a double click),
---and so IsPromptFromListOpen is cleared again once an option is actually picked.
---@param message string
---@param options ListOption[]
local function ShowPromptFromList(message, options)
    if (State.IsPromptFromListOpen) then return; end
    State.IsPromptFromListOpen = true;

    local wrappedOptions = {};
    for _, option in ipairs(options) do
        table.insert(wrappedOptions, {
            text = option.text,
            selected = function()
                State.IsPromptFromListOpen = false;
                option.selected();
            end,
        });
    end

    UI.PromptFromList(message, wrappedOptions);
end

---Rebuilds the persistent nav row for whichever page is now showing - on Home, the Placement Mode/Planning Mode
---buttons; on either of those pages, just a single Return button back to Home.
---@param currentPage "Home" | "Placement" | "Planning"
local function RenderNav(currentPage)
    DestroyIfExists(State.NavContent);
    State.NavContent = UI.CreateHorizontalLayoutGroup(State.NavContainer).SetFlexibleWidth(1);

    if (currentPage == "Home") then
        UI.CreateButton(State.NavContent)
            .SetText("Placement Mode")
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetOnClick(function() State.ShowPlacementPage(); end);

        UI.CreateButton(State.NavContent)
            .SetText("Planning Mode")
            .SetColor(BUTTON_COLOURS.RoyalBlue)
            .SetFlexibleWidth(1)
            .SetOnClick(function() State.ShowPlanningPage(); end);
    else
        UI.CreateButton(State.NavContent)
            .SetText("Return")
            .SetColor(BUTTON_COLOURS.TyrianPurple)
            .SetFlexibleWidth(1)
            .SetOnClick(function() State.ShowHomePage(); end);
    end
end

---Rebuilds the Edit view's Type-specific fields section (Structure's StructureID field, or one control per
---SPECIAL_UNIT_FIELD_DESCRIPTORS entry for a SpecialUnit) - called on open and whenever Type changes
local function RenderEditTypeFields()
    DestroyIfExists(State.EditTypeFieldsContainer);
    State.EditTypeFieldsContainer = UI.CreateVerticalLayoutGroup(State.EditFieldsParent).SetFlexibleWidth(1);
    State.EditStructureIDField = nil;
    State.EditSpecialUnitFieldControls = {};

    local typeKey = State.EditTypeDropdown.GetKey();
    local existing = State.EditExisting;

    if (typeKey == "Structure" and not State.EditIsFromTemplate) then
        UI.CreateLabel(State.EditTypeFieldsContainer).SetText("Structure ID (c|ModId|StructureName)");
        State.EditStructureIDField = UI.CreateTextInputField(State.EditTypeFieldsContainer)
            .SetPlaceholderText("Empty if vanilla structure")
            .SetText((existing ~= nil and existing.StructureID) or "")
            .SetInteractable(false)
            .SetFlexibleWidth(1);
    elseif (typeKey ~= "Structure") then
        for _, descriptor in ipairs(SPECIAL_UNIT_FIELD_DESCRIPTORS) do
            local existingValue = (existing ~= nil and existing.SpecialUnitFields ~= nil) and existing.SpecialUnitFields[descriptor.Key] or nil;

            local fieldRow = UI.CreateHorizontalLayoutGroup(State.EditTypeFieldsContainer).SetFlexibleWidth(1);
            UI.CreateLabel(fieldRow).SetText(HumanizePascalCase(descriptor.Key)).SetPreferredWidth(PLACEMENT_NAME_FIELD_WIDTH).SetMinWidth(0).SetFlexibleWidth(0);

            if (descriptor.Type == "boolean") then
                State.EditSpecialUnitFieldControls[descriptor.Key] =
                UI.CreateCheckBox(fieldRow)
                    .SetText("")
                    .SetIsChecked(existingValue == "true");

            elseif (descriptor.Type == "integer" or descriptor.Type == "number") then
                local numberField = 
                UI.CreateNumberInputField(fieldRow)
                    .SetWholeNumbers(descriptor.Type == "integer")
                    .SetFlexibleWidth(1);

                numberField.SetValue(tonumber(existingValue) or 0);
                State.EditSpecialUnitFieldControls[descriptor.Key] = numberField;
            else
                State.EditSpecialUnitFieldControls[descriptor.Key] =
                UI.CreateTextInputField(fieldRow)
                    .SetText(existingValue or "")
                    .SetMultiLine(descriptor.Key == "ModData")
                    .SetPreferredHeight((descriptor.Key == "ModData") and 100 or -1)
                    .SetFlexibleWidth(1);
            end
        end
    end
end

---Reads the Edit view's current controls into a plain PlaceholderPlacementSetting. Returns nil + an error message
---if Territory Name/Placement Name are blank.
---@return PlaceholderPlacementSetting | nil placement
---@return string | nil errorMessage
local function BuildPlacementFromEditState()
    local territoryName = TrimString(State.EditTerritoryField.GetText() or "");
    if (territoryName == "") then return nil, "Every row needs a territory name"; end

    local placementName = TrimString(State.EditPlacementNameField.GetText() or "");
    if (placementName == "") then return nil, "Every row needs a placement name"; end

    local typeKey = State.EditTypeDropdown.GetKey();
    ---@type PlaceholderPlacementSetting
    local placement = { Type = typeKey, TerritoryName = territoryName, PlacementName = placementName };

    if (typeKey == "Structure") then
        if (State.EditStructureIDField ~= nil) then
            local structureID = TrimString(State.EditStructureIDField.GetText() or "");
            placement.StructureID = (structureID ~= "") and structureID or nil;
        end
    else
        local fields = {};
        for _, descriptor in ipairs(SPECIAL_UNIT_FIELD_DESCRIPTORS) do
            local control = State.EditSpecialUnitFieldControls[descriptor.Key];
            if (descriptor.Type == "boolean") then
                fields[descriptor.Key] = tostring(control.GetIsChecked());
            elseif (descriptor.Type == "integer" or descriptor.Type == "number") then
                fields[descriptor.Key] = tostring(control.GetValue());
            else
                local text = control.GetText();
                if (text ~= nil and text ~= "") then fields[descriptor.Key] = text; end
            end
        end
        placement.SpecialUnitFields = fields;
    end

    return placement, nil;
end

---Re-applies whether the overwrite button should be interactable - text-driven, but never while a confirm is pending
local function UpdateOverwriteButtonInteractable()
    local text = State.PlanningDataField.GetText();
    State.OverwriteConfigBtn.SetInteractable(not State.IsConfirmPending and text ~= nil and text ~= "");
end

---Actually overwrites the placement list from the pasted data - only called once the player confirms
local function DoOverwritePlacementConfiguration()
    local placements = DeserializePlacementData(State.PlanningDataField.GetText());
    if (placements == nil) then
        State.OverwriteStatusLabel.SetText("Couldn't read that data").SetColor(ERROR_COLOUR);
        return;
    end

    State.Placements = placements;
    State.ShowPlacementPage();
end

---Builds the paste box and its overwrite button, shown while Is Planning Mode is checked
local function Create_PlanningModeUI()
    State.PlanningModeHeading = UI.CreateVerticalLayoutGroup(State.PlanningModeContainer).SetFlexibleWidth(1);

    State.PlanningDataField = UI.CreateTextInputField(State.PlanningModeHeading)
        .SetPlaceholderText("Paste to import placement data")
        .SetMultiLine(true)
        .SetPreferredHeight(100)
        .SetFlexibleWidth(1);

    State.OverwriteStatusLabel = UI.CreateLabel(State.PlanningModeHeading).SetText("");

    State.OverwriteConfigBtn = UI.CreateButton(State.PlanningModeHeading)
        .SetText("Overwrite Placement Configuration")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetFlexibleWidth(1)
        .SetInteractable(false);

    -- No dialog/modal API is available in this hook, so the confirmation is an inline Yes/No row that replaces
    -- itself with the result, instead of a floating popup
    State.ConfirmContainer = UI.CreateVerticalLayoutGroup(State.PlanningModeHeading).SetFlexibleWidth(1);
    State.IsConfirmPending = false;

    State.PlanningDataField.SetOnValueChanged(UpdateOverwriteButtonInteractable);

    State.OverwriteConfigBtn.SetOnClick(function()
        State.IsConfirmPending = true;
        UpdateOverwriteButtonInteractable();

        State.ConfirmHeading = UI.CreateVerticalLayoutGroup(State.ConfirmContainer).SetFlexibleWidth(1);
        UI.CreateLabel(State.ConfirmHeading).SetText("This will overwrite the current placement configuration. Are you sure?");

        local confirmHorz = UI.CreateHorizontalLayoutGroup(State.ConfirmHeading).SetFlexibleWidth(1);
        UI.CreateButton(confirmHorz)
            .SetText("Yes")
            .SetColor(BUTTON_COLOURS.DarkGreen)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                DestroyIfExists(State.ConfirmHeading);
                State.IsConfirmPending = false;
                UpdateOverwriteButtonInteractable();
                DoOverwritePlacementConfiguration();
            end);
        UI.CreateButton(confirmHorz)
            .SetText("No")
            .SetColor(BUTTON_COLOURS.TyrianPurple)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                DestroyIfExists(State.ConfirmHeading);
                State.IsConfirmPending = false;
                UpdateOverwriteButtonInteractable();
            end);
    end);
end

State.ShowListView = function()
    DestroyIfExists(State.ViewContent);
    State.ViewContent = UI.CreateVerticalLayoutGroup(State.ViewContainer).SetFlexibleWidth(1);

    local addRowHorz = UI.CreateHorizontalLayoutGroup(State.ViewContent).SetFlexibleWidth(1);
    UI.CreateButton(addRowHorz)
        .SetText("Add Row")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetPreferredWidth(0)
        .SetMinWidth(0)
        .SetFlexibleWidth(1)
        .SetOnClick(function() State.ShowEditView(nil, nil); end);

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
                    selected = function()
                        State.ShowEditView(nil, { Type = template.Type, PlacementName = template.PlacementName, TerritoryName = "" }, true);
                    end,
                });
            end
            ShowPromptFromList("Select a template", list);
        end);

    local headerHorz = UI.CreateHorizontalLayoutGroup(State.ViewContent).SetFlexibleWidth(1);
    UI.CreateLabel(headerHorz).SetText("Placement Name").SetColor(BUTTON_COLOURS.Artichoke).SetPreferredWidth(0).SetMinWidth(0).SetFlexibleWidth(1);
    UI.CreateLabel(headerHorz).SetText("Territory Name").SetColor(BUTTON_COLOURS.Artichoke).SetPreferredWidth(0).SetMinWidth(0).SetFlexibleWidth(1);
    UI.CreateEmpty(headerHorz).SetPreferredWidth(40).SetMinWidth(0).SetFlexibleWidth(0);
    UI.CreateEmpty(headerHorz).SetPreferredWidth(40).SetMinWidth(0).SetFlexibleWidth(0);

    for index, placement in ipairs(State.Placements) do
        local rowHorz = UI.CreateHorizontalLayoutGroup(State.ViewContent).SetFlexibleWidth(1);

        UI.CreateLabel(rowHorz).SetText(placement.PlacementName or "").SetPreferredWidth(0).SetMinWidth(0).SetFlexibleWidth(1);
        UI.CreateLabel(rowHorz).SetText(placement.TerritoryName or "").SetPreferredWidth(0).SetMinWidth(0).SetFlexibleWidth(1);

        UI.CreateImage(rowHorz)
            .SetSprite((placement.Type == "Structure") and ICON_STRUCTURE or ICON_SPECIAL_UNIT)
            .SetPreferredWidth(LIST_VIEW_ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(LIST_VIEW_ICON_SIZE).SetMinHeight(0);

        local originIcon = ICON_VANILLA;
        if (placement.Type == "SpecialUnit" or IsModdedStructure(placement)) then
            originIcon = ICON_MODDED;
        end
        UI.CreateImage(rowHorz).SetSprite(originIcon).SetPreferredWidth(LIST_VIEW_ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(LIST_VIEW_ICON_SIZE).SetMinHeight(0);

        if (PlacementHasBuiltInSupport(placement)) then
            UI.CreateImage(rowHorz).SetSprite(ICON_BUILT_IN_SUPPORT).SetPreferredWidth(LIST_VIEW_ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(LIST_VIEW_ICON_SIZE).SetMinHeight(0);
        end

        if (PlacementHasData(placement)) then
            UI.CreateImage(rowHorz).SetSprite(ICON_HAS_DATA).SetPreferredWidth(LIST_VIEW_ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(LIST_VIEW_ICON_SIZE).SetMinHeight(0);
        end

        UI.CreateButton(rowHorz)
            .SetText("")
            .SetIcon(ICON_EDIT)
            .SetIconPreferredWidth(ICON_SIZE).SetIconMinWidth(0)
            .SetIconPreferredHeight(ICON_SIZE).SetIconMinHeight(0)
            .SetColor(BUTTON_COLOURS.RoyalBlue)
            .SetPreferredWidth(40).SetMinWidth(0).SetFlexibleWidth(0)
            .SetPreferredHeight(30).SetMinHeight(0)
            .SetOnClick(function() State.ShowEditView(index); end);
    end
end

---@param index integer | nil # nil when adding a new placement
---@param prefill PlaceholderPlacementSetting | nil # used only when index is nil (e.g. from a template)
---@param isFromTemplate boolean | nil # true when prefill came from "Add from Template" - hides the Structure ID field
State.ShowEditView = function(index, prefill, isFromTemplate)
    State.EditingIndex = index;
    State.EditExisting = (index ~= nil) and State.Placements[index] or prefill;
    State.EditIsFromTemplate = isFromTemplate == true;

    DestroyIfExists(State.ViewContent);
    State.ViewContent = UI.CreateVerticalLayoutGroup(State.ViewContainer).SetFlexibleWidth(1);

    UI.CreateLabel(State.ViewContent).SetText((index ~= nil) and "Edit Placement" or "Add Placement");

    State.EditTypeDropdown = CreateDropDown(State.ViewContent, PLACEMENT_TYPE_OPTIONS, (State.EditExisting ~= nil and State.EditExisting.Type) or DEFAULT_PLACEMENT_TYPE, function(key)
        State.EditTypeDropdown.Button.SetColor(GetPlacementTypeColor(key));
        RenderEditTypeFields();
    end);
    State.EditTypeDropdown.Button.SetColor(GetPlacementTypeColor((State.EditExisting ~= nil and State.EditExisting.Type) or DEFAULT_PLACEMENT_TYPE));
    State.EditTypeDropdown.Button.SetInteractable(not State.EditIsFromTemplate and index == nil); -- templates are always Structure, and an existing row can't change Type after the fact, so Type can't be changed away from it

    State.EditTerritoryField = UI.CreateTextInputField(State.ViewContent)
        .SetPlaceholderText("Territory Name")
        .SetText((State.EditExisting ~= nil and State.EditExisting.TerritoryName) or "")
        .SetFlexibleWidth(1);

    -- An existing modded structure's name came from its StructureID (parsed out on import), not typed by hand, so
    -- it can't be changed independently of it - unlike a vanilla structure, which is matched by this name alone
    local isExistingModdedStructure = index ~= nil and State.EditExisting ~= nil and State.EditExisting.Type == "Structure" and State.EditExisting.StructureID ~= nil;

    State.EditPlacementNameField = UI.CreateTextInputField(State.ViewContent)
        .SetPlaceholderText("Placement Name")
        .SetText((State.EditExisting ~= nil and State.EditExisting.PlacementName) or "")
        .SetInteractable(not isExistingModdedStructure)
        .SetFlexibleWidth(1);

    State.EditFieldsParent = UI.CreateVerticalLayoutGroup(State.ViewContent).SetFlexibleWidth(1);
    RenderEditTypeFields();

    State.EditStatusLabel = UI.CreateLabel(State.ViewContent).SetText("");

    if (index ~= nil) then
        local deleteHorz = UI.CreateHorizontalLayoutGroup(State.ViewContent).SetFlexibleWidth(1);
        UI.CreateButton(deleteHorz)
            .SetText("Delete")
            .SetColor(BUTTON_COLOURS.Red)
            .SetFlexibleWidth(1)
            .SetOnClick(function()
                ShowPromptFromList("Delete this placement?", {
                    { text = "Delete", selected = function()
                        table.remove(State.Placements, index);
                        State.ShowListView();
                    end },
                    { text = "Cancel", selected = function() end },
                });
            end);
    end

    local buttonsHorz = UI.CreateHorizontalLayoutGroup(State.ViewContent).SetFlexibleWidth(1);
    UI.CreateButton(buttonsHorz)
        .SetText("Save")
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetFlexibleWidth(1)
        .SetOnClick(function()
            local placement, errorMessage = BuildPlacementFromEditState();
            if (placement == nil) then
                State.EditStatusLabel.SetText(errorMessage or "").SetColor(ERROR_COLOUR);
                return;
            end

            if (State.EditingIndex ~= nil) then
                State.Placements[State.EditingIndex] = placement;
            else
                table.insert(State.Placements, placement);
            end
            State.ShowListView();
        end);
    UI.CreateButton(buttonsHorz)
        .SetText("Cancel")
        .SetColor(BUTTON_COLOURS.TyrianPurple)
        .SetFlexibleWidth(1)
        .SetOnClick(function() State.ShowListView(); end);
end

State.ShowHomePage = function()
    RenderNav("Home");

    DestroyIfExists(State.PageContent);
    State.PageContent = UI.CreateVerticalLayoutGroup(State.PageContainer).SetFlexibleWidth(1);

    UI.CreateLabel(State.PageContent).SetText('Configure structures/special units to place on the map at the start of the game, or use Planning Mode to lay them out visually in a test game first.');

    UI.CreateLabel(State.PageContent).SetText(#State.Placements .. " placement" .. (#State.Placements == 1 and "" or "s") .. " configured").SetColor(SUBHEADING_COLOUR2);

    UI.CreateEmpty(State.PageContent).SetPreferredHeight(10);

    UI.CreateLabel(State.PageContent).SetText('Icon Glossary');

    local typeRow = UI.CreateHorizontalLayoutGroup(State.PageContent).SetFlexibleWidth(1);
    UI.CreateImage(typeRow).SetSprite(ICON_STRUCTURE).SetPreferredWidth(ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(ICON_SIZE).SetMinHeight(0);
    UI.CreateImage(typeRow).SetSprite(ICON_SPECIAL_UNIT).SetPreferredWidth(ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(ICON_SIZE).SetMinHeight(0);
    UI.CreateLabel(typeRow).SetText("The row represents a Structure or a Special Unit").SetFlexibleWidth(1);

    local originRow = UI.CreateHorizontalLayoutGroup(State.PageContent).SetFlexibleWidth(1);
    UI.CreateImage(originRow).SetSprite(ICON_VANILLA).SetPreferredWidth(ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(ICON_SIZE).SetMinHeight(0);
    UI.CreateImage(originRow).SetSprite(ICON_MODDED).SetPreferredWidth(ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(ICON_SIZE).SetMinHeight(0);
    UI.CreateLabel(originRow).SetText("A built-in vanilla structure, or a modded structure/special unit").SetFlexibleWidth(1);

    local supportRow = UI.CreateHorizontalLayoutGroup(State.PageContent).SetFlexibleWidth(1);
    UI.CreateImage(supportRow).SetSprite(ICON_BUILT_IN_SUPPORT).SetPreferredWidth(ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(ICON_SIZE).SetMinHeight(0);
    UI.CreateEmpty(supportRow).SetPreferredWidth(44).SetMinWidth(ICON_SIZE).SetFlexibleWidth(0);
    UI.CreateLabel(supportRow).SetText("Built-in Support - guaranteed to place with no issues. Without this, we require other mods to support this mod").SetFlexibleWidth(1);

    local dataRow = UI.CreateHorizontalLayoutGroup(State.PageContent).SetFlexibleWidth(1);
    UI.CreateImage(dataRow).SetSprite(ICON_HAS_DATA).SetPreferredWidth(ICON_SIZE).SetMinWidth(0).SetFlexibleWidth(0).SetPreferredHeight(ICON_SIZE).SetMinHeight(0);
    UI.CreateEmpty(dataRow).SetPreferredWidth(22).SetMinWidth(ICON_SIZE).SetFlexibleWidth(0);
    UI.CreateLabel(dataRow).SetText("Has extra recreation data, such as special unit strength").SetFlexibleWidth(1);
end

State.ShowPlacementPage = function()
    RenderNav("Placement");

    DestroyIfExists(State.PageContent);
    State.PageContent = UI.CreateVerticalLayoutGroup(State.PageContainer).SetFlexibleWidth(1);

    UI.CreateLabel(State.PageContent).SetText('Structure/Special Unit Placement');
    UI.CreateLabel(State.PageContent).SetText('Each row places a special unit/structure on the named territory at the start of the game.');
    UI.CreateLabel(State.PageContent).SetText('Placement Name must match the name of the desired special unit/structure, and Territory Name must match the name of a territory on the map.');

    UI.CreateEmpty(State.PageContent).SetPreferredHeight(10);

    State.ViewContainer = UI.CreateVerticalLayoutGroup(State.PageContent).SetFlexibleWidth(1);
    State.ViewContent = nil;
    State.ShowListView();
end

State.ShowPlanningPage = function()
    RenderNav("Planning");

    DestroyIfExists(State.PageContent);
    State.PageContent = UI.CreateVerticalLayoutGroup(State.PageContainer).SetFlexibleWidth(1);

    UI.CreateLabel(State.PageContent).SetText('Planning Mode');
    UI.CreateLabel(State.PageContent).SetText('Planning mode is a convenience option, providing an alternative method of entering where to place structures/special units on the map.');
    UI.CreateLabel(State.PageContent).SetText('When enabled, launch into a game and using the mod-menu in the bottom left, export the placement data. Then return to this config and paste the data into the text box below.');
    UI.CreateLabel(State.PageContent).SetText('Additionally, using the mod-menu you can place vanilla structures on the map.');
    UI.CreateLabel(State.PageContent).SetText('Clicking the overwrite button will replace your existing placement configuration.');

    State.IsPlanningModeCheckBox = UI.CreateCheckBox(State.PageContent).SetText('Is Planning Mode').SetIsChecked(State.IsPlanningModeValue);
    State.PlanningModeContainer = UI.CreateVerticalLayoutGroup(State.PageContent).SetFlexibleWidth(1);
    State.PlanningModeHeading = nil;

    State.IsPlanningModeCheckBox.SetOnValueChanged(function()
        State.IsPlanningModeValue = State.IsPlanningModeCheckBox.GetIsChecked();
        if (State.IsPlanningModeValue) then
            Create_PlanningModeUI();
        else
            DestroyIfExists(State.PlanningModeHeading);
        end
    end);

    if (State.IsPlanningModeValue) then
        Create_PlanningModeUI();
    end
end

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    State.Placements = {};
    for _, placement in ipairs(Mod.Settings.PlaceholderPlacements or {}) do
        table.insert(State.Placements, placement);
    end
    State.IsPlanningModeValue = Mod.Settings.IsPlanningMode or false;
    State.NavContainer = nil;
    State.NavContent = nil;
    State.PageContainer = nil;
    State.PageContent = nil;
    State.ViewContainer = nil;
    State.ViewContent = nil;
    State.EditingIndex = nil;
    State.EditExisting = nil;
    State.IsPlanningModeCheckBox = nil;
    State.PlanningModeContainer = nil;
    State.PlanningModeHeading = nil;
    State.PlanningDataField = nil;
    State.OverwriteStatusLabel = nil;
    State.OverwriteConfigBtn = nil;
    State.ConfirmContainer = nil;
    State.ConfirmHeading = nil;
    State.IsConfirmPending = false;

    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    -- Permanent header - never destroyed/hidden by page navigation, unlike everything below it
    UI.CreateLabel(mainModUI).SetText('Custom Scenario Builder (Mod Support)');
    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    State.NavContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);
    State.PageContainer = UI.CreateVerticalLayoutGroup(mainModUI).SetFlexibleWidth(1);
    if (#State.Placements > 0) then
        State.ShowPlacementPage();
    else
        State.ShowHomePage();
    end

    -- Client_SaveConfigureUI reads this back once the player saves. Points at State itself (not a copy) so
    -- State.Placements/State.IsPlanningModeValue stay live even after later page navigation.
    PlaceholderConfigureState = State;
end
