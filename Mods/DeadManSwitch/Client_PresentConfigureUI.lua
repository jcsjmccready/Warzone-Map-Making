require("Utilities");

function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);
    
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---- Acquiring type
    acquiringTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);
    UI.CreateLabel(acquiringTypeHeading).SetText('Acquiring type:').SetColor(getColourCode('subheading'));

    -- Card acquiring type
    isAcquiringTypeCard = UI.CreateRadioButton(acquiringType).SetGroup(acquiringType).SetText('Card');

    -- Card acquiring type sub-options
    isAcquiringTypeCard.SetOnValueChanged(function() 
    
        if(isAcquiringTypeCard.GetIsChecked()) then
            Create_Card_SubOptions_UI(acquiringTypeHeading);
        else
           UI.Destroy(cardOptionsHeading);
        end
    end);

    -- Commerce acquiring type
    isAcquiringTypeCommerce = UI.CreateRadioButton(acquiringType).SetGroup(acquiringType).SetText('Commerce');

    ---- Damage type
    damageTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);

    UI.CreateLabel(damageTypeHeading).SetText('Damage type when triggered:').SetColor(getColourCode('subheading'));

    triggerDamageType = UI.CreateRadioButtonGroup(damageTypeHeading);
    isDamageTypeBomb = UI.CreateRadioButton(damageTypeHeading).SetGroup(triggerDamageType).SetText('Play Bomb Card');
    isDamageTypeFlat = UI.CreateRadioButton(damageTypeHeading).SetGroup(triggerDamageType).SetText('Flat Damage');
    isDamageTypePercent = UI.CreateRadioButton(damageTypeHeading).SetGroup(triggerDamageType).SetText('% Damage');

    isDamageTypeFlat.SetOnValueChanged(function() 
    
        if(isDamageTypeFlat.GetIsChecked()) then
            Create_FlatDamage_SubOptions_UI(damageTypeHeading);
        else
           UI.Destroy(flatDamageHeading);
        end
    end);

    isDamageTypePercent.SetOnValueChanged(function() 
    
        if(isDamageTypePercent.GetIsChecked()) then
            Create_PercentageDamage_SubOptions_UI(damageTypeHeading);
        else
           UI.Destroy(percentageDamageHeading);
        end
    end);

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