require("Utilities");

---@class ActiveFlakGun # A Flak Gun barrage active for the remainder of the current turn
---@field TerritoryId TerritoryID # The territory the Flak Gun was fired at
---@field PlayerOwnerId PlayerID # The player who fired the Flak Gun
---@field AffectedTerritories table<TerritoryID, boolean> # The set of territories covered by the Flak Gun's area of effect (always includes TerritoryId itself)

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Start(game, addNewOrder)
	-- Flak Guns only intercept airlifts fired during the same turn they're set up, so the active list never
	-- carries over from one turn to the next
	local priv = Mod.PrivateGameData;
	priv.ActiveFlakGuns = {};
	Mod.PrivateGameData = priv;
end

---Server_AdvanceTurn_Order hook
---TODO: Spy Plane gameplay effect not yet implemented, and Flak Gun's "destroy spy plane" targeting option has no
---effect until it is
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "ShootFlakGun_")) then
		HandleShootFlakGun(game, order, addNewOrder);
	end

	if (order.proxyType == 'GameOrderPlayCardAirlift') then
		HandleAirliftTargetedByFlakGun(game, order, result, skipThisOrder, addNewOrder);
	end
end

---Registers a newly fired Flak Gun for the remainder of this turn, and starts a temporary-card streak if this was
---the original card (not a temporary copy) and multiple rounds are configured.
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleShootFlakGun(game, order, addNewOrder)
	if (order.CustomCardID == Mod.Settings.FlakGunCardID and Mod.Settings.FlakGunRounds > 1) then
		-- playing the original card starts its own independent countdown; if the player has other active
		-- Flak Gun streaks running, this is in addition to those, not a replacement for them
		local priv = Mod.PrivateGameData;
		if (priv.PendingFlakGunStreaks == nil) then priv.PendingFlakGunStreaks = {}; end;
		table.insert(priv.PendingFlakGunStreaks, { PlayerID = order.PlayerID, RemainingTurns = Mod.Settings.FlakGunRounds - 1 });
		Mod.PrivateGameData = priv;
	end

	local targetTerritoryID = tonumber(string.sub(order.ModData, string.len("ShootFlakGun_") + 1)) or 0;

	local affectedTerritories = {};
	for _, territoryID in ipairs(GetTerritoriesWithinDistance(game, targetTerritoryID, Mod.Settings.FlakGunAreaOfEffect or 0)) do
		affectedTerritories[territoryID] = true;
	end

	---@type ActiveFlakGun
	local activeFlakGun = {
		TerritoryId = targetTerritoryID,
		PlayerOwnerId = order.PlayerID,
		AffectedTerritories = affectedTerritories
	};

	local priv = Mod.PrivateGameData;
	local activeFlakGuns = priv.ActiveFlakGuns or {};
	table.insert(activeFlakGuns, activeFlakGun);
	priv.ActiveFlakGuns = activeFlakGuns;
	Mod.PrivateGameData = priv;

	local td = game.Map.Territories[targetTerritoryID];
	local event = WL.GameOrderEvent.Create(order.PlayerID, order.Description, {}, {});
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

	local annotations = {};
	for territoryID, _ in pairs(affectedTerritories) do
		annotations[territoryID] = WL.TerritoryAnnotation.Create(".", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan));
	end
	annotations[targetTerritoryID] = WL.TerritoryAnnotation.Create("Flak", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan));
	event.TerritoryAnnotationsOpt = annotations;

	addNewOrder(event);
end

