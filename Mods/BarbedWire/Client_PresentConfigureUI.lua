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
        .SetColor(BUTTON_COLOURS.LightBlue);
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
    caltropTrapsSpecialUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Traps Special Units")
        .SetIsChecked(Mod.Settings.CaltropTrapsSpecialUnits == nil or Mod.Settings.CaltropTrapsSpecialUnits);
    caltropOnlyTriggersOnTrappableUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Only trigger if trappable units attacked")
        .SetIsChecked(Mod.Settings.CaltropOnlyTriggersOnTrappableUnits == nil or Mod.Settings.CaltropOnlyTriggersOnTrappableUnits);
    UI.CreateLabel(optionalsHeading).SetText("");

    caltropIsImmuneUnitEnabled = UI.CreateCheckBox(optionalsHeading)
        .SetText("Enable immune special unit")
        .SetIsChecked(Mod.Settings.CaltropIsImmuneUnitEnabled or false);
    local caltropImmuneUnitContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);

    UI.CreateLabel(optionalsHeading).SetText("");

    UI.CreateLabel(optionalsHeading).SetText('Lifespan Behaviour').SetColor(BUTTON_COLOURS.LightBlue);
    caltropBombDestroys = UI.CreateCheckBox(optionalsHeading)
        .SetText("Bomb destroys")
        .SetIsChecked(Mod.Settings.CaltropBombDestroys or false);
    caltropSingleUse = UI.CreateCheckBox(optionalsHeading)
        .SetText("Caltrops are single use (destroyed instead of resetting) ")
        .SetIsChecked(Mod.Settings.CaltropSingleUse or false);
    caltropHasLimitedLifespan = UI.CreateCheckBox(optionalsHeading)
        .SetText("Caltrops have a limited lifespan?")
        .SetIsChecked(Mod.Settings.CaltropHasLimitedLifespan or false);
    local caltropLifespanContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);
    UI.CreateLabel(optionalsHeading).SetText('Misc.').SetColor(BUTTON_COLOURS.LightBlue);
    caltropAllyTriggers = UI.CreateCheckBox(optionalsHeading)
        .SetText("Allies trigger Caltrops")
        .SetIsChecked(Mod.Settings.CaltropAllyTriggers or false);
    caltropCancelsAirlifts = UI.CreateCheckBox(optionalsHeading)
        .SetText("Cancels Airlifts")
        .SetIsChecked(Mod.Settings.CaltropCancelsAirlifts or false);
    UI.CreateLabel(optionalsHeading).SetText("Applies to both primed and triggered Caltrops*").SetColor(BUTTON_COLOURS.DarkGray);

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

    -- Immune unit sub-options
    caltropIsImmuneUnitEnabled.SetOnValueChanged(function()
        if(caltropIsImmuneUnitEnabled.GetIsChecked()) then
            Create_Caltrop_ImmuneUnit_SubOptions_UI(caltropImmuneUnitContainer);
        else
           UI.Destroy(caltropImmuneUnitSupportHeading);
           caltropImmuneUnitIgnores.SetIsChecked(false);
           caltropImmuneUnitDestroys.SetIsChecked(false);
        end
    end);

     -- one time check for loading up from settings
    if(caltropIsImmuneUnitEnabled.GetIsChecked()) then
        Create_Caltrop_ImmuneUnit_SubOptions_UI(caltropImmuneUnitContainer);
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

