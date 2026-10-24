require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    Create_FlakGunCard_SubOptions_UI(mainModUI);
end

function Create_FlakGunCard_SubOptions_UI(rootParent)
    flakGunCardVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(flakGunCardVHeading).SetText("Card Settings:").SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    flakGunNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.FlakGunNumPieces or 9);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    flakGunCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FlakGunCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    flakGunMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FlakGunMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    flakGunInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FlakGunInitialPieces or 0);

    UI.CreateLabel(flakGunCardVHeading).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Area of effect').SetPreferredWidth(290);
    flakGunAreaOfEffect = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FlakGunAreaOfEffect or 1);
    UI.CreateLabel(flakGunCardVHeading).SetText('0 = target only, 1 = hits surrounding territories as well*').SetColor(BUTTON_COLOURS.DarkGray);


    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Flak gun rounds').SetPreferredWidth(290);
    flakGunRounds = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FlakGunRounds or 3);
    UI.CreateLabel(flakGunCardVHeading).SetText('Values greater than 1 will provide temporary (discards at end of turn) copies of the card each turn*').SetColor(BUTTON_COLOURS.DarkGray);

    UI.CreateEmpty(flakGunCardVHeading).SetPreferredHeight(5);

    flakGunFriendlyFire = UI.CreateCheckBox(flakGunCardVHeading)
        .SetText('Enable friendly fire')
        .SetIsChecked(Mod.Settings.FlakGunFriendlyFire or false);

    UI.CreateEmpty(flakGunCardVHeading).SetPreferredHeight(10);

    UI.CreateLabel(flakGunCardVHeading).SetText('Damage Types:').SetColor(SUBHEADING_COLOUR);

    -- always on - locked rather than offered as a real choice, so it can never be unchecked
    flakGunAirliftInteractionEnabled = UI.CreateCheckBox(flakGunCardVHeading)
        .SetText('Enable Airlift Interaction')
        .SetIsChecked(true)
        .SetInteractable(false);

    local airliftInteractionOptionsParent = UI.CreateVerticalLayoutGroup(flakGunCardVHeading);
    Create_FlakGunAirliftInteraction_SubOptions_UI(airliftInteractionOptionsParent);
end

---Builds the Airlift Source and Airlift Destination headers shown once Enable Airlift Interaction is checked.
---@param rootParent RootParent
function Create_FlakGunAirliftInteraction_SubOptions_UI(rootParent)
    flakGunAirliftInteractionVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    Create_FlakGunHitsAirliftSource_UI(flakGunAirliftInteractionVHeading);
    Create_FlakGunHitsAirliftDestination_UI(flakGunAirliftInteractionVHeading);
end

---@param rootParent RootParent
function Create_FlakGunHitsAirliftSource_UI(rootParent)
    local sectionVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(sectionVHeading).SetText('Airlift Source:');

    local sourceActionGroup = UI.CreateRadioButtonGroup(sectionVHeading);

    flakGunSourceCancelsAirlift = UI.CreateRadioButton(sectionVHeading)
        .SetGroup(sourceActionGroup)
        .SetText('Cancels airlift')
        .SetIsChecked(not Mod.Settings.FlakGunSourceDamagesArmies);

    flakGunSourceDamagesArmies = UI.CreateRadioButton(sectionVHeading)
        .SetGroup(sourceActionGroup)
        .SetText('Damages armies')
        .SetIsChecked(Mod.Settings.FlakGunSourceDamagesArmies or false);

    flakGunSourceCancelsAirlift.SetOnValueChanged(function()
        if (flakGunSourceCancelsAirlift.GetIsChecked()) then
            flakGunSourceCancelsAirlift.SetInteractable(false);
        else
            flakGunSourceCancelsAirlift.SetInteractable(true);
        end
    end);

    local sourceDamageOptionsParent = UI.CreateVerticalLayoutGroup(sectionVHeading);

    flakGunSourceDamagesArmies.SetOnValueChanged(function()
        if (flakGunSourceDamagesArmies.GetIsChecked()) then
            Create_FlakGunSourceDamage_SubOptions_UI(sourceDamageOptionsParent);
            flakGunSourceDamagesArmies.SetInteractable(false);
        else
            UI.Destroy(flakGunSourceDamageVHeading);
            flakGunSourceDamagesArmies.SetInteractable(true);
        end
    end);

    if (flakGunSourceCancelsAirlift.GetIsChecked()) then -- one time check for loading up from settings
        flakGunSourceCancelsAirlift.SetInteractable(false);
    end

    if (flakGunSourceDamagesArmies.GetIsChecked()) then -- one time check for loading up from settings
        Create_FlakGunSourceDamage_SubOptions_UI(sourceDamageOptionsParent);
        flakGunSourceDamagesArmies.SetInteractable(false);
    end