---Checks an about-to-resolve Airlift order against every Flak Gun fired this turn, cancelling it if its source is
---covered by a Flak Gun configured to do so, otherwise damaging the transported armies if its destination is
---covered by a Flak Gun configured to do so.
---@param game GameServerHook
---@param order GameOrderPlayCardAirlift
---@param result GameOrderPlayCardAirliftResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function HandleAirliftTargetedByFlakGun(game, order, result, skipThisOrder, addNewOrder)
	---@type [ActiveFlakGun]
	local activeFlakGuns = Mod.PrivateGameData.ActiveFlakGuns or {};
	if (#activeFlakGuns == 0) then return; end;

	local fromTerritoryName = game.Map.Territories[order.FromTerritoryID].Name;
	local toTerritoryName = game.Map.Territories[order.ToTerritoryID].Name;

	if (Mod.Settings.FlakGunTargetingAirliftSourceCancels) then
		for _, flakGun in ipairs(activeFlakGuns) do
			local isFriendly = Mod.Settings.FlakGunFriendlyFire ~= true and ArePlayersFriendly(game, flakGun.PlayerOwnerId, order.PlayerID);
			if (not isFriendly and flakGun.AffectedTerritories[order.FromTerritoryID]) then
				skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage); --suppress the meaningless/detailless 'Mod skipped order' message, since the below message provides the details

				local message = "Airlift out of " .. fromTerritoryName .. " was shot down by a Flak Gun";
				local event = WL.GameOrderEvent.Create(order.PlayerID, message, {}, {});
				event.TerritoryAnnotationsOpt = { [order.FromTerritoryID] = WL.TerritoryAnnotation.Create("Airlift Shot down", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)) };
				addNewOrder(event);
				return; --airlift never left, nothing more to do
			end
		end
	end

	if (Mod.Settings.FlakGunTargetingAirliftDestinationHurts) then
		local armiesAirlifted = result.ArmiesAirlifted;
		if (armiesAirlifted == nil or armiesAirlifted.IsEmpty) then return; end;

		local hitCount = 0;
		for _, flakGun in ipairs(activeFlakGuns) do
			local isFriendly = Mod.Settings.FlakGunFriendlyFire ~= true and ArePlayersFriendly(game, flakGun.PlayerOwnerId, order.PlayerID);
			if (not isFriendly and flakGun.AffectedTerritories[order.ToTerritoryID]) then
				hitCount = hitCount + 1;
			end
		end

		if (hitCount == 0) then return; end;

		local totalMinDamage = (Mod.Settings.FlakGunAirliftMinDamage or 0) * hitCount;

		--apply the percentage damage once per Flak Gun that hit (compounding)
		local remainingArmies = armiesAirlifted.NumArmies;
		for _ = 1, hitCount do
			remainingArmies = math.floor(remainingArmies * (1 - (Mod.Settings.FlakGunAirliftDamagePercent or 0)) + 0.5);
		end
		local minimumRemainingArmies = math.max(0, armiesAirlifted.NumArmies - totalMinDamage);

		local territoryModification = WL.TerritoryModification.Create(order.ToTerritoryID);
		territoryModification.SetArmiesTo = math.min(remainingArmies, minimumRemainingArmies);

		local message = "Airlift into " .. toTerritoryName .. " was damaged by a Flak Gun(s)";
		local event = WL.GameOrderEvent.Create(order.PlayerID, message, {}, {territoryModification});
		event.TerritoryAnnotationsOpt = { [order.ToTerritoryID] = WL.TerritoryAnnotation.Create("Airlift Damaged", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)) };
		addNewOrder(event);
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	DiscardUnusedTemporaryFlakGunCards(game, addNewOrder);
	GiveTemporaryFlakGunCards(game, addNewOrder);
end

--discards any Temp. Flak Gun cards still sitting unused in a player's hand, so they don't carry over into the
--next turn before this turn's active streaks hand out fresh ones
function DiscardUnusedTemporaryFlakGunCards(game, addNewOrder)
	for playerID, playerCards in pairs(game.ServerGame.LatestTurnStanding.Cards) do
		for cardInstanceID, cardInstance in pairs(playerCards.WholeCards) do
			if (cardInstance.CardID == Mod.Settings.FlakGunTemporaryCardID) then
				addNewOrder(WL.GameOrderDiscard.Create(playerID, cardInstanceID));
			end
		end
	end
end

--gives out a Temp. Flak Gun card for each still-active streak, one card per streak (a player with multiple
--active streaks receives multiple temporary cards), then ticks each streak's remaining turns down
function GiveTemporaryFlakGunCards(game, addNewOrder)
	local priv = Mod.PrivateGameData;
	local streaks = priv.PendingFlakGunStreaks;
	if (streaks == nil) then return; end;

	local remainingStreaks = {};
	for _, streak in pairs(streaks) do
		local instance = WL.NoParameterCardInstance.Create(Mod.Settings.FlakGunTemporaryCardID);
		addNewOrder(WL.GameOrderReceiveCard.Create(streak.PlayerID, { instance }));

		if (streak.RemainingTurns > 1) then
			table.insert(remainingStreaks, { PlayerID = streak.PlayerID, RemainingTurns = streak.RemainingTurns - 1 });
		end
	end

	priv.PendingFlakGunStreaks = (#remainingStreaks > 0) and remainingStreaks or nil;
	Mod.PrivateGameData = priv;
end
