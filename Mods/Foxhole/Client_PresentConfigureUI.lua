require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    MigrateModSettings();
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---- Acquiring type
    local acquiringTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(acquiringTypeHeading).SetText('How are Foxholes acquired?').SetColor(SUBHEADING_COLOUR);
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);

    local acquiringSubOptionsParent = UI.CreateVerticalLayoutGroup(mainModUI);

    isAcquiringTypeCard = UI.CreateRadioButton(acquiringTypeHeading)
        .SetGroup(acquiringType)
        .SetText('Card')
        .SetIsChecked(Mod.Settings.IsAcquiringTypeCard == nil or Mod.Settings.IsAcquiringTypeCard);

    isAcquiringTypeCommerce = UI.CreateRadioButton(acquiringTypeHeading)
        .SetGroup(acquiringType)
        .SetText('Commerce')
        .SetIsChecked(Mod.Settings.IsAcquiringTypeCard ~= nil and not Mod.Settings.IsAcquiringTypeCard);

    isAcquiringTypeCard.SetOnValueChanged(function()
        if (isAcquiringTypeCard.GetIsChecked()) then
            isAcquiringTypeCard.SetInteractable(false);
            isAcquiringTypeCommerce.SetInteractable(true);
            UI.Destroy(acquiringSubOptionsVGroup);
            Create_Card_SubOptions_UI(acquiringSubOptionsParent);
        end
    end);

    isAcquiringTypeCommerce.SetOnValueChanged(function()
        if (isAcquiringTypeCommerce.GetIsChecked()) then
            isAcquiringTypeCommerce.SetInteractable(false);
            isAcquiringTypeCard.SetInteractable(true);
            UI.Destroy(acquiringSubOptionsVGroup);
            Create_Commerce_SubOptions_UI(acquiringSubOptionsParent);
        end
    end);

    -- one time check for loading up from settings
    if (isAcquiringTypeCard.GetIsChecked()) then
        isAcquiringTypeCard.SetInteractable(false);
        Create_Card_SubOptions_UI(acquiringSubOptionsParent);
    else
        isAcquiringTypeCommerce.SetInteractable(false);
        Create_Commerce_SubOptions_UI(acquiringSubOptionsParent);
    end

    ---- Damage settings
    UI.CreateLabel(mainModUI).SetText('Foxhole Behaviour:').SetColor(SUBHEADING_COLOUR);
    local behaviourVGroup = UI.CreateVerticalLayoutGroup(mainModUI);

    local horz = UI.CreateHorizontalLayoutGroup(behaviourVGroup);
    UI.CreateLabel(horz).SetText('% of Bomb Card damage armies in a Foxhole take').SetPreferredWidth(290);
    foxholeDamagePercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.FoxholeDamagePercent or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(behaviourVGroup);
    UI.CreateLabel(horz).SetText('Foxhole is destroyed when bombed').SetPreferredWidth(290);
    foxholeDestroyedOnBomb = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.FoxholeDestroyedOnBomb or false).SetText('');

    local horz = UI.CreateHorizontalLayoutGroup(behaviourVGroup);
    UI.CreateLabel(horz).SetText('Foxhole has a limited duration').SetPreferredWidth(290);
    foxholeHasDuration = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.FoxholeHasDuration or false).SetText('');

    local durationSubOptionsParent = UI.CreateVerticalLayoutGroup(behaviourVGroup);

    foxholeHasDuration.SetOnValueChanged(function()
        if (foxholeHasDuration.GetIsChecked()) then
            Create_Duration_SubOptions_UI(durationSubOptionsParent);
        else
            UI.Destroy(durationSubOptionsVGroup);
        end
    end);

    if (foxholeHasDuration.GetIsChecked()) then
        Create_Duration_SubOptions_UI(durationSubOptionsParent);
    end
end

function Create_Duration_SubOptions_UI(rootParent)
    durationSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(durationSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Number of turns until a Foxhole is removed').SetPreferredWidth(290);
    foxholeDurationTurns = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.FoxholeDurationTurns or 5);
end

function Create_Card_SubOptions_UI(rootParent)
    acquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Card Settings:').SetColor(BUTTON_COLOURS.LightBlue);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    foxholeNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.FoxholeNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    foxholeCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FoxholeCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    foxholeMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FoxholeMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    foxholeInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FoxholeInitialPieces or 0);
end

function Create_Commerce_SubOptions_UI(rootParent)
    acquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Commerce Settings:').SetColor(BUTTON_COLOURS.LightBlue);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Cost of a Foxhole (gold)').SetPreferredWidth(290);
    foxholeCost = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue(Mod.Settings.FoxholeCost or 5);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Maximum Foxholes a player can own at once').SetPreferredWidth(290);
    foxholeMaxPerPlayer = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.FoxholeMaxPerPlayer or 3);
end
