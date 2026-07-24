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
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);
    UI.CreateLabel(acquiringTypeHeading).SetText('Acquiring type:').SetColor(SUBHEADING_COLOUR);

    -- Card acquiring type
    local acquiringTypeCardHeading = UI.CreateVerticalLayoutGroup(acquiringTypeHeading);
    isAcquiringTypeCard = UI.CreateRadioButton(acquiringTypeCardHeading).SetGroup(acquiringType).SetText('Card').SetIsChecked(Mod.Settings.isAcquiringTypeCard or true);

    -- Card acquiring type sub-options
    isAcquiringTypeCard.SetOnValueChanged(function()

        if(isAcquiringTypeCard.GetIsChecked()) then
            Create_Card_SubOptions_UI(acquiringTypeHeading);
            isAcquiringTypeCard.SetInteractable(false);
        else
           UI.Destroy(cardOptionsHeading);
            isAcquiringTypeCard.SetInteractable(true);
        end
    end);

    -- Commerce acquiring type - reserved for a future acquiring method, not yet exposed in the UI
    isAcquiringTypeCommerce = false;

    ---- Mod Behaviour
    local modBehaviourHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(modBehaviourHeading).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(modBehaviourHeading);
    UI.CreateLabel(horz).SetText('Sweeper Radius').SetPreferredWidth(290);
    sweeperRadius = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.SweeperRadius or 1);

    local horz = UI.CreateHorizontalLayoutGroup(modBehaviourHeading);
    UI.CreateLabel(horz).SetText('Radio Detection Radius').SetPreferredWidth(290);
    radioDetectionRadius = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.RadioDetectionRadius or 3);

    UI.CreateLabel(modBehaviourHeading).SetText('Visibility gained:');
    local visibilityGained = UI.CreateRadioButtonGroup(modBehaviourHeading);

    -- Autoplay Spy Card visibility
    local visibilityGainedAutoplaySpyCardHeading = UI.CreateVerticalLayoutGroup(modBehaviourHeading);
    visibilityGainedAutoplaySpyCard = UI.CreateRadioButton(visibilityGainedAutoplaySpyCardHeading).SetGroup(visibilityGained).SetText('Autoplay Spy Card').SetIsChecked(Mod.Settings.VisibilityGainedAutoplaySpyCard or true);

    visibilityGainedAutoplaySpyCard.SetOnValueChanged(function()
        if(visibilityGainedAutoplaySpyCard.GetIsChecked()) then
            visibilityGainedAutoplaySpyCard.SetInteractable(false);
        else
           visibilityGainedAutoplaySpyCard.SetInteractable(true);
        end
    end);

    -- Custom Vision visibility
    local visibilityGainedCustomVisionHeading = UI.CreateVerticalLayoutGroup(modBehaviourHeading);
    visibilityGainedCustomVision = UI.CreateRadioButton(visibilityGainedCustomVisionHeading).SetGroup(visibilityGained).SetText('Custom Vision').SetIsChecked(Mod.Settings.VisibilityGainedCustomVision or false);

    visibilityGainedCustomVision.SetOnValueChanged(function()
        if(visibilityGainedCustomVision.GetIsChecked()) then
            Create_CustomVision_SubOptions_UI(visibilityGainedCustomVisionHeading);
            visibilityGainedCustomVision.SetInteractable(false);
        else
           UI.Destroy(customVisionHeading);
           visibilityGainedCustomVision.SetInteractable(true);
        end
    end);

    if(isAcquiringTypeCard.GetIsChecked()) then -- one time check for loading up from settings
        Create_Card_SubOptions_UI(acquiringTypeHeading);
        isAcquiringTypeCard.SetInteractable(false);
    end
    if(visibilityGainedAutoplaySpyCard.GetIsChecked()) then -- one time check for loading up from settings
        visibilityGainedAutoplaySpyCard.SetInteractable(false);
    end
    if(visibilityGainedCustomVision.GetIsChecked()) then -- one time check for loading up from settings
        Create_CustomVision_SubOptions_UI(visibilityGainedCustomVisionHeading);
        visibilityGainedCustomVision.SetInteractable(false);
    end
end;

function Create_CustomVision_SubOptions_UI(rootParent)
    customVisionHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(customVisionHeading);
    UI.CreateLabel(horz).SetText('Radius').SetPreferredWidth(290);
    customVisionRadius = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.CustomVisionRadius or 2);
end;

function Create_Card_SubOptions_UI(rootParent)
    cardOptionsHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Number of Pieces to divide the card into').SetFlexibleWidth(290);
    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.NumPieces or 7);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    cardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.Weight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    minPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.MinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    initialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.InitialPieces or 0);

end;
