require("Actions.Actions");

Actions.VanillaCards = {};
Actions.VanillaCards.Blockade = {};
Actions.VanillaCards.Bomb = {};
Actions.VanillaCards.Diplomacy = {};
Actions.VanillaCards.EmergencyBlockade = {};
Actions.VanillaCards.Sanction = {};
Actions.VanillaCards.Spy = {};

---Adds an event explaining that a DMS action was cancelled because its card is not enabled in the game settings
---@param order GameOrderAttackTransfer # The attack that triggered the DMS
---@param territoryModification TerritoryModification # The DMS territory modification (destroying the DMS) to attach to the event
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean) # Adds a game order, the second argument skips it if the triggering order is skipped
---@param cardName string # Display name of the card that could not be played
function Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, cardName)
	addNewOrder(WL.GameOrderEvent.Create(order.PlayerID, cardName .. " card not available - DMS action cancelled", {}, {territoryModification}), true);
end

---Queues a blockade card on the captured territory, as the attacker, for each DMS, played at the end of the turn by Blockade.PlayPending
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Blockade.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Blockade] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, "Blockade");
		return;
	end

	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	AddTriggeredEvent(order, territoryModification, addNewOrder);

	-- blockade cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.PendingBlockade == nil) then privateGameData.PendingBlockade = {}; end;

	for _ = 1, numberOfDMS do
		table.insert(privateGameData.PendingBlockade, { PlayerID = attackingPlayer, TerritoryID = order.To });
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

---Plays a bomb card on the captured territory for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Bomb.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Bomb] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, "Bomb");
		return;
	end

	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	-- if the DMS's territory was already neutral, there's no real defending player to give the card to, so let the attacker bomb themself instead
	-- note: as of 26/09/21, this produces an animation and bomb annotation but has no effect
	local bombPlayer = defendingPlayer;
	if (defendingPlayer == WL.PlayerID.Neutral) then bombPlayer = attackingPlayer; end

	AddTriggeredEvent(order, territoryModification, addNewOrder);

	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Bomb);
		addNewOrder(WL.GameOrderReceiveCard.Create(bombPlayer, {instance}));
		addNewOrder(WL.GameOrderPlayCardBomb.Create(instance.ID, bombPlayer, order.To));
	end
end

---Queues a diplomacy card between the previous owner and the attacker for each DMS, played at the end of the turn by Diplomacy.PlayPending
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Diplomacy.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Diplomacy] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, "Diplomacy");
		return;
	end

	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	-- if the DMS's territory was already neutral, there's no real defending player to benefit from the effect
	if (defendingPlayer == WL.PlayerID.Neutral) then 
		addNewOrder(WL.GameOrderEvent.Create(attackingPlayer, "Defender is neutral - DMS action cancelled", {}, {territoryModification}), true);
		return;
	end

	-- diplomacy cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.PendingDiplomacy == nil) then privateGameData.PendingDiplomacy = {}; end;

	for _ = 1, numberOfDMS do
		table.insert(privateGameData.PendingDiplomacy, { PlayerID = defendingPlayer, PlayerOne = defendingPlayer, PlayerTwo = attackingPlayer });
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

---Plays an emergency blockade card on the captured territory, as the attacker, for each DMS
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.EmergencyBlockade.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.EmergencyBlockade] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, "Emergency Blockade");
		return;
	end

	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	AddTriggeredEvent(order, territoryModification, addNewOrder);

	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.EmergencyBlockade);
		addNewOrder(WL.GameOrderReceiveCard.Create(attackingPlayer, {instance}));
		addNewOrder(WL.GameOrderPlayCardAbandon.Create(instance.ID, attackingPlayer, order.To));
	end
end

---Plays a sanction card on the attacker for each DMS on the captured territory
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder, skipIfOriginalSkipped?: boolean)
---@param numberOfDMS integer
function Actions.VanillaCards.Sanction.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Sanctions] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, "Sanction");
		return;
	end

	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	-- if the DMS's territory was already neutral, there's no real defending player to give the card to, so let the attacker sanction themself instead
	local sanctioningPlayer = defendingPlayer;
	if (defendingPlayer == WL.PlayerID.Neutral) then sanctioningPlayer = attackingPlayer; end

	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Sanctions);
		addNewOrder(WL.GameOrderReceiveCard.Create(sanctioningPlayer, {instance}));
		addNewOrder(WL.GameOrderPlayCardSanctions.Create(instance.ID, sanctioningPlayer, attackingPlayer));
	end
end

---Plays a spy card for each DMS on the captured territory
---@param territoryModification TerritoryModification
---@param game GameServerHook
---@param order GameOrderAttackTransfer
---@param result GameOrderAttackTransferResult
---@param addNewOrder fun(order: GameOrder)
---@param numberOfDMS integer
function Actions.VanillaCards.Spy.Trigger(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- unable to programatically play cards without them being enabled
	if game.Settings.Cards == nil or game.Settings.Cards[WL.CardID.Spy] == nil then
		Actions.VanillaCards.CardNotEnabledEvent(order, territoryModification, addNewOrder, "Spy");
		return;
	end

	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

	-- if the DMS's territory was already neutral, there's no real defending player to benefit from the effect
	if (defendingPlayer == WL.PlayerID.Neutral) then return; end

	-- multiple Spy cards played on the same player is redundant but lets support desired side-effects from mods
	for _ = 1, numberOfDMS do
		local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
		addNewOrder(WL.GameOrderReceiveCard.Create(defendingPlayer, {instance}));
		addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, defendingPlayer, attackingPlayer));
	end
end
