---Server_Created hook
---@param game GameServerHook
---@param settings GameSettings
function Server_Created(game, settings)
	-- add bomb if not already added
	if (Mod.Settings.isDamageTypeBomb) then
		local cards = settings.Cards;
		if (settings.Cards[WL.CardID.Bomb] == nil) then
			cards[WL.CardID.Bomb] = WL.CardGameBomb.Create(1, 0, 0, 0);
		end
		for i, v in pairs(game.Settings.Cards) do
			cards[i] = v;
		end
		settings.Cards = cards;
	end
end
