require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
MigrateModSettings();
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    if(GetSettingsVersionForDisplay() ~= LATEST_SETTINGS_VERSION) then
        UI.CreateLabel(mainModUI).SetText("Mod Settings Version: " .. GetSettingsVersionForDisplay() .. "/" .. LATEST_SETTINGS_VERSION).SetColor(BUTTON_COLOURS.OrangeRed);
        UI.CreateLabel(mainModUI).SetText("Remove and re-add this mod to refresh*").SetColor(BUTTON_COLOURS.DarkGray);
    end

    ---- Enable Barbed Wire
    includeBarbedWire = UI.CreateCheckBox(mainModUI)
        .SetText("Enable Barbed Wire")
        .SetIsChecked(Mod.Settings.IncludeBarbedWire == nil or Mod.Settings.IncludeBarbedWire);
    local barbedWireEnabledParent = UI.CreateVerticalLayoutGroup(mainModUI);

    includeBarbedWire.SetOnValueChanged(function()
        if(includeBarbedWire.GetIsChecked()) then
            Create_BarbedWireEnabled_UI(barbedWireEnabledParent);
        else
            UI.Destroy(barbedWireEnabledVHeading);
        end
    end);

     -- one time check for loading up from settings
    if(includeBarbedWire.GetIsChecked()) then
        Create_BarbedWireEnabled_UI(barbedWireEnabledParent);
    end

    ---- Enable Caltrops
    includeCaltrop = UI.CreateCheckBox(mainModUI)
        .SetText("Enable Caltrops")
        .SetIsChecked(Mod.Settings.IncludeCaltrop or false);
    local caltropEnabledParent = UI.CreateVerticalLayoutGroup(mainModUI);

    includeCaltrop.SetOnValueChanged(function()
        if(includeCaltrop.GetIsChecked()) then
            Create_CaltropEnabled_UI(caltropEnabledParent);
        else
            UI.Destroy(caltropEnabledVHeading);
        end
    end);

     -- one time check for loading up from settings
    if(includeCaltrop.GetIsChecked()) then
        Create_CaltropEnabled_UI(caltropEnabledParent);
    end
end

function Create_CaltropEnabled_UI(rootParent)
    caltropEnabledVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    ---- Acquiring type
    local acquiringTypeHeading = UI.CreateVerticalLayoutGroup(caltropEnabledVHeading);
    UI.CreateLabel(acquiringTypeHeading)
        .SetText('Acquiring type:')
        .SetColor(SUBHEADING_COLOUR);
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);

    local caltropAcquiringSubOptionsParent = UI.CreateVerticalLayoutGroup(caltropEnabledVHeading);

    caltropIsAcquiringTypeCard = UI.CreateRadioButton(acquiringTypeHeading).SetGroup(acquiringType)
        .SetText('Card')
        .SetIsChecked(Mod.Settings.CaltropIsAcquiringTypeCard == nil or Mod.Settings.CaltropIsAcquiringTypeCard);

    caltropIsAcquiringTypeCommerce = UI.CreateRadioButton(acquiringTypeHeading).SetGroup(acquiringType)
        .SetText('Commerce')
        .SetIsChecked(Mod.Settings.CaltropIsAcquiringTypeCard ~= nil and not Mod.Settings.CaltropIsAcquiringTypeCard);

    caltropIsAcquiringTypeCard.SetOnValueChanged(function()
        if (caltropIsAcquiringTypeCard.GetIsChecked()) then
            caltropIsAcquiringTypeCard.SetInteractable(false);
            caltropIsAcquiringTypeCommerce.SetInteractable(true);
            UI.Destroy(caltropAcquiringSubOptionsVGroup);
            Create_CaltropCard_SubOptions_UI(caltropAcquiringSubOptionsParent);
        end
    end);

    caltropIsAcquiringTypeCommerce.SetOnValueChanged(function()
        if (caltropIsAcquiringTypeCommerce.GetIsChecked()) then
            caltropIsAcquiringTypeCommerce.SetInteractable(false);
            caltropIsAcquiringTypeCard.SetInteractable(true);
            UI.Destroy(caltropAcquiringSubOptionsVGroup);
        end
    end);

    -- one time check for loading up from settings
    if (caltropIsAcquiringTypeCard.GetIsChecked()) then
        caltropIsAcquiringTypeCard.SetInteractable(false);
        Create_CaltropCard_SubOptions_UI(caltropAcquiringSubOptionsParent);
    else
        caltropIsAcquiringTypeCommerce.SetInteractable(false);
    end

    ---- Behaviour
    local caltropParentVHeading = UI.CreateVerticalLayoutGroup(caltropEnabledVHeading);
    Create_Caltrop_Behaviour_UI(caltropParentVHeading);
