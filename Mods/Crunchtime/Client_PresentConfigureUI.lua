require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

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

    ---- Allowed starting order
    local startOrderHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(startOrderHeading).SetText('Allowed starting order:').SetColor(SUBHEADING_COLOUR);

    allowIncreaseFirst = UI.CreateCheckBox(startOrderHeading)
        .SetText('Allow starting with Crunch Time (then Rest Time)')
        .SetIsChecked(Mod.Settings.AllowIncreaseFirst ~= false);

    allowDecreaseFirst = UI.CreateCheckBox(startOrderHeading)
        .SetText('Allow starting with Rest Time (then Crunch Time)')
        .SetIsChecked(Mod.Settings.AllowDecreaseFirst ~= false);

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
    local durationModeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(durationModeHeading).SetText('Duration:').SetColor(SUBHEADING_COLOUR);
    userSpecifiedDuration = UI.CreateCheckBox(durationModeHeading)
    .SetText('User-specified duration (the same duration is used for both phases)')
    .SetIsChecked(Mod.Settings.UserSpecifiedDuration or false);

    DurationSettingsHeading = UI.CreateVerticalLayoutGroup(durationModeHeading);

    userSpecifiedDuration.SetOnValueChanged(function()
        UI.Destroy(DurationSettingsHeading);
        DurationSettingsHeading = UI.CreateVerticalLayoutGroup(durationModeHeading);
        Create_Duration_SubOptions_UI(DurationSettingsHeading);
    end);

    ---- Increase phase
    local increaseHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(increaseHeading).SetText('Crunch Time (income increase):').SetColor(SUBHEADING_COLOUR);

    local increasePercentHorz = UI.CreateHorizontalLayoutGroup(increaseHeading);
    UI.CreateLabel(increasePercentHorz)
    .SetText('% income increase')
    .SetPreferredWidth(290);
    
    increasePercent = UI.CreateNumberInputField(increasePercentHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(3.0)
        .SetWholeNumbers(false)
        .SetValue(Mod.Settings.IncreasePercent or 0.5);

    local increaseFlatHorz = UI.CreateHorizontalLayoutGroup(increaseHeading);
    UI.CreateLabel(increaseFlatHorz)
    .SetText('Flat income increase')
    .SetPreferredWidth(290);

    increaseFlatAmount = UI.CreateNumberInputField(increaseFlatHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue(Mod.Settings.IncreaseFlatAmount or 3);

    ---- Decrease phase
    local decreaseHeading = UI.CreateVerticalLayoutGroup(mainModUI);
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
        .SetValue(Mod.Settings.DecreasePercent or 0.3);

    local decreaseFlatHorz = UI.CreateHorizontalLayoutGroup(decreaseHeading);
    UI.CreateLabel(decreaseFlatHorz)
    .SetText('Flat income decrease')
    .SetPreferredWidth(290);

    decreaseFlatAmount = UI.CreateNumberInputField(decreaseFlatHorz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue(Mod.Settings.DecreaseFlatAmount or 2);

    -- one-time checks for loading up from settings
    if (triggerTypeCard.GetIsChecked()) then
        Create_Card_SubOptions_UI(triggerTypeCardHeading);
        triggerTypeCard.SetInteractable(false);
    end
    if (triggerTypeMenu.GetIsChecked()) then
        triggerTypeMenu.SetInteractable(false);
    end

    Create_Duration_SubOptions_UI(DurationSettingsHeading);
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

function Create_Duration_SubOptions_UI(rootParent)
    if (userSpecifiedDuration.GetIsChecked()) then
        local horz = UI.CreateHorizontalLayoutGroup(rootParent);
        UI.CreateLabel(horz)
        .SetText('Maximum duration a player may choose')
        .SetPreferredWidth(290);

        maxUserSpecifiedDuration = UI.CreateNumberInputField(horz)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(10)
            .SetValue(Mod.Settings.MaxUserSpecifiedDuration or 5);
    else
        local increaseHorz = UI.CreateHorizontalLayoutGroup(rootParent);
        UI.CreateLabel(increaseHorz)
        .SetText('Crunch Time duration')
        .SetPreferredWidth(290);

        increaseDuration = UI.CreateNumberInputField(increaseHorz)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(30)
            .SetValue(Mod.Settings.IncreaseDuration or 3);

        local decreaseHorz = UI.CreateHorizontalLayoutGroup(rootParent);
        UI.CreateLabel(decreaseHorz)
        .SetText('Rest Time duration')
        .SetPreferredWidth(290);

        decreaseDuration = UI.CreateNumberInputField(decreaseHorz)
            .SetSliderMinValue(1)
            .SetSliderMaxValue(30)
            .SetValue(Mod.Settings.DecreaseDuration or 3);
    end
end;
