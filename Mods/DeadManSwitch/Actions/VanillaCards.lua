require("Actions.Actions");

Actions.VanillaCards = {};
Actions.VanillaCards.Blockade = {};
Actions.VanillaCards.Bomb = {};
Actions.VanillaCards.Diplomacy = {};
Actions.VanillaCards.EmergencyBlockade = {};
Actions.VanillaCards.Gift = {};
Actions.VanillaCards.Sanction = {};
Actions.VanillaCards.Spy = {};

---Adds an event explaining that a DMS action was cancelled because its card is not enabled in the game settings
---@param context DeadManSwitchTriggerContext
---@param territoryModification TerritoryModification # The DMS territory modification (destroying the DMS) to attach to the event
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean) # Adds a game order, the second argument skips it if the triggering order is skipped
---@param cardName string # Display name of the card that could not be played
function Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, cardName)
	addNewOrder(WL.GameOrderEvent.Create(context.AttackerPlayerID, cardName .. " card not available - DMS action cancelled", {}, {territoryModification}), true);
end

---Returns a uniformly random playing player other than excludePlayerID, or nil if there isn't one
---@param game GameServerHook
---@param excludePlayerID PlayerID
---@return PlayerID | nil
local function PickRandomOtherPlayer(game, excludePlayerID)
	local candidates = {};
	for playerID, _ in pairs(game.ServerGame.Game.PlayingPlayers) do
		if (playerID ~= excludePlayerID) then table.insert(candidates, playerID); end
	end
	if (#candidates == 0) then return nil; end
	return candidates[math.random(#candidates)];
end

---Plays a bomb card on the captured territory for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Bomb.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Bomb] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Bomb");
		return;
	end

	-- if the DMS's territory was already neutral, there's no real defending player to give the card to, so let the attacker bomb themself instead
	-- note: as of 26/09/21, this produces an animation and bomb annotation but has no effect
	local bombPlayer = context.DefendingPlayerID;
	if (bombPlayer == WL.PlayerID.Neutral) then bombPlayer = context.AttackerPlayerID; end

	AddTriggeredEvent(context, territoryModification, addNewOrder);

	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Bomb);
		addNewOrder(WL.GameOrderReceiveCard.Create(bombPlayer, {instance}));
		addNewOrder(WL.GameOrderPlayCardBomb.Create(instance.ID, bombPlayer, context.TerritoryID));
	end
end

---Queues a blockade card on the captured territory, as the attacker, for each DMS, played at the end of the turn by Blockade.PlayPending
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Blockade.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Blockade] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Blockade");
		return;
	end

	AddTriggeredEvent(context, territoryModification, addNewOrder);

	-- blockade cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.PendingBlockade == nil) then privateGameData.PendingBlockade = {}; end;

	for _ = 1, numberOfDMS do
		table.insert(privateGameData.PendingBlockade, { PlayerID = context.AttackerPlayerID, TerritoryID = context.TerritoryID });
	end

	Mod.PrivateGameData = privateGameData;
end

---Plays the blockade cards queued by Trigger, called at the end of the turn
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function Actions.VanillaCards.Blockade.PlayPending(addNewOrder)
	local privateGameData = Mod.PrivateGameData;
	local pending = privateGameData.PendingBlockade;

	if (pending == nil) then return; end;

	for _,pendingBlockade in pairs(pending) do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Blockade);
		addNewOrder(WL.GameOrderReceiveCard.Create(pendingBlockade.PlayerID, {instance}));
		addNewOrder(WL.GameOrderPlayCardBlockade.Create(instance.ID, pendingBlockade.PlayerID, pendingBlockade.TerritoryID));
	end

	privateGameData.PendingBlockade = nil;
	Mod.PrivateGameData = privateGameData;
end

---Queues a diplomacy card between the DMS territory's owner and the attacker for each DMS, played at the end of the turn by Diplomacy.PlayPending
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Diplomacy.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Diplomacy] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Diplomacy");
		return;
	end

	-- if the DMS's territory was already neutral, there's no real defending player to benefit from the effect
	if (context.DefendingPlayerID == WL.PlayerID.Neutral) then
		addNewOrder(WL.GameOrderEvent.Create(context.AttackerPlayerID, "Defender is neutral - DMS action cancelled", {}, {territoryModification}), true);
		return;
	end

	-- diplomacy cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.PendingDiplomacy == nil) then privateGameData.PendingDiplomacy = {}; end;

	for _ = 1, numberOfDMS do
		table.insert(privateGameData.PendingDiplomacy, { PlayerID = context.DefendingPlayerID, PlayerOne = context.DefendingPlayerID, PlayerTwo = context.AttackerPlayerID });
	end

	Mod.PrivateGameData = privateGameData;