end

function Create_CaltropCard_SubOptions_UI(rootParent)
    caltropAcquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(caltropAcquiringSubOptionsVGroup).SetText('Card:').SetColor(BUTTON_COLOURS.LightBlue);
    local horz = UI.CreateHorizontalLayoutGroup(caltropAcquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    caltropNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.CaltropNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(caltropAcquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    caltropCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CaltropCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(caltropAcquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    caltropMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CaltropMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(caltropAcquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    caltropInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CaltropInitialPieces or 1);
end

function Create_Caltrop_Behaviour_UI(rootParent)
    caltropVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local optionalsHeading = UI.CreateVerticalLayoutGroup(caltropVHeading);

    UI.CreateLabel(optionalsHeading)
        .SetText('Behaviour:')
        .SetColor(BUTTON_COLOURS.LightBlue);

    local triggerDurationHorz = UI.CreateHorizontalLayoutGroup(optionalsHeading);
    UI.CreateLabel(triggerDurationHorz)
        .SetText('Trigger duration')
        .SetPreferredWidth(290);

    caltropTriggerDuration = UI.CreateNumberInputField(triggerDurationHorz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.CaltropTriggerDuration or 1);

    caltropTrapsArmies = UI.CreateCheckBox(optionalsHeading)
        .SetText("Traps armies")
        .SetIsChecked(Mod.Settings.CaltropTrapsArmies or false);
    caltropCancelsAirlifts = UI.CreateCheckBox(optionalsHeading)
        .SetText("Cancels Airlifts")
        .SetIsChecked(Mod.Settings.CaltropCancelsAirlifts == nil or Mod.Settings.CaltropCancelsAirlifts);
    caltropTrapsSpecialUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Traps Special Units")
        .SetIsChecked(Mod.Settings.CaltropTrapsSpecialUnits == nil or Mod.Settings.CaltropTrapsSpecialUnits);
    caltropOnlyTriggersOnTrappableUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Only trigger if trappable units attacked")
        .SetIsChecked(Mod.Settings.CaltropOnlyTriggersOnTrappableUnits == nil or Mod.Settings.CaltropOnlyTriggersOnTrappableUnits);
    caltropIsTankSpecialBehaviour = UI.CreateCheckBox(optionalsHeading)
        .SetText("Include Tank special behaviour")
        .SetIsChecked(Mod.Settings.CaltropIsTankSpecialBehaviour or false);
    local caltropTankContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);

    UI.CreateLabel(optionalsHeading).SetText("");

    caltropSingleUse = UI.CreateCheckBox(optionalsHeading)
        .SetText("Caltrops are single use (destroyed instead of resetting) ")
        .SetIsChecked(Mod.Settings.CaltropSingleUse or false);
    caltropHasLimitedLifespan = UI.CreateCheckBox(optionalsHeading)
        .SetText("Caltrops have a limited lifespan?")
        .SetIsChecked(Mod.Settings.CaltropHasLimitedLifespan or false);
    local caltropLifespanContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);
    caltropBombDestroys = UI.CreateCheckBox(caltropLifespanContainer)
        .SetText("Bomb destroys")
        .SetIsChecked(Mod.Settings.CaltropBombDestroys or false);
    caltropAllyTriggers = UI.CreateCheckBox(optionalsHeading)
        .SetText("Allies trigger Caltrops")
        .SetIsChecked(Mod.Settings.CaltropAllyTriggers or false);

    -- Lifespan sub-options
    caltropHasLimitedLifespan.SetOnValueChanged(function()
        if(caltropHasLimitedLifespan.GetIsChecked()) then
            Create_Caltrop_Lifespan_SubOptions_UI(caltropLifespanContainer);
        else
           UI.Destroy(caltropLifespanHeading);
        end
    end);

     -- one time check for loading up from settings
    if(caltropHasLimitedLifespan.GetIsChecked()) then
        Create_Caltrop_Lifespan_SubOptions_UI(caltropLifespanContainer);
    end

    -- Tank sub-options
    caltropIsTankSpecialBehaviour.SetOnValueChanged(function()
        if(caltropIsTankSpecialBehaviour.GetIsChecked()) then
            Create_Caltrop_Tank_SubOptions_UI(caltropTankContainer);
        else
           UI.Destroy(caltropTankSupportHeading);
           caltropTanksIgnore.SetIsChecked(false);
           caltropTanksDestroy.SetIsChecked(false);
        end
    end);

     -- one time check for loading up from settings
    if(caltropIsTankSpecialBehaviour.GetIsChecked()) then
        Create_Caltrop_Tank_SubOptions_UI(caltropTankContainer);
    end
end

function Create_Caltrop_Lifespan_SubOptions_UI(rootParent)
    caltropLifespanHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(caltropLifespanHeading);
    UI.CreateLabel(horz).SetText('Number of turns before Caltrops are destroyed').SetPreferredWidth(290);
    caltropLifespan = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(2)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.CaltropLifespan or 2);
