require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---- include cards
    local includeCardsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(includeCardsHeading).SetText('Include Cards:').SetColor(SUBHEADING_COLOUR);

    includeSpyPlaneCard = UI.CreateCheckBox(includeCardsHeading)
    .SetText("Include Spy Plane Card")
    .SetIsChecked(Mod.Settings.IncludeSpyPlaneCard or false);
    local spyPlaneCardParentVHeading = UI.CreateVerticalLayoutGroup(includeCardsHeading);

    includeSpyPlaneCard.SetOnValueChanged(function()
        if(includeSpyPlaneCard.GetIsChecked()) then
            Create_SpyPlaneCard_SubOptions_UI(spyPlaneCardParentVHeading);
        else
            UI.Destroy(spyPlaneCardVHeading);
        end
    end);

    includeFlakGunCard = UI.CreateCheckBox(includeCardsHeading)
    .SetText("Include Flak Gun Card")
    .SetIsChecked(Mod.Settings.IncludeFlakGunCard or false);
    local flakGunCardParentVHeading = UI.CreateVerticalLayoutGroup(includeCardsHeading);

    includeFlakGunCard.SetOnValueChanged(function()
        if(includeFlakGunCard.GetIsChecked()) then
            Create_FlakGunCard_SubOptions_UI(flakGunCardParentVHeading);
        else
            UI.Destroy(flakGunCardVHeading);
        end
    end);

    -- one time check for loading up from settings
    if(includeSpyPlaneCard.GetIsChecked()) then
        Create_SpyPlaneCard_SubOptions_UI(spyPlaneCardParentVHeading);
    end

    if(includeFlakGunCard.GetIsChecked()) then
        Create_FlakGunCard_SubOptions_UI(flakGunCardParentVHeading);
    end
end

function Create_SpyPlaneCard_SubOptions_UI(rootParent)
    spyPlaneCardVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(spyPlaneCardVHeading).SetText("Card Settings:").SetColor(BUTTON_COLOURS.LightBlue);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    spyPlaneNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.SpyPlaneNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    spyPlaneCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.SpyPlaneCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    spyPlaneMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.SpyPlaneMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    spyPlaneInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.SpyPlaneInitialPieces or 0);

    UI.CreateLabel(spyPlaneCardVHeading).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(horz).SetText('Inclusion generosity').SetPreferredWidth(290);
    spyPlaneInclusionGenerosity = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(25)
        .SetSliderMaxValue(300)
        .SetValue(Mod.Settings.SpyPlaneInclusionGenerosity or 50);
    UI.CreateLabel(spyPlaneCardVHeading).SetText('Territories are included based on the distance from their centerpoint to the latest step of the plane as it moves. Experiment with how this number feels for your chosen map.').SetColor(BUTTON_COLOURS.DarkGray);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(horz).SetText('Maximum flight distance').SetPreferredWidth(290);
    spyPlaneMaxFlightDistance = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(200)
        .SetSliderMaxValue(2000)
        .SetValue(Mod.Settings.SpyPlaneMaxFlightDistance or 300);

    local flightStyleHeading = UI.CreateVerticalLayoutGroup(spyPlaneCardVHeading);
    UI.CreateLabel(flightStyleHeading).SetText('Flight style:');
    local flightStyleGroup = UI.CreateRadioButtonGroup(flightStyleHeading);

    spyPlaneFlightStyleInstant = UI.CreateRadioButton(flightStyleHeading)
    .SetGroup(flightStyleGroup)
    .SetText('Instant - all territories from A-B are shown')
    .SetIsChecked(Mod.Settings.SpyPlaneFlightStyleInstant or true);

    spyPlaneFlightStyleSteps = UI.CreateRadioButton(flightStyleHeading)
    .SetGroup(flightStyleGroup)
    .SetText('Steps - territories are shown as the plane moves')
    .SetIsChecked(Mod.Settings.SpyPlaneFlightStyleSteps or false);

    local flightStyleSubOptionsHeading = UI.CreateVerticalLayoutGroup(spyPlaneCardVHeading);

    spyPlaneFlightStyleInstant.SetOnValueChanged(function()
        if (spyPlaneFlightStyleInstant.GetIsChecked()) then
            spyPlaneFlightStyleInstant.SetInteractable(false);
            UI.Destroy(spyPlaneFlightStepsVHeading);
        else
            spyPlaneFlightStyleInstant.SetInteractable(true);
        end
    end);

    spyPlaneFlightStyleSteps.SetOnValueChanged(function()
        if (spyPlaneFlightStyleSteps.GetIsChecked()) then
            spyPlaneFlightStyleSteps.SetInteractable(false);
            Create_SpyPlaneFlightSteps_SubOptions_UI(flightStyleSubOptionsHeading);
        else
            spyPlaneFlightStyleSteps.SetInteractable(true);
        end
    end);

    if (spyPlaneFlightStyleSteps.GetIsChecked()) then
        spyPlaneFlightStyleSteps.SetInteractable(false);
        Create_SpyPlaneFlightSteps_SubOptions_UI(flightStyleSubOptionsHeading);
    else
        spyPlaneFlightStyleInstant.SetInteractable(false);
    end