end

function Create_FlakGunSourceDamage_SubOptions_UI(rootParent)
    flakGunSourceDamageVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunSourceDamageVHeading);
    UI.CreateLabel(horz).SetText('% damage dealt to transported armies').SetPreferredWidth(290);
    flakGunSourceDamagePercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.FlakGunSourceDamagePercent or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunSourceDamageVHeading);
    UI.CreateLabel(horz).SetText('Minimum damage dealt to transported armies').SetPreferredWidth(290);
    flakGunSourceMinDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.FlakGunSourceMinDamage or 0);
end

---@param rootParent RootParent
function Create_FlakGunHitsAirliftDestination_UI(rootParent)
    local sectionVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(sectionVHeading).SetText('Airlift Destination:');

    local destinationActionGroup = UI.CreateRadioButtonGroup(sectionVHeading);

    flakGunDestinationCancelsAirlift = UI.CreateRadioButton(sectionVHeading)
        .SetGroup(destinationActionGroup)
        .SetText('Cancels airlift')
        .SetIsChecked(Mod.Settings.FlakGunDestinationDamagesArmies == false);

    flakGunDestinationDamagesArmies = UI.CreateRadioButton(sectionVHeading)
        .SetGroup(destinationActionGroup)
        .SetText('Damages armies')
        .SetIsChecked(Mod.Settings.FlakGunDestinationDamagesArmies ~= false);

    flakGunDestinationCancelsAirlift.SetOnValueChanged(function()
        if (flakGunDestinationCancelsAirlift.GetIsChecked()) then
            flakGunDestinationCancelsAirlift.SetInteractable(false);
        else
            flakGunDestinationCancelsAirlift.SetInteractable(true);
        end
    end);

    local destinationDamageOptionsParent = UI.CreateVerticalLayoutGroup(sectionVHeading);

    flakGunDestinationDamagesArmies.SetOnValueChanged(function()
        if (flakGunDestinationDamagesArmies.GetIsChecked()) then
            Create_FlakGunDestinationDamage_SubOptions_UI(destinationDamageOptionsParent);
            flakGunDestinationDamagesArmies.SetInteractable(false);
        else
            UI.Destroy(flakGunDestinationDamageVHeading);
            flakGunDestinationDamagesArmies.SetInteractable(true);
        end
    end);

    if (flakGunDestinationCancelsAirlift.GetIsChecked()) then -- one time check for loading up from settings
        flakGunDestinationCancelsAirlift.SetInteractable(false);
    end

    if (flakGunDestinationDamagesArmies.GetIsChecked()) then -- one time check for loading up from settings
        Create_FlakGunDestinationDamage_SubOptions_UI(destinationDamageOptionsParent);
        flakGunDestinationDamagesArmies.SetInteractable(false);
    end
end

function Create_FlakGunDestinationDamage_SubOptions_UI(rootParent)
    flakGunDestinationDamageVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunDestinationDamageVHeading);
    UI.CreateLabel(horz).SetText('% damage dealt to transported armies').SetPreferredWidth(290);
    flakGunDestinationDamagePercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.FlakGunDestinationDamagePercent or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunDestinationDamageVHeading);
    UI.CreateLabel(horz).SetText('Minimum damage dealt to transported armies').SetPreferredWidth(290);
    flakGunDestinationMinDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.FlakGunDestinationMinDamage or 0);
end