function Create_Caltrop_ImmuneUnit_SubOptions_UI(rootParent)
    caltropImmuneUnitSupportHeading = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(caltropImmuneUnitSupportHeading).SetText("Immune unit can not be trapped*").SetColor(BUTTON_COLOURS.DarkGray);

    local unitNameHorz = UI.CreateHorizontalLayoutGroup(caltropImmuneUnitSupportHeading);
    UI.CreateLabel(unitNameHorz).SetText('Immune unit name').SetPreferredWidth(290);
    caltropImmuneUnitName = UI.CreateTextInputField(unitNameHorz)
        .SetPlaceholderText('Tank')
        .SetText(Mod.Settings.CaltropImmuneUnitName or 'Tank')
        .SetPreferredWidth(200);

    -- one radio group: ignore / destroy / none. None needs no setting of its own - it is just neither of the
    -- other two saved, and is also the default.
    local mode = 'none';
    if (Mod.Settings.CaltropImmuneUnitDestroys) then
        mode = 'destroy';
    elseif (Mod.Settings.CaltropImmuneUnitIgnores) then
        mode = 'ignore';
    end

    UI.CreateLabel(caltropImmuneUnitSupportHeading).SetText('Additional Behaviour');
    caltropImmuneUnitBehaviourGroup = UI.CreateRadioButtonGroup(caltropImmuneUnitSupportHeading);

    caltropImmuneUnitIgnores = UI.CreateRadioButton(caltropImmuneUnitSupportHeading).SetGroup(caltropImmuneUnitBehaviourGroup)
        .SetText('Armies/special units share the immunity')
        .SetIsChecked(mode == 'ignore');

    caltropImmuneUnitDestroys = UI.CreateRadioButton(caltropImmuneUnitSupportHeading).SetGroup(caltropImmuneUnitBehaviourGroup)
        .SetText('Immune unit destroys Caltrops on entry/exit')
        .SetIsChecked(mode == 'destroy');

    caltropImmuneUnitNone = UI.CreateRadioButton(caltropImmuneUnitSupportHeading).SetGroup(caltropImmuneUnitBehaviourGroup)
        .SetText('None')
        .SetIsChecked(mode == 'none');

    -- the selected radio can't be clicked again (you can't unselect a radio group)
    for _, radio in ipairs({ caltropImmuneUnitIgnores, caltropImmuneUnitDestroys, caltropImmuneUnitNone }) do
        radio.SetOnValueChanged(function()
            radio.SetInteractable(not radio.GetIsChecked());
        end);
        -- initial load
        radio.SetInteractable(not radio.GetIsChecked());
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

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Card:').SetColor(SUBHEADING_COLOUR);
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

    UI.CreateLabel(acquiringSubOptionsVGroup).SetText('Commerce:').SetColor(SUBHEADING_COLOUR);

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
        .SetColor(SUBHEADING_COLOUR);

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
    barbedWireTrapsSpecialUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Traps Special Units")
        .SetIsChecked(Mod.Settings.BarbedWireTrapsSpecialUnits or false);
    barbedWireOnlyTriggersOnTrappableUnits = UI.CreateCheckBox(optionalsHeading)
        .SetText("Only trigger if trappable units attacked")
        .SetIsChecked(Mod.Settings.BarbedWireOnlyTriggersOnTrappableUnits == nil or Mod.Settings.BarbedWireOnlyTriggersOnTrappableUnits);
    UI.CreateLabel(optionalsHeading).SetText("");

    barbedWireIsImmuneUnitEnabled = UI.CreateCheckBox(optionalsHeading)
        .SetText("Enable immune special unit")
        .SetIsChecked(Mod.Settings.BarbedWireIsImmuneUnitEnabled or false);
    local barbedWireImmuneUnitContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);

    UI.CreateLabel(optionalsHeading).SetText("");

    UI.CreateLabel(optionalsHeading).SetText('Lifespan Behaviour').SetColor(SUBHEADING_COLOUR);
    barbedWireBombDestroys = UI.CreateCheckBox(optionalsHeading)
        .SetText("Bomb destroys")
        .SetIsChecked(Mod.Settings.BarbedWireBombDestroys or false);
    barbedWireSingleUse = UI.CreateCheckBox(optionalsHeading)
        .SetText("Wire is single use (destroyed instead of resetting) ")
        .SetIsChecked(Mod.Settings.BarbedWireSingleUse or false);
    barbedWireHasLimitedLifespan = UI.CreateCheckBox(optionalsHeading)
        .SetText("Wire has a limited lifespan?")
        .SetIsChecked(Mod.Settings.BarbedWireHasLimitedLifespan or false);
    local barbedWireLifespanContainer = UI.CreateVerticalLayoutGroup(optionalsHeading);
    UI.CreateLabel(optionalsHeading).SetText('Misc.').SetColor(SUBHEADING_COLOUR);
    barbedWireAllyTriggers = UI.CreateCheckBox(optionalsHeading)
        .SetText("Allies trigger barbed wire")
        .SetIsChecked(Mod.Settings.BarbedWireAllyTriggers or false);
    barbedWireCancelsAirlifts = UI.CreateCheckBox(optionalsHeading)
        .SetText("Cancels Airlifts")
        .SetIsChecked(Mod.Settings.BarbedWireCancelsAirlifts or false);
    UI.CreateLabel(optionalsHeading).SetText("Applies to both primed and triggered barbed wire*").SetColor(BUTTON_COLOURS.DarkGray);

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

    -- Immune unit sub-options
    barbedWireIsImmuneUnitEnabled.SetOnValueChanged(function()
        if(barbedWireIsImmuneUnitEnabled.GetIsChecked()) then
            Create_BarbedWire_ImmuneUnit_SubOptions_UI(barbedWireImmuneUnitContainer);
        else
           UI.Destroy(barbedWireImmuneUnitSupportHeading);
           barbedWireImmuneUnitIgnores.SetIsChecked(false);
           barbedWireImmuneUnitDestroys.SetIsChecked(false);
        end
    end);

     -- one time check for loading up from settings
    if(barbedWireIsImmuneUnitEnabled.GetIsChecked()) then
        Create_BarbedWire_ImmuneUnit_SubOptions_UI(barbedWireImmuneUnitContainer);
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