end

function Create_SpyPlaneFlightSteps_SubOptions_UI(rootParent)
    spyPlaneFlightStepsVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(spyPlaneFlightStepsVHeading);
    UI.CreateLabel(horz).SetText('Flight steps').SetPreferredWidth(290);
    spyPlaneFlightSteps = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.SpyPlaneFlightSteps or 5);
end

function Create_FlakGunCard_SubOptions_UI(rootParent)
    flakGunCardVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(flakGunCardVHeading).SetText("Card Settings:").SetColor(BUTTON_COLOURS.OrangeRed);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    flakGunNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.FlakGunNumPieces or 5);

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
        .SetValue(Mod.Settings.FlakGunAreaOfEffect or 0);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunCardVHeading);
    UI.CreateLabel(horz).SetText('Flak gun rounds').SetPreferredWidth(290);
    flakGunRounds = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FlakGunRounds or 1);
    UI.CreateLabel(flakGunCardVHeading).SetText('Values greater than 1 will provide temporary copies of the card each turn').SetColor(BUTTON_COLOURS.DarkGray);

    flakGunFriendlyFire = UI.CreateCheckBox(flakGunCardVHeading)
        .SetText('Enable friendly fire')
        .SetIsChecked(Mod.Settings.FlakGunFriendlyFire or false);

    UI.CreateLabel(flakGunCardVHeading).SetText('Damage Type:');

    flakGunTargetingSpyPlaneDestroys = UI.CreateCheckBox(flakGunCardVHeading)
        .SetText('Targeting spy plane destroys it')
        .SetIsChecked(Mod.Settings.FlakGunTargetingSpyPlaneDestroys or false);

    flakGunTargetingAirliftSourceCancels = UI.CreateCheckBox(flakGunCardVHeading)
        .SetText('Targeting airlift source cancels airlift')
        .SetIsChecked(Mod.Settings.FlakGunTargetingAirliftSourceCancels or false);

    flakGunTargetingAirliftDestinationHurts = UI.CreateCheckBox(flakGunCardVHeading)
        .SetText('Targeting airlift destination hurts transported armies')
        .SetIsChecked(Mod.Settings.FlakGunTargetingAirliftDestinationHurts or false);
    local airliftDestinationHurtsSubOptionsHeading = UI.CreateVerticalLayoutGroup(flakGunCardVHeading);

    flakGunTargetingAirliftDestinationHurts.SetOnValueChanged(function()
        if(flakGunTargetingAirliftDestinationHurts.GetIsChecked()) then
            Create_FlakGunAirliftDestinationHurts_SubOptions_UI(airliftDestinationHurtsSubOptionsHeading);
        else
            UI.Destroy(flakGunAirliftDestinationHurtsVHeading);
        end
    end);

    if(flakGunTargetingAirliftDestinationHurts.GetIsChecked()) then
        Create_FlakGunAirliftDestinationHurts_SubOptions_UI(airliftDestinationHurtsSubOptionsHeading);
    end
end

function Create_FlakGunAirliftDestinationHurts_SubOptions_UI(rootParent)
    flakGunAirliftDestinationHurtsVHeading = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunAirliftDestinationHurtsVHeading);
    UI.CreateLabel(horz).SetText('% damage dealt to transported armies').SetPreferredWidth(290);
    flakGunAirliftDamagePercent = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.FlakGunAirliftDamagePercent or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(flakGunAirliftDestinationHurtsVHeading);
    UI.CreateLabel(horz).SetText('Minimum damage dealt to transported armies').SetPreferredWidth(290);
    flakGunAirliftMinDamage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.FlakGunAirliftMinDamage or 0);
end
