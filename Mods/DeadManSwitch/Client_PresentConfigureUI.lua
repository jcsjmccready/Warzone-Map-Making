require("Utilities.CommonUtils");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

---@param rootParent RootParent
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

    -- Commerce acquiring type
    isAcquiringTypeCommerce = false;

    ---- Damage type
    local damageTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);

    UI.CreateLabel(damageTypeHeading).SetText('Trigger actions:').SetColor(SUBHEADING_COLOUR);

    triggerDamageType = UI.CreateRadioButtonGroup(damageTypeHeading);

    -- bomb damage
    local damageTypeBombHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeBomb = UI.CreateRadioButton(damageTypeBombHeading).SetGroup(triggerDamageType).SetText('Play Bomb Card').SetIsChecked(Mod.Settings.isDamageTypeBomb or true);
    UI.CreateLabel(damageTypeBombHeading).SetText('Does not work if DMS owner is neutral*').SetColor(BUTTON_COLOURS.DarkGray);

    isDamageTypeBomb.SetOnValueChanged(function() 

        if(isDamageTypeBomb.GetIsChecked()) then
            isDamageTypeBomb.SetInteractable(false);
        else
           isDamageTypeBomb.SetInteractable(true);
        end
    end);

    -- flat damage
    local damageTypeFlatHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeFlat = UI.CreateRadioButton(damageTypeFlatHeading).SetGroup(triggerDamageType).SetText('Flat Damage').SetIsChecked(Mod.Settings.isDamageTypeFlat or false);

    isDamageTypeFlat.SetOnValueChanged(function() 

        if(isDamageTypeFlat.GetIsChecked()) then
            Create_FlatDamage_SubOptions_UI(damageTypeFlatHeading);
            isDamageTypeFlat.SetInteractable(false);
        else
           UI.Destroy(flatDamageHeading);
           isDamageTypeFlat.SetInteractable(true);
        end
    end);

    -- percentage damage
    local damageTypePercentHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypePercent = UI.CreateRadioButton(damageTypePercentHeading).SetGroup(triggerDamageType).SetText('% Damage').SetIsChecked(Mod.Settings.isDamageTypePercent or false);


    isDamageTypePercent.SetOnValueChanged(function()

        if(isDamageTypePercent.GetIsChecked()) then
            Create_PercentageDamage_SubOptions_UI(damageTypePercentHeading);
            isDamageTypePercent.SetInteractable(false);
        else
           UI.Destroy(percentageDamageHeading);
           isDamageTypePercent.SetInteractable(true);
        end
    end);

    -- blockade damage
    local damageTypeBlockadeHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeBlockade = UI.CreateRadioButton(damageTypeBlockadeHeading).SetGroup(triggerDamageType).SetText('Play Blockade Card').SetIsChecked(Mod.Settings.isDamageTypeBlockade or false);

    isDamageTypeBlockade.SetOnValueChanged(function()

        if(isDamageTypeBlockade.GetIsChecked()) then
            isDamageTypeBlockade.SetInteractable(false);
        else
           isDamageTypeBlockade.SetInteractable(true);
        end
    end);

    -- emergency blockade damage
    local damageTypeEmergencyBlockadeHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeEmergencyBlockade = UI.CreateRadioButton(damageTypeEmergencyBlockadeHeading).SetGroup(triggerDamageType).SetText('Play Emergency Blockade Card').SetIsChecked(Mod.Settings.isDamageTypeEmergencyBlockade or false);

    isDamageTypeEmergencyBlockade.SetOnValueChanged(function()

        if(isDamageTypeEmergencyBlockade.GetIsChecked()) then
            isDamageTypeEmergencyBlockade.SetInteractable(false);
        else
           isDamageTypeEmergencyBlockade.SetInteractable(true);
        end
    end);

    -- nuke damage
    local damageTypeNukeHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeNuke = UI.CreateRadioButton(damageTypeNukeHeading).SetGroup(triggerDamageType)
    .SetText('Play Nuke Card')
    .SetIsChecked(Mod.Settings.isDamageTypeNuke or false);

    UI.CreateLabel(damageTypeNukeHeading).SetText('Requires and configured via Nuke mod by Krinid*').SetColor(BUTTON_COLOURS.DarkGray);

    isDamageTypeNuke.SetOnValueChanged(function()

        if(isDamageTypeNuke.GetIsChecked()) then
            isDamageTypeNuke.SetInteractable(false);
        else
           isDamageTypeNuke.SetInteractable(true);
        end
    end);

    ---- Additional trigger actions (can stack with each other and with the trigger action above)
    local additionalActionsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(additionalActionsHeading).SetText('Additional trigger actions:').SetColor(SUBHEADING_COLOUR);

    isDamageTypeSanction = UI.CreateCheckBox(additionalActionsHeading).SetText('Play Sanction Card').SetIsChecked(Mod.Settings.isDamageTypeSanction or false);
    isDamageTypeDiplomacy = UI.CreateCheckBox(additionalActionsHeading).SetText('Play Diplomacy Card').SetIsChecked(Mod.Settings.isDamageTypeDiplomacy or false);
    UI.CreateLabel(additionalActionsHeading).SetText('Does not work if DMS owner is neutral*').SetColor(BUTTON_COLOURS.DarkGray);

    isDamageTypeSpy = UI.CreateCheckBox(additionalActionsHeading).SetText('Play Spy Card').SetIsChecked(Mod.Settings.isDamageTypeSpy or false);
    UI.CreateLabel(additionalActionsHeading).SetText('Does not work if DMS owner is neutral*').SetColor(BUTTON_COLOURS.DarkGray);


    local optionalsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(optionalsHeading).SetText('Optionals:').SetColor(SUBHEADING_COLOUR);
    allyTriggers = UI.CreateCheckBox(optionalsHeading).SetText("Allies trigger DMS").SetIsChecked(Mod.Settings.AllyTriggers or false);
    
    if(isAcquiringTypeCard.GetIsChecked()) then -- one time check for loading up from settings
        Create_Card_SubOptions_UI(acquiringTypeHeading);
        isAcquiringTypeCard.SetInteractable(false);
    end
    if(isDamageTypePercent.GetIsChecked()) then -- one time check for loading up from settings
        Create_PercentageDamage_SubOptions_UI(damageTypePercentHeading);
        isDamageTypePercent.SetInteractable(false);
    end
    if(isDamageTypeFlat.GetIsChecked()) then -- one time check for loading up from settings
        Create_FlatDamage_SubOptions_UI(damageTypeFlatHeading);
        isDamageTypeFlat.SetInteractable(false);
    end
    if(isDamageTypeBomb.GetIsChecked()) then -- one time check for loading up from settings
        isDamageTypeBomb.SetInteractable(false);
    end
    if(isDamageTypeBlockade.GetIsChecked()) then -- one time check for loading up from settings
        isDamageTypeBlockade.SetInteractable(false);
    end
    if(isDamageTypeEmergencyBlockade.GetIsChecked()) then -- one time check for loading up from settings
        isDamageTypeEmergencyBlockade.SetInteractable(false);
    end
    if(isDamageTypeNuke.GetIsChecked()) then -- one time check for loading up from settings
        isDamageTypeNuke.SetInteractable(false);
    end
