require("Utilities");

---@class ActiveFlakGun # A Flak Gun barrage active for the remainder of the current turn
---@field TerritoryId TerritoryID # The territory the Flak Gun was fired at
---@field PlayerOwnerId PlayerID # The player who fired the Flak Gun
---@field AffectedTerritories table<TerritoryID, boolean> # The set of territories covered by the Flak Gun's area of effect (always includes TerritoryId itself)

---@class ActiveSpyPlaneFlight # A Distance-based Steps Spy Plane flight still in progress, carried over between turns
---@field PlayerID PlayerID # The player who played the Spy Plane card
---@field StartX number # The X coordinate the flight started from
---@field StartY number # The Y coordinate the flight started from
---@field EndX number # The X coordinate the flight ends at (already pulled in to Mod.Settings.SpyPlaneMaxFlightDistance if needed)
---@field EndY number # The Y coordinate the flight ends at (already pulled in to Mod.Settings.SpyPlaneMaxFlightDistance if needed)
---@field EndTerritoryID TerritoryID # The territory the player originally selected as the flight's destination, annotated on every step
---@field TotalDistance number # The total length of the flight, in map units (already capped to Mod.Settings.SpyPlaneMaxFlightDistance)
---@field DistanceCovered number # How much of the flight has already been covered by steps granted on previous turns

---Server_AdvanceTurn_Start hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Start(game, addNewOrder)
	-- Flak Guns only intercept airlifts fired during the same turn they're set up, so the active list never
	-- carries over from one turn to the next
	local priv = Mod.PrivateGameData;
	priv.ActiveFlakGuns = {};
	Mod.PrivateGameData = priv;

	RemoveExpiredSpyPlaneVisionFogMods(addNewOrder);
	AdvanceActiveSpyPlaneFlights(game, addNewOrder);
end

---Server_AdvanceTurn_Order hook
---TODO: Spy Plane's Segment-based Steps flight style not yet implemented (Distance-based Steps grants vision one
---strip at a time as the plane advances each turn; Instant grants it all at once). Flak Gun's "destroy spy plane"
---targeting option has no effect until Spy Plane orders exist for it to detect
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

	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "FlySpyPlane_")) then
		HandleFlySpyPlane(game, order, addNewOrder);
	end
end

---Parses the start/end territories back out of a FlySpyPlane_ order and - depending on the configured flight
---style - either grants the player vision of the whole flight line for this turn (Instant), or kicks off a
---Distance-based Steps flight by granting vision of its first step and (if more than one step is needed) queuing
---the rest to be advanced automatically on the player's following turns via AdvanceActiveSpyPlaneFlights.
---@param game GameServerHook
---@param order GameOrder
---@param addNewOrder fun(order: GameOrder)
function HandleFlySpyPlane(game, order, addNewOrder)
	local ids = split(string.sub(order.ModData, string.len("FlySpyPlane_") + 1), "_");
	local startTerritoryID = tonumber(ids[1]);
	local endTerritoryID = tonumber(ids[2]);

	local maxFlightDistance = Mod.Settings.SpyPlaneMaxFlightDistance or 300;
	local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;

	local startTd = game.Map.Territories[startTerritoryID];
	local endTd = game.Map.Territories[endTerritoryID];
	local event = WL.GameOrderEvent.Create(order.PlayerID, order.Description, {}, {});
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(startTd.MiddlePointX, startTd.MiddlePointY, endTd.MiddlePointX, endTd.MiddlePointY);

	--in Distance-based Steps, the first step's own event (below) already labels the plane's starting position, so
	--a separate "Spy Plane Start" annotation here would be redundant
	local isDistanceSteps = Mod.Settings.SpyPlaneFlightStyleSteps and Mod.Settings.SpyPlaneStepModeDistance;
	local annotations = {
		[endTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.LightBlue)),
	};
	if (not isDistanceSteps) then
		annotations[startTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane Start", 8, GetColourIntegerFromHex(BUTTON_COLOURS.LightBlue));
	end
	event.TerritoryAnnotationsOpt = annotations;

	if (Mod.Settings.SpyPlaneFlightStyleInstant) then
		local coveredTerritories = GetTerritoriesNearLine(game, startTerritoryID, endTerritoryID, inclusionGenerosity, maxFlightDistance);
		event.FogModsOpt = { GrantSpyPlaneVisionForTurn(coveredTerritories, order.PlayerID) };
	elseif (Mod.Settings.SpyPlaneFlightStyleSteps and Mod.Settings.SpyPlaneStepModeDistance) then
		local ax, ay, bx, by, totalDistance = GetClampedLineSegment(game, startTerritoryID, endTerritoryID, maxFlightDistance);

		---@type ActiveSpyPlaneFlight
		local flight = {
			PlayerID = order.PlayerID,
			StartX = ax, StartY = ay,
			EndX = bx, EndY = by,
			EndTerritoryID = endTerritoryID,
			TotalDistance = totalDistance,
			DistanceCovered = 0,
		};

		--grant this turn's step immediately, same as Instant does for the whole flight, then queue whatever's left
		AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder);

		if (flight.DistanceCovered < flight.TotalDistance) then
			local priv = Mod.PrivateGameData;
			local activeFlights = priv.ActiveSpyPlaneFlights or {};
			table.insert(activeFlights, flight);
			priv.ActiveSpyPlaneFlights = activeFlights;
			Mod.PrivateGameData = priv;
		end
	end

	addNewOrder(event);
end

