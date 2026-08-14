require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---- Acquiring type
    local acquiringTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(acquiringTypeHeading).SetText('Acquiry Type?').SetColor(SUBHEADING_COLOUR);
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
    UI.CreateLabel(mainModUI).SetText('Bomb Shelter Behaviour:').SetColor(SUBHEADING_COLOUR);
    local behaviourVGroup = UI.CreateVerticalLayoutGroup(mainModUI);

    local horz = UI.CreateHorizontalLayoutGroup(behaviourVGroup);
    UI.CreateLabel(horz).SetText('% of Bomb Card damage armies in a Bomb Shelter take').SetPreferredWidth(290);
    bombShelterDamagePercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.BombShelterDamagePercent or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(behaviourVGroup);
    UI.CreateLabel(horz).SetText('Bomb Shelter is destroyed when bombed').SetPreferredWidth(290);
    bombShelterDestroyedOnBomb = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.BombShelterDestroyedOnBomb or false).SetText('');

    local horz = UI.CreateHorizontalLayoutGroup(behaviourVGroup);
    UI.CreateLabel(horz).SetText('Bomb Shelter has a limited duration').SetPreferredWidth(290);
    bombShelterHasDuration = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.BombShelterHasDuration or false).SetText('');

    local durationSubOptionsParent = UI.CreateVerticalLayoutGroup(behaviourVGroup);

    bombShelterHasDuration.SetOnValueChanged(function()
        if (bombShelterHasDuration.GetIsChecked()) then
            Create_Duration_SubOptions_UI(durationSubOptionsParent);
        else
            UI.Destroy(durationSubOptionsVGroup);
        end
    end);

    if (bombShelterHasDuration.GetIsChecked()) then
        Create_Duration_SubOptions_UI(durationSubOptionsParent);
    end
end

function Create_Duration_SubOptions_UI(rootParent)
    durationSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(durationSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Number of turns until a Bomb Shelter is removed').SetPreferredWidth(290);
    bombShelterDurationTurns = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.BombShelterDurationTurns or 5);
end

function Create_Card_SubOptions_UI(rootParent)
    acquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Card Settings:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    bombShelterNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.BombShelterNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    bombShelterCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BombShelterCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    bombShelterMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BombShelterMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    bombShelterInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BombShelterInitialPieces or 0);
end

function Create_Commerce_SubOptions_UI(rootParent)
    acquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Commerce Settings:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Cost of a Bomb Shelter').SetPreferredWidth(290);
    bombShelterCost = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue(Mod.Settings.BombShelterCost or 5);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Maximum number of Bomb Shelters a player can own at once').SetPreferredWidth(290);
    bombShelterMaxPerPlayer = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.BombShelterMaxPerPlayer or 3);
end