end

function Create_Caltrop_Tank_SubOptions_UI(rootParent)
    caltropTankSupportHeading = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(caltropTankSupportHeading).SetText("Tanks can not be trapped*").SetColor(BUTTON_COLOURS.DarkGray);

    caltropTankSpecialBehaviourGroup = UI.CreateRadioButtonGroup(caltropTankSupportHeading);

    caltropTanksIgnore = UI.CreateRadioButton(caltropTankSupportHeading).SetGroup(caltropTankSpecialBehaviourGroup)
        .SetText('Armies with Tanks ignore triggered Caltrops')
        .SetIsChecked(Mod.Settings.CaltropTanksIgnore or true);

    caltropTanksDestroy = UI.CreateRadioButton(caltropTankSupportHeading).SetGroup(caltropTankSpecialBehaviourGroup)
        .SetText('Tanks destroy Caltrops on entry/exit')
        .SetIsChecked(Mod.Settings.CaltropTanksDestroy or false);

    caltropTanksIgnore.SetOnValueChanged(function()
        if(caltropTanksIgnore.GetIsChecked()) then
            caltropTanksIgnore.SetInteractable(false);
        else
           caltropTanksIgnore.SetInteractable(true);
        end
    end);

    caltropTanksDestroy.SetOnValueChanged(function()
        if(caltropTanksDestroy.GetIsChecked()) then
            caltropTanksDestroy.SetInteractable(false);
        else
           caltropTanksDestroy.SetInteractable(true);
        end
    end);

    -- initial load
    if(caltropTanksIgnore.GetIsChecked()) then
        caltropTanksIgnore.SetInteractable(false);
        caltropTanksDestroy.SetInteractable(true);
    else
        caltropTanksIgnore.SetInteractable(true);
        caltropTanksDestroy.SetInteractable(false);
    end
end