end

---Plays the diplomacy cards queued by Trigger, called at the end of the turn
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
function Actions.VanillaCards.Diplomacy.PlayPending(addNewOrder)
	local privateGameData = Mod.PrivateGameData;
	local pending = privateGameData.PendingDiplomacy;

	if (pending == nil) then return; end;

	for _,pendingDiplomacy in pairs(pending) do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Diplomacy);
		addNewOrder(WL.GameOrderReceiveCard.Create(pendingDiplomacy.PlayerID, {instance}));
		addNewOrder(WL.GameOrderPlayCardDiplomacy.Create(instance.ID, pendingDiplomacy.PlayerID, pendingDiplomacy.PlayerOne, pendingDiplomacy.PlayerTwo));
	end

	privateGameData.PendingDiplomacy = nil;
	Mod.PrivateGameData = privateGameData;
end

---Gifts the captured territory itself to another player: either a uniformly random other player, or the DMS
---territory's previous owner, depending on Mod.Settings.GiftRecipientType. Only ever plays one Gift card regardless
---of numberOfDMS - gifting the same territory away twice makes no sense.
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Gift.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Gift] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Gift");
		return;
	end

	local giftTo;
	if (Mod.Settings.GiftRecipientType == "Defender") then
		-- if the DMS's territory was already neutral, there's no real defending player to gift it to
		if (context.DefendingPlayerID == WL.PlayerID.Neutral) then
			addNewOrder(WL.GameOrderEvent.Create(context.AttackerPlayerID, "Defender is neutral - DMS action cancelled", {}, {territoryModification}), true);
			return;
		end
		giftTo = context.DefendingPlayerID;
	else
		giftTo = PickRandomOtherPlayer(game, context.AttackerPlayerID);
		if (giftTo == nil) then
			addNewOrder(WL.GameOrderEvent.Create(context.AttackerPlayerID, "No other player to gift to - DMS action cancelled", {}, {territoryModification}), true);
			return;
		end
	end

	AddTriggeredEvent(context, territoryModification, addNewOrder);

	local instance = WL.NoParameterCardInstance.Create(WL.CardID.Gift);
	addNewOrder(WL.GameOrderReceiveCard.Create(context.AttackerPlayerID, {instance}));
	addNewOrder(WL.GameOrderPlayCardGift.Create(instance.ID, context.AttackerPlayerID, context.TerritoryID, giftTo));
end

---Plays an emergency blockade card on the captured territory, as the attacker, for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.EmergencyBlockade.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.EmergencyBlockade] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Emergency Blockade");
		return;
	end

	AddTriggeredEvent(context, territoryModification, addNewOrder);

	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.EmergencyBlockade);
		addNewOrder(WL.GameOrderReceiveCard.Create(context.AttackerPlayerID, {instance}));
		addNewOrder(WL.GameOrderPlayCardAbandon.Create(instance.ID, context.AttackerPlayerID, context.TerritoryID));
	end
end

---Plays a sanction card on the DMS territory's owner (or the attacker if that owner is neutral) against the attacker, for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Sanction.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Sanctions] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Sanction");
		return;
	end

	-- if the DMS's territory was already neutral, there's no real defending player to give the card to, so let the attacker sanction themself instead
	local sanctioningPlayer = context.DefendingPlayerID;
	if (sanctioningPlayer == WL.PlayerID.Neutral) then sanctioningPlayer = context.AttackerPlayerID; end

	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Sanctions);
		addNewOrder(WL.GameOrderReceiveCard.Create(sanctioningPlayer, {instance}));
		addNewOrder(WL.GameOrderPlayCardSanctions.Create(instance.ID, sanctioningPlayer, context.AttackerPlayerID));
	end
end

---Plays a spy card on the DMS territory's owner against the attacker, for each DMS. Does nothing if that owner is neutral.
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param context DeadManSwitchTriggerContext
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Spy.Trigger(territoryModification, game, context, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Spy] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(context, territoryModification, addNewOrder, "Spy");
		return;
	end

	-- if the DMS's territory was already neutral, there's no real defending player to benefit from the effect
	if (context.DefendingPlayerID == WL.PlayerID.Neutral) then return; end

	-- multiple Spy cards played on the same player is redundant but lets support desired side-effects from mods
	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
		addNewOrder(WL.GameOrderReceiveCard.Create(context.DefendingPlayerID, {instance}));
		addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, context.DefendingPlayerID, context.AttackerPlayerID));
	end
end
