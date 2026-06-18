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