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