end;

---@param rootParent VerticalLayoutGroup
function Create_PercentageDamage_SubOptions_UI(rootParent)
    percentageDamageHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(percentageDamageHeading);
    UI.CreateLabel(horz).SetText('Percentage Damage Amount').SetPreferredWidth(290);
    percentageDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0.01)
        .SetSliderMaxValue(1.0)
        .SetWholeNumbers(false)
        .SetValue(Mod.Settings.PercentageDamage or 0.3);

    local horz = UI.CreateHorizontalLayoutGroup(percentageDamageHeading);
    UI.CreateLabel(horz).SetText('Minimum Damage Amount').SetPreferredWidth(290);
    percentageMinDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(30)
        .SetValue(Mod.Settings.PercentageMinDamage or 1);
end;

---@param rootParent VerticalLayoutGroup
function Create_FlatDamage_SubOptions_UI(rootParent)
    flatDamageHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(flatDamageHeading);
    UI.CreateLabel(horz).SetText('Flat Damage Amount').SetPreferredWidth(290);
    flatDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(30)
        .SetValue(Mod.Settings.FlatDamage or 15);
end;

---@param rootParent VerticalLayoutGroup
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
        .SetValue(Mod.Settings.CardWeight or 1.0);
    
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
        .SetValue(Mod.Settings.InitialPieces or 1);

end;