require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Play this card and pick a bonus you fully control*').SetColor(BUTTON_COLOURS.DarkGray);
    UI.CreateLabel(mainModUI).SetText('If you still fully control it at the end of the turn, its value is permanently reduced and you get a one-turn income boost*').SetColor(BUTTON_COLOURS.DarkGray);

    UI.CreateLabel(mainModUI).SetText('Income Gained (this turn only):').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Flat income gained').SetPreferredWidth(290);
    flatIncomeGained = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.FlatIncomeGained or 5);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('% of bonus value gained as income').SetPreferredWidth(290);
    percentIncomeGained = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.PercentIncomeGained or 0.5);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Minimum income gained').SetPreferredWidth(290);
    minimumIncomeGained = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.MinimumIncomeGained or 1);

    UI.CreateLabel(mainModUI).SetText('Bonus Value Decrease (permanent):').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Flat value to decrease bonus by').SetPreferredWidth(290);
    flatValueDecrease = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.FlatValueDecrease or 1);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('% to decrease bonus by').SetPreferredWidth(290);
    percentValueDecrease = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.PercentValueDecrease or 0.25);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Minimum bonus value decrease').SetPreferredWidth(290);
    minimumValueDecrease = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.MinimumValueDecrease or 1);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Fully conscripted bonuses slowly neutralise if no occupying army').SetPreferredWidth(290);
    neutraliseFullyConscripted = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.NeutraliseFullyConscripted or false).SetText('');
    UI.CreateLabel(mainModUI).SetText('(Bonuses that start at 0 value are excluded from this)').SetColor(BUTTON_COLOURS.DarkGray);

    local neutraliseSubOptionsParent = UI.CreateVerticalLayoutGroup(mainModUI);

    neutraliseFullyConscripted.SetOnValueChanged(function()
        if (neutraliseFullyConscripted.GetIsChecked()) then
            Create_Neutralise_SubOptions_UI(neutraliseSubOptionsParent);
        else
            UI.Destroy(neutraliseSubOptionsVGroup);
        end
    end);

    if (neutraliseFullyConscripted.GetIsChecked()) then
        Create_Neutralise_SubOptions_UI(neutraliseSubOptionsParent);
    end

    UI.CreateLabel(mainModUI).SetText('Card Settings:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Number of pieces to divide the card into').SetPreferredWidth(290);
    conscriptionNumPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(11)
        .SetValue(Mod.Settings.ConscriptionNumPieces or 5);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    conscriptionCardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.ConscriptionCardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    conscriptionMinPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.ConscriptionMinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    conscriptionInitialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.ConscriptionInitialPieces or 0);
end

function Create_Neutralise_SubOptions_UI(rootParent)
    neutraliseSubOptionsVGroup = UI.CreateVerticalLayoutGroup(rootParent);

    local horz = UI.CreateHorizontalLayoutGroup(neutraliseSubOptionsVGroup);
    UI.CreateLabel(horz).SetText('% of applicable territories to neutralise per turn').SetPreferredWidth(290);
    neutralisePercentPerTurn = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(1)
        .SetValue(Mod.Settings.NeutralisePercentPerTurn or 0.25);

    UI.CreateLabel(neutraliseSubOptionsVGroup).SetText('(At least 1 applicable territory always neutralises per turn as long as this is at least 1%)').SetColor(BUTTON_COLOURS.DarkGray);
end
