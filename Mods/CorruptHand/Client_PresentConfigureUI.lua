require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Turns until Budding Corruption matures into Corruption').SetPreferredWidth(290);
    turnsUntilCorruption = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.TurnsUntilCorruption or 3);
    UI.CreateLabel(mainModUI).SetText('(0 = the target receives Corruption immediately instead of Budding Corruption)').SetColor(BUTTON_COLOURS.DarkGray);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Cards corrupted per turn, per active Corruption card').SetPreferredWidth(290);
    cardsCorruptedPerTurn = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardsCorruptedPerTurnPerSource or 1);

    UI.CreateLabel(mainModUI).SetText('What playing a Corrupted card gives back:').SetColor(SUBHEADING_COLOUR);
    local recoveryModeGroup = UI.CreateRadioButtonGroup(mainModUI);

    -- Full random card recovery
    local recoveryModeFullRandomCardHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    recoveryModeFullRandomCard = UI.CreateRadioButton(recoveryModeFullRandomCardHeading).SetGroup(recoveryModeGroup).SetText('A full random card from the player\'s corrupted pool')
        .SetIsChecked(Mod.Settings.RecoveryModeFullRandomCard or Mod.Settings.RecoveryModeFullRandomCard == nil);

    recoveryModeFullRandomCard.SetOnValueChanged(function()
        if (recoveryModeFullRandomCard.GetIsChecked()) then
            recoveryModeFullRandomCard.SetInteractable(false);
        else
            recoveryModeFullRandomCard.SetInteractable(true);
        end
    end);

    -- Partial pieces recovery
    local recoveryModePartialPiecesHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    recoveryModePartialPieces = UI.CreateRadioButton(recoveryModePartialPiecesHeading).SetGroup(recoveryModeGroup).SetText('A percentage of pieces towards a random card from the corrupted pool')
        .SetIsChecked(Mod.Settings.RecoveryModeFullRandomCard == false);

    recoveryModePartialPieces.SetOnValueChanged(function()
        if (recoveryModePartialPieces.GetIsChecked()) then
            Create_PartialPieces_SubOptions_UI(recoveryModePartialPiecesHeading);
            recoveryModePartialPieces.SetInteractable(false);
        else
            UI.Destroy(partialPiecesSubOptionsVGroup);
            recoveryModePartialPieces.SetInteractable(true);
        end
    end);

    if (recoveryModeFullRandomCard.GetIsChecked()) then -- one time check for loading up from settings
        recoveryModeFullRandomCard.SetInteractable(false);
    end
    if (recoveryModePartialPieces.GetIsChecked()) then -- one time check for loading up from settings
        Create_PartialPieces_SubOptions_UI(recoveryModePartialPiecesHeading);
        recoveryModePartialPieces.SetInteractable(false);
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

function Create_PartialPieces_SubOptions_UI(rootParent)
    partialPiecesSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(partialPiecesSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('% of pieces returned').SetPreferredWidth(290);
    partialPiecesPercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.PartialPiecesPercent or 0.5);
end;
