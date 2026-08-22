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
    UI.CreateLabel(horz).SetText('Cards corrupted per turn, per active Corruption card').SetPreferredWidth(290);
    cardsCorruptedPerTurn = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardsCorruptedPerTurnPerSource or 1);

    UI.CreateLabel(mainModUI).SetText('Playing a Corrupt Hand gives:');
    local corruptHandGivesGroup = UI.CreateRadioButtonGroup(mainModUI);

    -- Corruption immediately
    local corruptHandGivesCorruptionHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    corruptHandGivesCorruption = UI.CreateRadioButton(corruptHandGivesCorruptionHeading).SetGroup(corruptHandGivesGroup).SetText('Corruption card')
        .SetIsChecked(Mod.Settings.CorruptHandGivesCorruptionImmediately or false);

    corruptHandGivesCorruption.SetOnValueChanged(function()
        if (corruptHandGivesCorruption.GetIsChecked()) then
            corruptHandGivesCorruption.SetInteractable(false);
        else
            corruptHandGivesCorruption.SetInteractable(true);
        end
    end);

    -- Budding Corruption, matures later
    local corruptHandGivesBuddingHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    corruptHandGivesBudding = UI.CreateRadioButton(corruptHandGivesBuddingHeading).SetGroup(corruptHandGivesGroup).SetText('Budding Corruption card (which matures into a Corruption Card later)')
        .SetIsChecked(not (Mod.Settings.CorruptHandGivesCorruptionImmediately or false));

    corruptHandGivesBudding.SetOnValueChanged(function()
        if (corruptHandGivesBudding.GetIsChecked()) then
            Create_TurnsUntilCorruption_SubOptions_UI(corruptHandGivesBuddingHeading);
            corruptHandGivesBudding.SetInteractable(false);
        else
            UI.Destroy(turnsUntilCorruptionSubOptionsVGroup);
            corruptHandGivesBudding.SetInteractable(true);
        end
    end);

    if (corruptHandGivesCorruption.GetIsChecked()) then -- one time check for loading up from settings
        corruptHandGivesCorruption.SetInteractable(false);
    end
    if (corruptHandGivesBudding.GetIsChecked()) then -- one time check for loading up from settings
        Create_TurnsUntilCorruption_SubOptions_UI(corruptHandGivesBuddingHeading);
        corruptHandGivesBudding.SetInteractable(false);
    end

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Difficulty to spot Budding Corruption').SetPreferredWidth(290);
    buddingCorruptionDifficulty = Mod.Settings.BuddingCorruptionDifficulty or "Medium";
    buddingCorruptionDifficultyBtn = UI.CreateButton(horz)
        .SetText(buddingCorruptionDifficulty)
        .SetOnClick(SelectBuddingCorruptionDifficultyClicked)
        .SetFlexibleWidth(1);

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

function SelectBuddingCorruptionDifficultyClicked()
    local options = {};
    for _, difficulty in ipairs({ "VeryEasy", "Easy", "Medium", "Hard" }) do
        table.insert(options, { text = difficulty, selected = function() BuddingCorruptionDifficultySelected(difficulty); end });
    end
    UI.PromptFromList("Choose a difficulty to spot Budding Corruption", options);
end

function BuddingCorruptionDifficultySelected(difficulty)
    buddingCorruptionDifficulty = difficulty;
    buddingCorruptionDifficultyBtn.SetText(difficulty);
end

function Create_TurnsUntilCorruption_SubOptions_UI(rootParent)
    turnsUntilCorruptionSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(turnsUntilCorruptionSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Turns until Budding Corruption matures into Corruption').SetPreferredWidth(290);
    turnsUntilCorruption = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.TurnsUntilCorruption or 1, 1);
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
