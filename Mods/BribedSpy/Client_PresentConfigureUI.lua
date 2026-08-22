require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    Create_UI_Controls(rootParent);
end;

function Create_UI_Controls(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    ---- Card options
    local cardOptionsHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(cardOptionsHeading).SetText('Bribed Spy Card:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Number of Pieces to divide the card into').SetPreferredWidth(290);
    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.NumPieces or 7);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    cardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardWeight or 1.0);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    minPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.MinPieces or 1);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    initialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.InitialPieces or 0);

    local horz = UI.CreateHorizontalLayoutGroup(cardOptionsHeading);
    UI.CreateLabel(horz).SetText('Number of turns the bribe lasts').SetPreferredWidth(290);
    bribeDuration = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(10)
        .SetValue(Mod.Settings.BribeDuration or 3);

    ---- Mod Behaviour
    local modBehaviourHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(modBehaviourHeading).SetText('Mod Behaviour:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(modBehaviourHeading);
    UI.CreateLabel(horz).SetText('Allow targeting yourself').SetPreferredWidth(290);
    allowTargetingSelf = UI.CreateCheckBox(horz).SetIsChecked(Mod.Settings.AllowTargetingSelf or false).SetText('');

    ---- Income granted to the bribed player
    local incomeHeading = UI.CreateVerticalLayoutGroup(mainModUI);
    UI.CreateLabel(incomeHeading).SetText('Bribed Player Income:').SetColor(SUBHEADING_COLOUR);

    local horz = UI.CreateHorizontalLayoutGroup(incomeHeading);
    UI.CreateLabel(horz).SetText('Minimum income gained per turn').SetPreferredWidth(290);
    minimumIncomeGain = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(20)
        .SetValue(Mod.Settings.MinimumIncomeGain or 2);

    local horz = UI.CreateHorizontalLayoutGroup(incomeHeading);
    UI.CreateLabel(horz).SetText('% increased income gained').SetPreferredWidth(290);
    increasedIncomePercentage = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(200)
        .SetValue(Mod.Settings.IncreasedIncomePercentage or 25);
end;