---Grants the given player Visible fog of the given territories for the remainder of this turn only, registering
---the FogMod so RemoveExpiredSpyPlaneVisionFogMods removes it again at the start of the player's next turn. Shared
---by Instant's single whole-flight reveal and each individual step of a Distance-based Steps flight.
---@param coveredTerritories TerritoryID[]
---@param playerID PlayerID
---@return FogMod
function GrantSpyPlaneVisionForTurn(coveredTerritories, playerID)
	local fogMod = WL.FogMod.Create("Spy Plane vision", WL.StandingFogLevel.Visible, 9000, coveredTerritories, { playerID });

	local priv = Mod.PrivateGameData;
	if (priv.PendingSpyPlaneVisionFogModIDs == nil) then priv.PendingSpyPlaneVisionFogModIDs = {}; end;
	table.insert(priv.PendingSpyPlaneVisionFogModIDs, fogMod.ID);
	Mod.PrivateGameData = priv;

	return fogMod;
end

---Grants vision of the next strip of territories along an in-progress Distance-based Steps flight (from wherever
---it left off, up to Mod.Settings.SpyPlaneMaxDistancePerStep further along), and advances flight.DistanceCovered
---to match. Used both for a flight's first step (played as part of its own order) and every subsequent step
---(advanced automatically by AdvanceActiveSpyPlaneFlights at the start of each of the flight's following turns).
---@param game GameServerHook
---@param flight ActiveSpyPlaneFlight
---@param inclusionGenerosity number
---@param addNewOrder fun(order: GameOrder)
function AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder)
	local maxDistancePerStep = Mod.Settings.SpyPlaneMaxDistancePerStep or 200;

	local stepStartDistance = flight.DistanceCovered;
	local stepEndDistance = math.min(flight.TotalDistance, flight.DistanceCovered + maxDistancePerStep);

	local t0 = (flight.TotalDistance > 0) and (stepStartDistance / flight.TotalDistance) or 0;
	local t1 = (flight.TotalDistance > 0) and (stepEndDistance / flight.TotalDistance) or 1;

	local x0 = flight.StartX + t0 * (flight.EndX - flight.StartX);
	local y0 = flight.StartY + t0 * (flight.EndY - flight.StartY);
	local x1 = flight.StartX + t1 * (flight.EndX - flight.StartX);
	local y1 = flight.StartY + t1 * (flight.EndY - flight.StartY);

	local coveredTerritories = GetTerritoriesNearLineSegment(game, x0, y0, x1, y1, inclusionGenerosity);
	local fogMod = GrantSpyPlaneVisionForTurn(coveredTerritories, flight.PlayerID);

	--label whichever territory is closest to this step's segment as the plane's current position, and re-label
	--the flight's overall destination each step too since annotations don't persist from the turn the card was
	--played (Instant's annotations are a one-time thing, but a Steps flight spans many turns of separate events)
	local midX, midY = (x0 + x1) / 2, (y0 + y1) / 2;
	local nearestTerritoryID = FindNearestTerritory(game, midX, midY);

	local event = WL.GameOrderEvent.Create(flight.PlayerID, "Spy Plane continues its flight", {}, {});
	event.FogModsOpt = { fogMod };
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(x0, y0, x1, y1);
	event.TerritoryAnnotationsOpt = {
		[nearestTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane", 8, GetColourIntegerFromHex(BUTTON_COLOURS.LightBlue)),
		[flight.EndTerritoryID] = WL.TerritoryAnnotation.Create("Spy Plane End", 8, GetColourIntegerFromHex(BUTTON_COLOURS.LightBlue)),
	};
	addNewOrder(event);

	flight.DistanceCovered = stepEndDistance;
end

---Advances every Distance-based Steps Spy Plane flight still in progress by one more step, granting vision of the
---next strip of territories for this turn. Flights that reach their end are dropped from the active list.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function AdvanceActiveSpyPlaneFlights(game, addNewOrder)
	local activeFlights = Mod.PrivateGameData.ActiveSpyPlaneFlights;
	if (activeFlights == nil or #activeFlights == 0) then return; end;

	local inclusionGenerosity = Mod.Settings.SpyPlaneInclusionGenerosity or 50;
	local remainingFlights = {};
	for _, flight in ipairs(activeFlights) do
		--AdvanceSpyPlaneFlightStep (via GrantSpyPlaneVisionForTurn) does its own read-modify-write of
		--Mod.PrivateGameData for PendingSpyPlaneVisionFogModIDs, so we must not hold a snapshot of it across this
		--loop - re-read fresh below instead of writing back a copy taken before the loop ran
		AdvanceSpyPlaneFlightStep(game, flight, inclusionGenerosity, addNewOrder);

		if (flight.DistanceCovered < flight.TotalDistance) then
			table.insert(remainingFlights, flight);
		end
	end

	local priv = Mod.PrivateGameData;
	priv.ActiveSpyPlaneFlights = (#remainingFlights > 0) and remainingFlights or nil;
	Mod.PrivateGameData = priv;
end

---Removes any Spy Plane vision FogMods granted last turn, so each turn's vision (whether from Instant or a single
---Distance-based Steps step) lasts exactly one turn - mirrors OrderNeutral's RemoveExpiredVisionFogMods.
---@param addNewOrder fun(order: GameOrder)
function RemoveExpiredSpyPlaneVisionFogMods(addNewOrder)
	local priv = Mod.PrivateGameData;
	local pendingIDs = priv.PendingSpyPlaneVisionFogModIDs;
	if (pendingIDs == nil or #pendingIDs == 0) then return; end;

	local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Spy Plane vision expired", {}, {});
	event.RemoveFogModsOpt = pendingIDs;
	addNewOrder(event);

	priv.PendingSpyPlaneVisionFogModIDs = nil;
	Mod.PrivateGameData = priv;
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
