require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Corruption Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Turns until Budding Corruption matures into Corruption').SetPreferredWidth(290);
    turnsUntilCorruption = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.TurnsUntilCorruption or 1);
    UI.CreateLabel(mainModUI).SetText('(0 = the target receives Corruption immediately instead of Budding Corruption)').SetColor(BUTTON_COLOURS.DarkGray);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Cards corrupted per turn, per active Corruption card').SetPreferredWidth(290);
    cardsCorruptedPerTurn = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardsCorruptedPerTurnPerSource or 1);

    UI.CreateLabel(mainModUI).SetText('Playing a Corrupted Card:').SetColor(SUBHEADING_COLOUR);

    -- Random recovery
    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Allows the option to recover a random card from your pool of corrupted cards').SetPreferredWidth(290);
    recoveryAllowRandom = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.RecoveryAllowRandom or Mod.Settings.RecoveryAllowRandom == nil).SetText('');

    local recoveryRandomSubOptionsParent = UI.CreateVerticalLayoutGroup(mainModUI);

    recoveryAllowRandom.SetOnValueChanged(function()
        if (recoveryAllowRandom.GetIsChecked()) then
            Create_RecoveryRandom_SubOptions_UI(recoveryRandomSubOptionsParent);
        else
            UI.Destroy(recoveryRandomSubOptionsVGroup);
        end
    end);

    if (recoveryAllowRandom.GetIsChecked()) then -- one time check for loading up from settings
        Create_RecoveryRandom_SubOptions_UI(recoveryRandomSubOptionsParent);
    end

    -- Player selected recovery
    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Allows the option to recover a specific card from your pool of corrupted cards').SetPreferredWidth(290);
    recoveryAllowPlayerSelected = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.RecoveryAllowPlayerSelected or false).SetText('');

    local recoveryPlayerSelectedSubOptionsParent = UI.CreateVerticalLayoutGroup(mainModUI);

    recoveryAllowPlayerSelected.SetOnValueChanged(function()
        if (recoveryAllowPlayerSelected.GetIsChecked()) then
            Create_RecoveryPlayerSelected_SubOptions_UI(recoveryPlayerSelectedSubOptionsParent);
        else
            UI.Destroy(recoveryPlayerSelectedSubOptionsVGroup);
        end
    end);

    if (recoveryAllowPlayerSelected.GetIsChecked()) then -- one time check for loading up from settings
        Create_RecoveryPlayerSelected_SubOptions_UI(recoveryPlayerSelectedSubOptionsParent);
    end

    UI.CreateLabel(mainModUI).SetText('Card Settings:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the Corrupt Hand card into').SetPreferredWidth(290);
    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.NumPieces or 7);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    cardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    minPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.MinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    initialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.InitialPieces or 0);
end;

function Create_RecoveryRandom_SubOptions_UI(rootParent)
    recoveryRandomSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(recoveryRandomSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('% of pieces returned').SetPreferredWidth(290);
    recoveryRandomPercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.RecoveryRandomPercent or 0.5);
end;

function Create_RecoveryPlayerSelected_SubOptions_UI(rootParent)
    recoveryPlayerSelectedSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(recoveryPlayerSelectedSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('% of pieces returned').SetPreferredWidth(290);
    recoveryPlayerSelectedPercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.RecoveryPlayerSelectedPercent or 0.25);
end;
