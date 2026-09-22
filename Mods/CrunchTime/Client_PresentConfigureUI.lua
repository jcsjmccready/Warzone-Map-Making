require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---- Mode
    local modeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(modeHeading).SetText('Mode:').SetColor(SUBHEADING_COLOUR);
    local modeGroup = UI.CreateRadioButtonGroup(modeHeading);

    local advancedByDefault = (Mod.Settings.ConfigMode == "Advanced");

    local basicModeHeading = UI.CreateVerticalLayoutGroup(modeHeading);
    basicModeBtn = UI.CreateRadioButton(basicModeHeading).SetGroup(modeGroup).SetText('Basic').SetIsChecked(not advancedByDefault);

    local advancedModeHeading = UI.CreateVerticalLayoutGroup(modeHeading);
    advancedModeBtn = UI.CreateRadioButton(advancedModeHeading).SetGroup(modeGroup).SetText('Advanced').SetIsChecked(advancedByDefault);

    ---- Entry method
    local entryMethodHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(entryMethodHeading).SetText('Entry method:').SetColor(SUBHEADING_COLOUR);
    local entryMethodGroup = UI.CreateRadioButtonGroup(entryMethodHeading);

    local triggerTypeCardHeading = UI.CreateVerticalLayoutGroup(entryMethodHeading);
    triggerTypeCard = UI.CreateRadioButton(triggerTypeCardHeading)
    .SetGroup(entryMethodGroup)
    .SetText('Card')
    .SetIsChecked(Mod.Settings.TriggerTypeCard ~= false);

    triggerTypeCard.SetOnValueChanged(function()
        if (triggerTypeCard.GetIsChecked()) then
            Create_Card_SubOptions_UI(triggerTypeCardHeading);
            triggerTypeCard.SetInteractable(false);
        else
            UI.Destroy(cardOptionsHeading);
            triggerTypeCard.SetInteractable(true);
        end
    end);

    local triggerTypeMenuHeading = UI.CreateVerticalLayoutGroup(entryMethodHeading);
    triggerTypeMenu = UI.CreateRadioButton(triggerTypeMenuHeading)
    .SetGroup(entryMethodGroup)
    .SetText('Mod Menu')
    .SetIsChecked(Mod.Settings.TriggerTypeMenu or false);

    triggerTypeMenu.SetOnValueChanged(function()
        if (triggerTypeMenu.GetIsChecked()) then
            triggerTypeMenu.SetInteractable(false);
        else
            triggerTypeMenu.SetInteractable(true);
        end
    end);

    ---- Mode-specific content
    local modeContentParent = UI.CreateVerticalLayoutGroup(mainModUI);
    ModeContentHeading = UI.CreateVerticalLayoutGroup(modeContentParent);

    basicModeBtn.SetOnValueChanged(function()
        if (basicModeBtn.GetIsChecked()) then
            UI.Destroy(ModeContentHeading);
            ModeContentHeading = UI.CreateVerticalLayoutGroup(modeContentParent);
            Create_Basic_Mode_UI(ModeContentHeading);
        end
    end);

    advancedModeBtn.SetOnValueChanged(function()
        if (advancedModeBtn.GetIsChecked()) then
            UI.Destroy(ModeContentHeading);
            ModeContentHeading = UI.CreateVerticalLayoutGroup(modeContentParent);
            Create_Advanced_Mode_UI(ModeContentHeading);
        end
    end);

    -- one-time checks for loading up from settings
    if (triggerTypeCard.GetIsChecked()) then
        Create_Card_SubOptions_UI(triggerTypeCardHeading);
        triggerTypeCard.SetInteractable(false);
    end
    if (triggerTypeMenu.GetIsChecked()) then
        triggerTypeMenu.SetInteractable(false);
    end

    if (advancedByDefault) then
        Create_Advanced_Mode_UI(ModeContentHeading);
    else
        Create_Basic_Mode_UI(ModeContentHeading);
    end
end;

function Create_Card_SubOptions_UI(rootParent)
    cardOptionsHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz)
    .SetText('Number of Pieces to divide the card into')
    .SetPreferredWidth(290);

    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.NumPieces or 7);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz)
    .SetText('Card weight (how common the card is)')
    .SetPreferredWidth(290);

    cardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz)
    .SetText('Minimum pieces awarded per turn')
    .SetPreferredWidth(290);

    minPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.MinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz)
    .SetText('Pieces given to each player at the start')
    .SetPreferredWidth(290);

    initialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.InitialPieces or 1);
