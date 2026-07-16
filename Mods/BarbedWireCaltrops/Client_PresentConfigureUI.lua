require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(mainModUI).SetText("Multiple barbed wires in a single territory do not increase the effect*");

    ---- Acquiring type
    local acquiringTypeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);
    UI.CreateLabel(acquiringTypeHeading).SetText('Acquiring type:').SetColor(SUBHEADING_COLOUR);

    -- Card acquiring type
    local acquiringTypeCardHeading = UI.CreateVerticalLayoutGroup(acquiringTypeHeading);
    isAcquiringTypeCard = UI.CreateRadioButton(acquiringTypeCardHeading).SetGroup(acquiringType).SetText('Card').SetIsChecked(Mod.Settings.isAcquiringTypeCard or true).SetInteractable(false);

    ---- include cards
    local includeCardsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(includeCardsHeading).SetText('Include mods:').SetColor(SUBHEADING_COLOUR);
    
    includeBarbedWire = UI.CreateCheckBox(includeCardsHeading).SetText("Include Barbed Wire").SetIsChecked(Mod.Settings.IncludeBarbedWire or false);
    local barbedWireParentVHeading = UI.CreateVerticalLayoutGroup(includeCardsHeading);

    includeBarbedWire.SetOnValueChanged(function() 
        if(includeBarbedWire.GetIsChecked()) then
            Create_BarbedWire_SubOptions_UI(barbedWireParentVHeading);
        else
           UI.Destroy(barbedWireVHeading);
        end
    end);

    includeTankCaltrop = UI.CreateCheckBox(includeCardsHeading).SetText("Include Tank Caltrop").SetIsChecked(Mod.Settings.IncludeTankCaltrop or false);
    local tankCaltropParentVHeading = UI.CreateVerticalLayoutGroup(includeCardsHeading);

    includeTankCaltrop.SetOnValueChanged(function() 
        if(includeTankCaltrop.GetIsChecked()) then
            Create_TankCaltrop_SubOptions_UI(tankCaltropParentVHeading);
        else
           UI.Destroy(tankCaltropVHeading);
        end
    end);

    -- Commerce acquiring type
    isAcquiringTypeCommerce = false;

     -- one time check for loading up from settings
    if(includeBarbedWire.GetIsChecked()) then
        Create_BarbedWire_SubOptions_UI(barbedWireParentVHeading);
    end
    if(includeTankCaltrop.GetIsChecked()) then
        Create_TankCaltrop_SubOptions_UI(tankCaltropParentVHeading);
    end
end

function Create_BarbedWire_SubOptions_UI(rootParent)
    barbedWireVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    if(isAcquiringTypeCard.GetIsChecked()) then
        Create_BarbedWireCard_SubOptions_UI(barbedWireVHeading);
    end

    local optionalsHeading = UI.CreateVerticalLayoutGroup(barbedWireVHeading);
    UI.CreateLabel(optionalsHeading).SetText('Behaviour:').SetColor(BUTTON_COLOURS.LightBlue);
    barbedWireAllyTriggers = UI.CreateCheckBox(optionalsHeading).SetText("Allies trigger barbed wire").SetIsChecked(Mod.Settings.BarbedWireAllyTriggers or false);
    barbedWireIsTankSpecialBehaviour = UI.CreateCheckBox(optionalsHeading).SetText("Include Tank special behaviour").SetIsChecked(Mod.Settings.BarbedWireIsTankSpecialBehaviour or false);

    -- Tank sub-options
    barbedWireIsTankSpecialBehaviour.SetOnValueChanged(function() 

        if(barbedWireIsTankSpecialBehaviour.GetIsChecked()) then
            Create_BarbedWire_Tank_SubOptions_UI(optionalsHeading);
        else
           UI.Destroy(barbedWireTankSupportHeading);
           barbedWireTanksIgnore.SetIsChecked(false);
           barbedWireTanksDestroy.SetIsChecked(false);
        end
    end);

     -- one time check for loading up from settings
    if(barbedWireIsTankSpecialBehaviour.GetIsChecked()) then
        Create_BarbedWire_Tank_SubOptions_UI(optionalsHeading);
    end
