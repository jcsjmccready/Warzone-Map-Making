function Client_SaveConfigureUI(alert, addCard)
	local numPieces = numPiecesField.GetValue();
	local cardWeight = cardWeightField.GetValue();
	local minPieces = minPiecesField.GetValue();
	local initialPieces = initialPiecesField.GetValue();

	if numPieces < 1 then alert('Number of pieces must be positive'); return; end
	if cardWeight < 0 then alert('Card weight cannot be negative'); return; end
	if minPieces < 0 then alert('Minimum pieces cannot be negative'); return; end
	if initialPieces < 0 then alert('Initial pieces cannot be negative'); return; end

	Mod.Settings.NumPieces = numPieces;
	Mod.Settings.CardWeight = cardWeight;
	Mod.Settings.MinPieces = minPieces;
	Mod.Settings.InitialPieces = initialPieces;

	Mod.Settings.TankCardID = addCard(
		"Tank Card",
		"Play this card to build a Tank on any territory you control (at the end of the turn).",
		"TankCard.png",
		numPieces,
		minPieces,
		initialPieces,
		cardWeight);
end