end;

------------------------------
-- Advanced mode: an arbitrary, ordered list of phases the map maker builds up directly
------------------------------

function Create_Advanced_Mode_UI(rootParent)
    ---- Phase order
    local phaseOrderHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(phaseOrderHeading).SetText('Phase order:').SetColor(SUBHEADING_COLOUR);

    phaseOrderPlayerSelected = UI.CreateCheckBox(phaseOrderHeading)
        .SetText('Let the player choose which phase to start on (otherwise always starts on phase 1)')
        .SetIsChecked(Mod.Settings.PhaseOrderPlayerSelected or false);

    ---- Duration mode (only meaningful when the player is choosing a starting phase, since that's the only point
    ---- they interact with an entry dialog where a duration could also be entered)
    local durationModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    DurationModeSettingsHeading = UI.CreateVerticalLayoutGroup(durationModeHeading);

    phaseOrderPlayerSelected.SetOnValueChanged(function()
        UI.Destroy(DurationModeSettingsHeading);
        DurationModeSettingsHeading = UI.CreateVerticalLayoutGroup(durationModeHeading);
        Create_DurationMode_UI(DurationModeSettingsHeading);
    end);

    ---- Phases
    local phasesHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(phasesHeading).SetText('Phases (at least 2 required):').SetColor(SUBHEADING_COLOUR);

    local phaseColumnHeadings = UI.CreateHorizontalLayoutGroup(phasesHeading);
    UI.CreateLabel(phaseColumnHeadings).SetText('Duration').SetPreferredWidth(90);
    UI.CreateEmpty(phaseColumnHeadings).SetPreferredWidth(70);
    UI.CreateLabel(phaseColumnHeadings).SetText('%').SetPreferredWidth(90);
    UI.CreateEmpty(phaseColumnHeadings).SetPreferredWidth(40);
    UI.CreateLabel(phaseColumnHeadings).SetText('Number').SetPreferredWidth(90);

    PhaseRowsHeading = UI.CreateVerticalLayoutGroup(phasesHeading);
    PhaseRows = {};

    if (Mod.Settings.Phases ~= nil and #Mod.Settings.Phases >= 2) then
        for _, row in ipairs(Mod.Settings.Phases) do
            Create_Phase_Row_UI(PhaseRowsHeading, row.Duration, row.Percent, row.FlatAmount);
        end
    else
        -- first-time defaults: reproduces the mod's original two-phase behaviour out of the box
        Create_Phase_Row_UI(PhaseRowsHeading, 3, 0.5, 3);
        Create_Phase_Row_UI(PhaseRowsHeading, 3, -0.3, -2);
    end

    UI.CreateButton(phasesHeading)
        .SetText('+ Add Phase')
        .SetColor(BUTTON_COLOURS.DarkGreen)
        .SetOnClick(function()
            Create_Phase_Row_UI(PhaseRowsHeading, 3, 0, 0);
        end);

    Create_DurationMode_UI(DurationModeSettingsHeading);
end;

--one row of the phase list: Duration/%/Number number fields plus a delete button. Removing a row below the
--2-phase minimum is blocked rather than silently allowed, since Client_SaveConfigureUI would just reject the save
function Create_Phase_Row_UI(rootParent, duration, percent, flatAmount)
    local row = UI.CreateHorizontalLayoutGroup(rootParent).SetFlexibleWidth(1);

    local durationField = UI.CreateNumberInputField(row)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(30)
        .SetValue(duration or 3)
        .SetPreferredWidth(90);

    local percentField = UI.CreateNumberInputField(row)
        .SetWholeNumbers(false)
        .SetSliderMinValue(-3.0)
        .SetSliderMaxValue(3.0)
        .SetValue(percent or 0)
        .SetPreferredWidth(90);

    local flatField = UI.CreateNumberInputField(row)
        .SetSliderMinValue(-50)
        .SetSliderMaxValue(50)
        .SetValue(flatAmount or 0)
        .SetPreferredWidth(90);

    local rowData = { Container = row, DurationField = durationField, PercentField = percentField, FlatField = flatField };

    UI.CreateButton(row)
        .SetText('X')
        .SetColor(BUTTON_COLOURS.Red)
        .SetOnClick(function()
            if (#PhaseRows <= 2) then
                UI.Alert('At least 2 phases are required');
                return;
            end

            for i, existingRow in ipairs(PhaseRows) do
                if (existingRow == rowData) then
                    table.remove(PhaseRows, i);
                    break;
                end
            end

            UI.Destroy(row);
        end);

    table.insert(PhaseRows, rowData);
end;

function Create_DurationMode_UI(rootParent)
    if (not phaseOrderPlayerSelected.GetIsChecked()) then
        -- no entry dialog choice to attach a duration field to - every phase always uses its own configured Duration
        userSpecifiedDuration = nil;
        return;
    end

    userSpecifiedDuration = UI.CreateCheckBox(rootParent)
        .SetText("Let the player choose a duration in-game (used for every phase instead of each phase's own Duration)")
        .SetIsChecked(Mod.Settings.UserSpecifiedDuration or false);

    UserSpecifiedDurationSettingsHeading = UI.CreateVerticalLayoutGroup(rootParent);

    userSpecifiedDuration.SetOnValueChanged(function()
        UI.Destroy(UserSpecifiedDurationSettingsHeading);
        UserSpecifiedDurationSettingsHeading = UI.CreateVerticalLayoutGroup(rootParent);
        Create_UserSpecifiedDuration_SubOptions_UI(UserSpecifiedDurationSettingsHeading);
    end);

    Create_UserSpecifiedDuration_SubOptions_UI(UserSpecifiedDurationSettingsHeading);
end;

function Create_UserSpecifiedDuration_SubOptions_UI(rootParent)
    if (not userSpecifiedDuration.GetIsChecked()) then return; end

    local horz = UI.CreateHorizontalLayoutGroup(rootParent);
    UI.CreateLabel(horz)
    .SetText('Maximum duration a player may choose')
    .SetPreferredWidth(290);

    maxUserSpecifiedDuration = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(30)
        .SetValue(Mod.Settings.MaxUserSpecifiedDuration or 5);
end;

------------------------------
-- Basic mode: the mod's original fixed two-phase (Crunch Time / Rest Time) UI, built on top of the same
-- Phases/PhaseOrderPlayerSelected settings Advanced mode uses - see Client_SaveConfigureUI.lua for how the two
-- checkboxes below map onto a 2-row Phases array and PhaseOrderPlayerSelected
------------------------------

function Create_Basic_Mode_UI(rootParent)
    -- best-effort defaults when switching back from Advanced-mode-produced settings: use the first row with a
    -- non-negative Percent as "Crunch Time" and the first with a negative Percent as "Rest Time"
    local increaseRowDefault = nil;
    local decreaseRowDefault = nil;
    if (Mod.Settings.Phases ~= nil) then
        for _, row in ipairs(Mod.Settings.Phases) do
            if (row.Percent >= 0 and increaseRowDefault == nil) then increaseRowDefault = row; end
            if (row.Percent < 0 and decreaseRowDefault == nil) then decreaseRowDefault = row; end
        end
    end

    local allowIncreaseFirstDefault = true;
    local allowDecreaseFirstDefault = true;
    if (Mod.Settings.Phases ~= nil and not Mod.Settings.PhaseOrderPlayerSelected) then
        -- order was fixed - only the direction of the first configured row was actually reachable
        allowIncreaseFirstDefault = (Mod.Settings.Phases[1].Percent >= 0);
        allowDecreaseFirstDefault = not allowIncreaseFirstDefault;
    end

    ---- Allowed starting order
    local startOrderHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(startOrderHeading).SetText('Allowed starting order:').SetColor(SUBHEADING_COLOUR);

    allowIncreaseFirst = UI.CreateCheckBox(startOrderHeading)
        .SetText('Allow starting with Crunch Time (then Rest Time)')
        .SetIsChecked(allowIncreaseFirstDefault);

    allowDecreaseFirst = UI.CreateCheckBox(startOrderHeading)
        .SetText('Allow starting with Rest Time (then Crunch Time)')
        .SetIsChecked(allowDecreaseFirstDefault);

    -- at least one order must stay allowed - if the player unchecks one and the other is already unchecked,
    -- force the other back on rather than allowing a state where Crunch Time could never be entered
    allowIncreaseFirst.SetOnValueChanged(function()
        if (not allowIncreaseFirst.GetIsChecked() and not allowDecreaseFirst.GetIsChecked()) then
            allowDecreaseFirst.SetIsChecked(true);
        end
    end);

    allowDecreaseFirst.SetOnValueChanged(function()
        if (not allowDecreaseFirst.GetIsChecked() and not allowIncreaseFirst.GetIsChecked()) then
            allowIncreaseFirst.SetIsChecked(true);
        end
    end);

    ---- Duration mode
    local basicDurationModeHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(basicDurationModeHeading).SetText('Duration:').SetColor(SUBHEADING_COLOUR);
    userSpecifiedDuration = UI.CreateCheckBox(basicDurationModeHeading)
    .SetText('User-specified duration (the same duration is used for both phases)')
    .SetIsChecked(Mod.Settings.UserSpecifiedDuration or false);

    BasicDurationSettingsHeading = UI.CreateVerticalLayoutGroup(basicDurationModeHeading);

    userSpecifiedDuration.SetOnValueChanged(function()
        UI.Destroy(BasicDurationSettingsHeading);
        BasicDurationSettingsHeading = UI.CreateVerticalLayoutGroup(basicDurationModeHeading);
        Create_Basic_Duration_SubOptions_UI(BasicDurationSettingsHeading);
    end);

    ---- Increase phase
    local increaseHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(increaseHeading).SetText('Crunch Time (income increase):').SetColor(SUBHEADING_COLOUR);

    local increasePercentHorz = UI.CreateHorizontalLayoutGroup(increaseHeading);
    UI.CreateLabel(increasePercentHorz)
    .SetText('% income increase')
    .SetPreferredWidth(290);

    increasePercent = UI.CreateNumberInputField(increasePercentHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(3.0)
        .SetWholeNumbers(false)
        .SetValue((increaseRowDefault and increaseRowDefault.Percent) or 0.5);

    local increaseFlatHorz = UI.CreateHorizontalLayoutGroup(increaseHeading);
    UI.CreateLabel(increaseFlatHorz)
    .SetText('Flat income increase')
    .SetPreferredWidth(290);

    increaseFlatAmount = UI.CreateNumberInputField(increaseFlatHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue((increaseRowDefault and increaseRowDefault.FlatAmount) or 3);

    ---- Decrease phase
    local decreaseHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(decreaseHeading)
    .SetText('Rest Time (income decrease):')
    .SetColor(SUBHEADING_COLOUR);

    local decreasePercentHorz = UI.CreateHorizontalLayoutGroup(decreaseHeading);
    UI.CreateLabel(decreasePercentHorz)
    .SetText('% income decrease')
    .SetPreferredWidth(290);

    decreasePercent = UI.CreateNumberInputField(decreasePercentHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1.0)
        .SetWholeNumbers(false)
        .SetValue((decreaseRowDefault and -decreaseRowDefault.Percent) or 0.3);

    local decreaseFlatHorz = UI.CreateHorizontalLayoutGroup(decreaseHeading);
    UI.CreateLabel(decreaseFlatHorz)
    .SetText('Flat income decrease')
    .SetPreferredWidth(290);

    decreaseFlatAmount = UI.CreateNumberInputField(decreaseFlatHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue((decreaseRowDefault and -decreaseRowDefault.FlatAmount) or 2);

    Create_Basic_Duration_SubOptions_UI(BasicDurationSettingsHeading);
end;

function Create_Basic_Duration_SubOptions_UI(rootParent)
    if (userSpecifiedDuration.GetIsChecked()) then
        local horz = UI.CreateHorizontalLayoutGroup(rootParent);
        UI.CreateLabel(horz)
        .SetText('Maximum duration a player may choose')
        .SetPreferredWidth(290);

        maxUserSpecifiedDuration = UI.CreateNumberInputField(horz)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(30)
            .SetValue(Mod.Settings.MaxUserSpecifiedDuration or 5);
    else
        local increaseDurationDefault = (Mod.Settings.Phases and Mod.Settings.Phases[1] and Mod.Settings.Phases[1].Duration) or 3;
        local decreaseDurationDefault = (Mod.Settings.Phases and Mod.Settings.Phases[2] and Mod.Settings.Phases[2].Duration) or 3;

        local increaseHorz = UI.CreateHorizontalLayoutGroup(rootParent);
        UI.CreateLabel(increaseHorz)
        .SetText('Crunch Time duration')
        .SetPreferredWidth(290);

        increaseDuration = UI.CreateNumberInputField(increaseHorz)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(30)
            .SetValue(increaseDurationDefault);

        local decreaseHorz = UI.CreateHorizontalLayoutGroup(rootParent);
        UI.CreateLabel(decreaseHorz)
        .SetText('Rest Time duration')
        .SetPreferredWidth(290);

        decreaseDuration = UI.CreateNumberInputField(decreaseHorz)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(30)
            .SetValue(decreaseDurationDefault);
    end
end;
