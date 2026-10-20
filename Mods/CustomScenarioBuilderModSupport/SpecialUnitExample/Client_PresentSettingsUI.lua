function Client_PresentSettingsUI(rootParent)
	UI.CreateLabel(rootParent).SetText('SpecialUnitExample card: ' .. Mod.Settings.NumPieces .. ' pieces, weight ' .. Mod.Settings.CardWeight);
end