function Create_BarbedWireEnabled_UI(rootParent)
    barbedWireEnabledVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    ---- Acquiring type
    local acquiringTypeHeading = UI.CreateVerticalLayoutGroup(barbedWireEnabledVHeading);
    UI.CreateLabel(acquiringTypeHeading)
        .SetText('Acquiring type:')
        .SetColor(SUBHEADING_COLOUR);
    local acquiringType = UI.CreateRadioButtonGroup(acquiringTypeHeading);

    local acquiringSubOptionsParent = UI.CreateVerticalLayoutGroup(barbedWireEnabledVHeading);

    isAcquiringTypeCard = UI.CreateRadioButton(acquiringTypeHeading).SetGroup(acquiringType)
        .SetText('Card')
        .SetIsChecked(Mod.Settings.isAcquiringTypeCard == nil or Mod.Settings.isAcquiringTypeCard);

    isAcquiringTypeCommerce = UI.CreateRadioButton(acquiringTypeHeading).SetGroup(acquiringType)
        .SetText('Commerce')
        .SetIsChecked(Mod.Settings.isAcquiringTypeCard ~= nil and not Mod.Settings.isAcquiringTypeCard);

    isAcquiringTypeCard.SetOnValueChanged(function()
        if (isAcquiringTypeCard.GetIsChecked()) then
            isAcquiringTypeCard.SetInteractable(false);
            isAcquiringTypeCommerce.SetInteractable(true);
            UI.Destroy(acquiringSubOptionsVGroup);
            Create_BarbedWireCard_SubOptions_UI(acquiringSubOptionsParent);
        end
    end);

    isAcquiringTypeCommerce.SetOnValueChanged(function()
        if (isAcquiringTypeCommerce.GetIsChecked()) then
            isAcquiringTypeCommerce.SetInteractable(false);
            isAcquiringTypeCard.SetInteractable(true);
            UI.Destroy(acquiringSubOptionsVGroup);
            Create_BarbedWireCommerce_SubOptions_UI(acquiringSubOptionsParent);
        end
    end);

    -- one time check for loading up from settings
    if (isAcquiringTypeCard.GetIsChecked()) then
        isAcquiringTypeCard.SetInteractable(false);
        Create_BarbedWireCard_SubOptions_UI(acquiringSubOptionsParent);
    else
        isAcquiringTypeCommerce.SetInteractable(false);
        Create_BarbedWireCommerce_SubOptions_UI(acquiringSubOptionsParent);
    end

    ---- Behaviour
    local barbedWireParentVHeading = UI.CreateVerticalLayoutGroup(barbedWireEnabledVHeading);
    Create_BarbedWire_Behaviour_UI(barbedWireParentVHeading);
end

function Create_BarbedWireCard_SubOptions_UI(rootParent)
    acquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Card:').SetColor(BUTTON_COLOURS.LightBlue);
    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    barbedWireNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.BarbedWireNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    barbedWireCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BarbedWireCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    barbedWireMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BarbedWireMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    barbedWireInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.BarbedWireInitialPieces or 1);
end

function Create_BarbedWireCommerce_SubOptions_UI(rootParent)
    acquiringSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Commerce:').SetColor(BUTTON_COLOURS.LightBlue);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Cost of a Barbed Wire').SetPreferredWidth(290);
    barbedWireCost = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(50)
        .SetValue(Mod.Settings.BarbedWireCost or 5);

    local horz = UI.CreateHorizontalLayoutGroup(acquiringSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('Maximum number of Barbed Wire a player can own at once').SetPreferredWidth(290);
    barbedWireMaxPerPlayer = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.BarbedWireMaxPerPlayer or 3);
end