end

function Create_TankCaltrop_SubOptions_UI(rootParent)
    tankCaltropVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    
    if(isAcquiringTypeCard.GetIsChecked()) then
        Create_TankCaltropCard_SubOptions_UI(tankCaltropVHeading);
    end

    local optionalsHeading = UI.CreateVerticalLayoutGroup(tankCaltropVHeading);
    UI.CreateLabel(optionalsHeading).SetText('Behaviour:').SetColor(BUTTON_COLOURS.LightBlue);
    tankCaltropAllyTriggers = UI.CreateCheckBox(optionalsHeading).SetText("Allies trigger tank caltrops").SetIsChecked(Mod.Settings.TankCaltropAllyTriggers or false);
end

function Create_BarbedWire_Tank_SubOptions_UI(rootParent)
    barbedWireTankSupportHeading = UI.CreateVerticalLayoutGroup(rootParent);
    barbedWireTankSpecialBehaviourGroup = UI.CreateRadioButtonGroup(barbedWireTankSupportHeading);
    
    barbedWireTanksIgnore = UI.CreateRadioButton(barbedWireTankSupportHeading).SetGroup(barbedWireTankSpecialBehaviourGroup).SetText('Armies with Tanks ignore triggered barbed wire').SetIsChecked(Mod.Settings.BarbedWireTanksIgnore or false);
    barbedWireTanksDestroy = UI.CreateRadioButton(barbedWireTankSupportHeading).SetGroup(barbedWireTankSpecialBehaviourGroup).SetText('Tanks destroy barbed wire on entry/exit').SetIsChecked(Mod.Settings.BarbedWireTanksDestroy or false);

    barbedWireTanksIgnore.SetOnValueChanged(function() 
        if(barbedWireTanksIgnore.GetIsChecked()) then
            barbedWireTanksIgnore.SetInteractable(false);
        else
           barbedWireTanksIgnore.SetInteractable(true);
        end
    end);
    
    barbedWireTanksDestroy.SetOnValueChanged(function() 
        if(barbedWireTanksDestroy.GetIsChecked()) then
            barbedWireTanksDestroy.SetInteractable(false);
        else
           barbedWireTanksDestroy.SetInteractable(true);
        end
    end);

    -- initial load
    if(barbedWireTanksIgnore.GetIsChecked()) then
        barbedWireTanksIgnore.SetInteractable(false);
        barbedWireTanksDestroy.SetInteractable(true);
    else
        barbedWireTanksIgnore.SetInteractable(true);
        barbedWireTanksDestroy.SetInteractable(false);
    end
end


function Create_BarbedWireCard_SubOptions_UI(rootParent)
    barbedWireCardOptionsHeading = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(barbedWireCardOptionsHeading).SetText('Card:').SetColor(BUTTON_COLOURS.LightBlue);
    local horz = UI.CreateHorizontalLayoutGroup(barbedWireCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    barbedWireNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.BarbedWireNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(barbedWireCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    barbedWireCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BarbedWireWeight or 1.0);
    
    local horz = UI.CreateHorizontalLayoutGroup(barbedWireCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    barbedWireMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BarbedWireMinPieces or 1);
    
    local horz = UI.CreateHorizontalLayoutGroup(barbedWireCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    barbedWireInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BarbedWireInitialPieces or 5);
end

function Create_TankCaltropCard_SubOptions_UI(rootParent)
    tankCaltropCardOptionsHeading = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(tankCaltropCardOptionsHeading).SetText('Card:').SetColor(BUTTON_COLOURS.LightBlue);

    local horz = UI.CreateHorizontalLayoutGroup(tankCaltropCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    tankCaltropNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.TankCaltropNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(tankCaltropCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    tankCaltropCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.TankCaltropWeight or 1.0);
    
    local horz = UI.CreateHorizontalLayoutGroup(tankCaltropCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    tankCaltropMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.TankCaltropMinPieces or 1);
    
    local horz = UI.CreateHorizontalLayoutGroup(tankCaltropCardOptionsHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    tankCaltropInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.TankCaltropInitialPieces or 5);
end