require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
Create_UI_Controls(rootParent);

end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Mod Settings:').SetColor(SUBHEADING_COLOUR);
    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Card duration:').SetPreferredWidth(290);
    cardDuration = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardDuration or 2);
    UI.CreateLabel(mainModUI).SetText('Values > 1 give you temporary copy of the card (that discard if unused) each turn beyond the first*').SetColor(BUTTON_COLOURS.DarkGray);


    local neutralArmyGivesVisionHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    neutralArmyGivesVision = UI.CreateCheckBox(neutralArmyGivesVisionHeading).SetText("Neutral army gives vision")
    .SetIsChecked(Mod.Settings.NeutralArmyGivesVision or false);

    neutralArmyGivesVision.SetOnValueChanged(function()
        if (neutralArmyGivesVision.GetIsChecked()) then
            Create_NeutralArmyGivesVision_SubOptions_UI(neutralArmyGivesVisionHeading);
        else
            UI.Destroy(neutralArmyGivesVisionSubOptionsHeading);
        end
    end);

    -- one time check for loading up from settings
    if (neutralArmyGivesVision.GetIsChecked()) then
        Create_NeutralArmyGivesVision_SubOptions_UI(neutralArmyGivesVisionHeading);
    end

    UI.CreateLabel(mainModUI).SetText('Card Settings:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.NumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    cardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.Weight or 1.0);
    
    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    minPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.MinPieces or 1);
    
    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    initialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.InitialPieces or 0);
end

function Create_NeutralArmyGivesVision_SubOptions_UI(rootParent)
    neutralArmyGivesVisionSubOptionsHeading = UI.CreateVerticalLayoutGroup(rootParent);
    visionMethodGroup = UI.CreateRadioButtonGroup(neutralArmyGivesVisionSubOptionsHeading);

    visionMethodFreeReconCard = UI.CreateRadioButton(neutralArmyGivesVisionSubOptionsHeading).SetGroup(visionMethodGroup)
    .SetText('Play free recon card')
    .SetIsChecked(Mod.Settings.VisionMethodFreeReconCard or true);
    
    visionMethodManual = UI.CreateRadioButton(neutralArmyGivesVisionSubOptionsHeading).SetGroup(visionMethodGroup)
    .SetText('Mod gives vision manually')
    .SetIsChecked(Mod.Settings.VisionMethodManual or false);
end
