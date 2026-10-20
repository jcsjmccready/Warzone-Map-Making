function Client_PresentConfigureUI(rootParent)
	local vert = UI.CreateVerticalLayoutGroup(rootParent);

	local row1 = UI.CreateHorizontalLayoutGroup(vert);
	UI.CreateLabel(row1).SetText('Number of Pieces to divide the card into');
	numPiecesField = UI.CreateNumberInputField(row1)
		.SetSliderMinValue(1)
		.SetSliderMaxValue(15)
		.SetValue(Mod.Settings.NumPieces or 7);

	local row2 = UI.CreateHorizontalLayoutGroup(vert);
	UI.CreateLabel(row2).SetText('Card weight (how common the card is)');
	cardWeightField = UI.CreateNumberInputField(row2)
		.SetWholeNumbers(false)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(5)
		.SetValue(Mod.Settings.CardWeight or 1.0);

	local row3 = UI.CreateHorizontalLayoutGroup(vert);
	UI.CreateLabel(row3).SetText('Minimum pieces awarded per turn');
	minPiecesField = UI.CreateNumberInputField(row3)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(5)
		.SetValue(Mod.Settings.MinPieces or 1);

	local row4 = UI.CreateHorizontalLayoutGroup(vert);
	UI.CreateLabel(row4).SetText('Pieces given to each player at the start');
	initialPiecesField = UI.CreateNumberInputField(row4)
		.SetSliderMinValue(0)
		.SetSliderMaxValue(5)
		.SetValue(Mod.Settings.InitialPieces or 1);
end