function Create_BarbedWire_ImmuneUnit_SubOptions_UI(rootParent)
    barbedWireImmuneUnitSupportHeading = UI.CreateVerticalLayoutGroup(rootParent);

    UI.CreateLabel(barbedWireImmuneUnitSupportHeading).SetText("Immune unit can not be trapped*").SetColor(BUTTON_COLOURS.DarkGray);

    local unitNameHorz = UI.CreateHorizontalLayoutGroup(barbedWireImmuneUnitSupportHeading);
    UI.CreateLabel(unitNameHorz).SetText('Immune unit name').SetPreferredWidth(290);
    barbedWireImmuneUnitName = UI.CreateTextInputField(unitNameHorz)
        .SetPlaceholderText('Tank')
        .SetText(Mod.Settings.BarbedWireImmuneUnitName or 'Tank')
        .SetPreferredWidth(200);

    -- one radio group: ignore / destroy / none. None needs no setting of its own - it is just neither of the
    -- other two saved, and is also the default.
    local mode = 'none';
    if (Mod.Settings.BarbedWireImmuneUnitDestroys) then
        mode = 'destroy';
    elseif (Mod.Settings.BarbedWireImmuneUnitIgnores) then
        mode = 'ignore';
    end

    UI.CreateLabel(barbedWireImmuneUnitSupportHeading).SetText('Additional Behaviour');
    barbedWireImmuneUnitBehaviourGroup = UI.CreateRadioButtonGroup(barbedWireImmuneUnitSupportHeading);

    barbedWireImmuneUnitIgnores = UI.CreateRadioButton(barbedWireImmuneUnitSupportHeading).SetGroup(barbedWireImmuneUnitBehaviourGroup)
        .SetText('Armies/special units share the immunity')
        .SetIsChecked(mode == 'ignore');

    barbedWireImmuneUnitDestroys = UI.CreateRadioButton(barbedWireImmuneUnitSupportHeading).SetGroup(barbedWireImmuneUnitBehaviourGroup)
        .SetText('Immune unit destroys barbed wire on entry/exit')
        .SetIsChecked(mode == 'destroy');

    barbedWireImmuneUnitNone = UI.CreateRadioButton(barbedWireImmuneUnitSupportHeading).SetGroup(barbedWireImmuneUnitBehaviourGroup)
        .SetText('None')
        .SetIsChecked(mode == 'none');

    -- the selected radio can't be clicked again (you can't unselect a radio group)
    for _, radio in ipairs({ barbedWireImmuneUnitIgnores, barbedWireImmuneUnitDestroys, barbedWireImmuneUnitNone }) do
        radio.SetOnValueChanged(function()
            radio.SetInteractable(not radio.GetIsChecked());
        end);
        -- initial load
        radio.SetInteractable(not radio.GetIsChecked());
    end
end
