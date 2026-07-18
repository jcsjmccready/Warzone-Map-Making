require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);
    UI.CreateLabel(mainModUI).SetText('In team games, if feared or charmed, army movement will attack teammates*');

    ---- include cards
    local includeCardsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(includeCardsHeading).SetText('Include Cards:').SetColor(SUBHEADING_COLOUR);

    -- Card acquiring type
    includeFearCard = UI.CreateCheckBox(includeCardsHeading).SetText("Include Fear Card").SetIsChecked(Mod.Settings.IncludeFearCard or false);
    local fearCardParentVHeading = UI.CreateVerticalLayoutGroup(includeCardsHeading);

    includeFearCard.SetOnValueChanged(function() 
        if(includeFearCard.GetIsChecked()) then
            Create_FearCard_SubOptions_UI(fearCardParentVHeading);
        else
           UI.Destroy(fearCardVHeading);
        end
    end);

    includeCharmCard = UI.CreateCheckBox(includeCardsHeading).SetText("Include Charm Card").SetIsChecked(Mod.Settings.IncludeCharmCard or false);
    local charmCardParentVHeading = UI.CreateVerticalLayoutGroup(includeCardsHeading);

    includeCharmCard.SetOnValueChanged(function() 
        if(includeCharmCard.GetIsChecked()) then
            Create_CharmCard_SubOptions_UI(charmCardParentVHeading);
        else
           UI.Destroy(charmCardVHeading);
        end
    end);

     -- one time check for loading up from settings
    if(includeFearCard.GetIsChecked()) then
        Create_FearCard_SubOptions_UI(fearCardParentVHeading);
    end

    if(includeCharmCard.GetIsChecked()) then
        Create_CharmCard_SubOptions_UI(charmCardParentVHeading);
    end
end

function Update_FalloffExamplesLabel(exampleLabel, falloffField, distanceField)
    local falloff = falloffField.GetValue() or 0;
    local maxDistance = math.max(1, distanceField.GetValue() or 1);
    local examples = {};

    for distance = 0, maxDistance do
        local percentAffected = math.floor((falloff ^ distance) * 100 + 0.5) / 100;
        table.insert(examples, string.format('D%s=%s%%', distance, percentAffected * 100));
    end

    exampleLabel.SetText('Falloff examples: ' .. table.concat(examples, ', '));
end

function Create_FearCard_SubOptions_UI(rootParent)
    fearCardVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(fearCardVHeading).SetText("Creates a structure that 'fears' armies, forcing them to move away from it.");
    UI.CreateLabel(charmCardVHeading).SetText("All armies on the selected territory are forced to leave*");
    UI.CreateLabel(fearCardVHeading).SetText("Fear Settings:").SetColor(BUTTON_COLOURS.ElectricPurple);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Distance the fear affects').SetPreferredWidth(290);
    fearDistance = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(3)
        .SetValue(Mod.Settings.FearDistance or 1);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Duration of the fear effect').SetPreferredWidth(290);
    fearDuration = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FearDuration or 2);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Falloff % of the fear effect per step').SetPreferredWidth(290);
    fearFalloff = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.FearFalloff or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    local fallOffExamples = UI.CreateLabel(horz).SetText('Falloff examples: ').SetPreferredWidth(290).SetColor(BUTTON_COLOURS.DarkGray);

    local refreshExamplesButton = UI.CreateButton(horz)
        .SetText('Refresh')
        .SetPreferredWidth(150);

    refreshExamplesButton.SetOnClick(function()
        Update_FalloffExamplesLabel(fallOffExamples, fearFalloff, fearDistance);
    end);

    Update_FalloffExamplesLabel(fallOffExamples, fearFalloff, fearDistance);
        
    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Maximum fear % where Special Units Are Immune').SetPreferredWidth(290);
    fearSpecialUnitThreshold = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.FearSpecialUnitThreshold or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Can only create on own territories').SetPreferredWidth(290);
    fearCreateOnlyOwnTerritories = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.FearCreateOnlyOwnTerritories or false).SetText('');

    UI.CreateLabel(fearCardVHeading).SetText("Card Settings:").SetColor(BUTTON_COLOURS.ElectricPurple);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Number of Pieces to divide the card into').SetFlexibleWidth(290);
    fearNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.FearNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    fearCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FearWeight or 1.0);
    
    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    fearMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FearMinPieces or 1);
    
    local horz = UI.CreateHorizontalLayoutGroup(fearCardVHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    fearInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.FearInitialPieces or 5);
end


function Create_CharmCard_SubOptions_UI(rootParent)
    charmCardVHeading = UI.CreateVerticalLayoutGroup(rootParent);
    UI.CreateLabel(charmCardVHeading).SetText("Creates a structure that forces armies to move towards it.");
    UI.CreateLabel(charmCardVHeading).SetText("Armies on the selected territory can not leave*");
    UI.CreateLabel(charmCardVHeading).SetText("Charm Settings:").SetColor(BUTTON_COLOURS.Orchid);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Distance the charm affects').SetPreferredWidth(290);
    charmDistance = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(3)
        .SetValue(Mod.Settings.CharmDistance or 1);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Duration of the charm effect').SetPreferredWidth(290);
    charmDuration = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CharmDuration or 2);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Falloff % of the charm effect per step').SetPreferredWidth(290);
    charmFalloff = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.CharmFalloff or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    local charmFalloffExamples = UI.CreateLabel(horz).SetText('Falloff examples: ').SetPreferredWidth(290).SetColor(BUTTON_COLOURS.DarkGray);
    

    local refreshCharmExamplesButton = UI.CreateButton(horz)
        .SetText('Refresh')
        .SetPreferredWidth(150);

    refreshCharmExamplesButton.SetOnClick(function()
        Update_FalloffExamplesLabel(charmFalloffExamples, charmFalloff, charmDistance);
    end);

    Update_FalloffExamplesLabel(charmFalloffExamples, charmFalloff, charmDistance);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Maximum charm % where Special Units are Immune').SetPreferredWidth(290);
    charmSpecialUnitThreshold = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.CharmSpecialUnitThreshold or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Can only create on own territories').SetPreferredWidth(290);
    charmCreateOnlyOwnTerritories = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.CharmCreateOnlyOwnTerritories or false).SetText('');

    UI.CreateLabel(charmCardVHeading).SetText("Card Settings:").SetColor(BUTTON_COLOURS.Orchid);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Number of Pieces to divide the card into').SetFlexibleWidth(290);
    charmNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.CharmNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    charmCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CharmWeight or 1.0);
    
    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    charmMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CharmMinPieces or 1);
    
    local horz = UI.CreateHorizontalLayoutGroup(charmCardVHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    charmInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CharmInitialPieces or 5);
end