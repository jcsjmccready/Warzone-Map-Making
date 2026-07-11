require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(mainModUI).SetText("Allows the creation of a Barbed Wire structure. After an attacker takes a territory containing one, it will trigger and block movement out of the territory the next turn. It resets one turn later.");

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

    local optionalsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(optionalsHeading).SetText('Optionals:').SetColor(SUBHEADING_COLOUR);
    allyTriggers = UI.CreateCheckBox(optionalsHeading).SetText("Allies trigger barbed wire").SetIsChecked(Mod.Settings.AllyTriggers or false);
    tanksIgnore = UI.CreateCheckBox(optionalsHeading).SetText("Armies with tanks can ignore triggered barbed wire").SetIsChecked(Mod.Settings.TanksIgnore or false);
    tanksDestroy = UI.CreateCheckBox(optionalsHeading).SetText("Tanks destroy barbed wire on entry").SetIsChecked(Mod.Settings.TanksDestroy or false);

    if(isAcquiringTypeCard.GetIsChecked()) then -- one time check for loading up from settings
        Create_Card_SubOptions_UI(acquiringTypeHeading);
        isAcquiringTypeCard.SetInteractable(false);
    end
end


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
end