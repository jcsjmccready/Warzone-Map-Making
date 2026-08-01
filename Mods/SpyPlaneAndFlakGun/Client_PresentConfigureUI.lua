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
end