function Create_BarbedWire_Behaviour_UI(rootParent)
    barbedWireVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local optionalsHeading = UI.CreateVerticalLayoutGroup(barbedWireVHeading);

    UI.CreateLabel(optionalsHeading)
        .SetText('Behaviour:')
        .SetColor(BUTTON_COLOURS.LightBlue);

    local triggerDurationHorz = UI.CreateHorizontalLayoutGroup(optionalsHeading);
    UI.CreateLabel(triggerDurationHorz)
        .SetText('Trigger duration')
        .SetPreferredWidth(290);

    barbedWireTriggerDuration = UI.CreateNumberInputField(triggerDurationHorz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.BarbedWireTriggerDuration or 1);

    barbedWireTrapsArmies = UI.CreateCheckBox(optionalsHeading)
        .SetText("Traps armies")
        .SetIsChecked(Mod.Settings.BarbedWireTrapsArmies == nil or Mod.Settings.BarbedWireTrapsArmies);
    barbedWireCancelsAirlifts = UI.CreateCheckBox(optionalsHeading)
        .SetText("Cancels Airlifts")
        .SetIsChecked(Mod.Settings.BarbedWireCancelsAirlifts or false);
    barbedWireTrapsSpecialUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Traps Special Units")
        .SetIsChecked(Mod.Settings.BarbedWireTrapsSpecialUnits or false);
    barbedWireOnlyTriggersOnTrappableUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Only trigger if trappable units attacked")
        .SetIsChecked(Mod.Settings.BarbedWireOnlyTriggersOnTrappableUnits == nil or Mod.Settings.BarbedWireOnlyTriggersOnTrappableUnits);
    barbedWireIsTankSpecialBehaviour = UI.CreateCheckBox(optionalsHeading)
        .SetText("Include Tank special behaviour")
        .SetIsChecked(Mod.Settings.BarbedWireIsTankSpecialBehaviour or false);
    local barbedWireTankContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);

    UI.CreateLabel(optionalsHeading).SetText("");

    barbedWireSingleUse = UI.CreateCheckBox(optionalsHeading)
        .SetText("Wire is single use (destroyed instead of resetting) ")
        .SetIsChecked(Mod.Settings.BarbedWireSingleUse or false);
    barbedWireHasLimitedLifespan = UI.CreateCheckBox(optionalsHeading)
        .SetText("Wire has a limited lifespan?")
        .SetIsChecked(Mod.Settings.BarbedWireHasLimitedLifespan or false);
    local barbedWireLifespanContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);
    barbedWireBombDestroys = UI.CreateCheckBox(barbedWireLifespanContainer)
        .SetText("Bomb destroys")
        .SetIsChecked(Mod.Settings.BarbedWireBombDestroys or false);
    barbedWireAllyTriggers = UI.CreateCheckBox(optionalsHeading)
        .SetText("Allies trigger barbed wire")
        .SetIsChecked(Mod.Settings.BarbedWireAllyTriggers or false);

    -- Lifespan sub-options
    barbedWireHasLimitedLifespan.SetOnValueChanged(function()
        if(barbedWireHasLimitedLifespan.GetIsChecked()) then
            Create_BarbedWire_Lifespan_SubOptions_UI(barbedWireLifespanContainer);
        else
           UI.Destroy(barbedWireLifespanHeading);
        end
    end);

     -- one time check for loading up from settings
    if(barbedWireHasLimitedLifespan.GetIsChecked()) then
        Create_BarbedWire_Lifespan_SubOptions_UI(barbedWireLifespanContainer);
    end

    -- Tank sub-options
    barbedWireIsTankSpecialBehaviour.SetOnValueChanged(function()
        if(barbedWireIsTankSpecialBehaviour.GetIsChecked()) then
            Create_BarbedWire_Tank_SubOptions_UI(barbedWireTankContainer);
        else
           UI.Destroy(barbedWireTankSupportHeading);
           barbedWireTanksIgnore.SetIsChecked(false);
           barbedWireTanksDestroy.SetIsChecked(false);
        end
    end);

     -- one time check for loading up from settings
    if(barbedWireIsTankSpecialBehaviour.GetIsChecked()) then
        Create_BarbedWire_Tank_SubOptions_UI(barbedWireTankContainer);
    end
end

function Create_BarbedWire_Lifespan_SubOptions_UI(rootParent)
    barbedWireLifespanHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(barbedWireLifespanHeading);
    UI.CreateLabel(horz).SetText('Number of turns before wire is destroyed').SetPreferredWidth(290);
    barbedWireLifespan = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(2)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.BarbedWireLifespan or 2);
end

function Create_BarbedWire_Tank_SubOptions_UI(rootParent)
    barbedWireTankSupportHeading = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(barbedWireTankSupportHeading).SetText("Tanks can not be trapped*").SetColor(BUTTON_COLOURS.DarkGray);

    barbedWireTankSpecialBehaviourGroup = UI.CreateRadioButtonGroup(barbedWireTankSupportHeading);

    barbedWireTanksIgnore = UI.CreateRadioButton(barbedWireTankSupportHeading).SetGroup(barbedWireTankSpecialBehaviourGroup)
        .SetText('Armies with Tanks ignore triggered barbed wire')
        .SetIsChecked(Mod.Settings.BarbedWireTanksIgnore or true);

    barbedWireTanksDestroy = UI.CreateRadioButton(barbedWireTankSupportHeading).SetGroup(barbedWireTankSpecialBehaviourGroup)
        .SetText('Tanks destroy barbed wire on entry/exit')
        .SetIsChecked(Mod.Settings.BarbedWireTanksDestroy or false);

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
