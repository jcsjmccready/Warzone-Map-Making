function Client_PresentSettingsUI(rootParent)
	UI.CreateLabel(rootParent).SetText('Tank card: ' .. Mod.Settings.NumPieces .. ' pieces, weight ' .. Mod.Settings.CardWeight);
end
