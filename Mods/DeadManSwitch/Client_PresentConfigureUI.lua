require("Utilities");

function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(mainModUI).SetText("Allows the creation of a Dead Man's Switch (DMS) structure. After an attacker takes a territory containing one, it will trigger and deal damage to the attacker.");

    ---- Acquiring type
    acquiringTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);
    UI.CreateLabel(acquiringTypeHeading).SetText('Acquiring type:').SetColor(SUBHEADING_COLOUR);

    -- Card acquiring type
    acquiringTypeCardHeading = UI.CreateVerticalLayoutGroup(acquiringTypeHeading);
    isAcquiringTypeCard = UI.CreateRadioButton(acquiringTypeCardHeading).SetGroup(acquiringType).SetText('Card');

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
    -- acquiringTypeCommerceHeading = UI.CreateVerticalLayoutGroup(acquiringTypeHeading);
    -- isAcquiringTypeCommerce = UI.CreateRadioButton(acquiringTypeCommerceHeading).SetGroup(acquiringType).SetText('Commerce');
    
    -- isAcquiringTypeCommerce.SetOnValueChanged(function() 

    --     if(isAcquiringTypeCommerce.GetIsChecked()) then
    --         isAcquiringTypeCommerce.SetInteractable(false);
    --     else
    --        isAcquiringTypeCommerce.SetInteractable(true);
    --     end
    -- end);

    ---- Damage type
    damageTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);

    UI.CreateLabel(damageTypeHeading).SetText('Damage type when triggered:').SetColor(SUBHEADING_COLOUR);

    triggerDamageType = UI.CreateRadioButtonGroup(damageTypeHeading);

    -- bomb damage
    damageTypeBombHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeBomb = UI.CreateRadioButton(damageTypeBombHeading).SetGroup(triggerDamageType).SetText('Play Bomb Card');

    isDamageTypeBomb.SetOnValueChanged(function() 

        if(isDamageTypeBomb.GetIsChecked()) then
            isDamageTypeBomb.SetInteractable(false);
        else
           isDamageTypeBomb.SetInteractable(true);
        end
    end);

    -- flat damage
    damageTypeFlatHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypeFlat = UI.CreateRadioButton(damageTypeFlatHeading).SetGroup(triggerDamageType).SetText('Flat Damage');

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
    damageTypePercentHeading = UI.CreateVerticalLayoutGroup(damageTypeHeading);
    isDamageTypePercent = UI.CreateRadioButton(damageTypePercentHeading).SetGroup(triggerDamageType).SetText('% Damage');

    isDamageTypePercent.SetOnValueChanged(function() 

        if(isDamageTypePercent.GetIsChecked()) then
            Create_PercentageDamage_SubOptions_UI(damageTypePercentHeading);
            isDamageTypePercent.SetInteractable(false);
        else
           UI.Destroy(percentageDamageHeading);
           isDamageTypePercent.SetInteractable(true);
        end
    end);


    optionalsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(optionalsHeading).SetText('Optionals:').SetColor(SUBHEADING_COLOUR);
    allyTriggers = UI.CreateCheckBox(optionalsHeading).SetText("Allies trigger DMS").SetIsChecked(Mod.Settings.AllyTriggers or false);
end;

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

function Create_FlatDamage_SubOptions_UI(rootParent)
    flatDamageHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(flatDamageHeading);
    UI.CreateLabel(horz).SetText('Flat Damage Amount').SetPreferredWidth(290);
    flatDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(30)
        .SetValue(Mod.Settings.FlatDamage or 15);
end;

function Create_Card_SubOptions_UI(rootParent)
    cardOptionsHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Number of Pieces to divide the card into').SetFlexibleWidth(290);
    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.NumPieces or 5);

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
        .SetValue(Mod.Settings.InitialPieces or 5);

end;