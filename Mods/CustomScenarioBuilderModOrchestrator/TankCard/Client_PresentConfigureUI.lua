require("Utilities");

---Client_PresentConfigureUI hook
---@param rootParent RootParent
function Client_PresentConfigureUI(rootParent)
    local mainModUI = UI.CreateVerticalLayoutGroup(rootParent).SetFlexibleWidth(1);

    UI.CreateLabel(mainModUI).SetText('Tank Card').SetColor(SUBHEADING_COLOUR);
    UI.CreateLabel(mainModUI).SetText('Play this card on a territory you control to build a Tank there at the end of the turn.');

    UI.CreateEmpty(mainModUI).SetPreferredHeight(10);

    local horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Number of Pieces to divide the card into').SetPreferredWidth(290);
    numPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(1)
        .SetSliderMaxValue(15)
        .SetValue(Mod.Settings.NumPieces or 7);

    horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Card weight (how common the card is)').SetPreferredWidth(290);
    cardWeight = UI.CreateNumberInputField(horz)
        .SetWholeNumbers(false)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.CardWeight or 1.0);

    horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Minimum pieces awarded per turn').SetPreferredWidth(290);
    minPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.MinPieces or 1);

    horz = UI.CreateHorizontalLayoutGroup(mainModUI);
    UI.CreateLabel(horz).SetText('Pieces given to each player at the start').SetPreferredWidth(290);
    initialPieces = UI.CreateNumberInputField(horz)
        .SetSliderMinValue(0)
        .SetSliderMaxValue(5)
        .SetValue(Mod.Settings.InitialPieces or 1);
end
