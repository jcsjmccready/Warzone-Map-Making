require("Utilities");
require("Interface");

FlakGunApplication = {};

---@class ActiveFlakGun # A Flak Gun barrage active for the remainder of the current turn
---@field TerritoryId TerritoryID # The territory the Flak Gun was fired at
---@field PlayerOwnerId PlayerID # The player who fired the Flak Gun
---@field AffectedTerritories table<TerritoryID, boolean> # The set of territories covered by the Flak Gun's area of effect (always includes TerritoryId itself)

---@class FlakGunPendingStreak
---@field PlayerID PlayerID
---@field RemainingTurns integer

---@class FlakGunPrivateGameData
---@field ActiveFlakGuns ActiveFlakGun[] # Reset to empty at the start of every turn (Server_AdvanceTurn_Start)
---@field PendingFlakGunStreaks FlakGunPendingStreak[] | nil # Cleared once every streak has handed out its last temporary card

---Registers a newly fired Flak Gun for the remainder of this turn, and starts a temporary-card streak if this
---was the original card (not a temporary copy, not an Api call) and multiple rounds are configured.
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
---@param playerID PlayerID
---@param targetTerritoryID TerritoryID
---@param message string # Shown in the order list for the resulting event
---@param isOriginalCard boolean # True only when triggered by playing the actual Flak Gun card (not its temporary copy, and not the Api)
function FlakGunApplication.FireFlakGun(game, addNewOrder, playerID, targetTerritoryID, message, isOriginalCard)
	if (isOriginalCard and Mod.Settings.FlakGunRounds > 1) then
		-- playing the original card starts its own independent countdown; if the player has other active
		-- Flak Gun streaks running, this is in addition to those, not a replacement for them
		local priv = Mod.PrivateGameData --[[@as FlakGunPrivateGameData]];
		if (priv.PendingFlakGunStreaks == nil) then priv.PendingFlakGunStreaks = {}; end
		table.insert(priv.PendingFlakGunStreaks, { PlayerID = playerID, RemainingTurns = Mod.Settings.FlakGunRounds - 1 });
		Mod.PrivateGameData = priv;
	end

	local affectedTerritories = {};
	for _, territoryID in ipairs(GetTerritoriesWithinDistance(game, targetTerritoryID, Mod.Settings.FlakGunAreaOfEffect or 0)) do
		affectedTerritories[territoryID] = true;
	end

	---@type ActiveFlakGun
	local activeFlakGun = {
		TerritoryId = targetTerritoryID,
		PlayerOwnerId = playerID,
		AffectedTerritories = affectedTerritories
	};

	local priv = Mod.PrivateGameData --[[@as FlakGunPrivateGameData]];
	local activeFlakGuns = priv.ActiveFlakGuns or {};
	table.insert(activeFlakGuns, activeFlakGun);
	priv.ActiveFlakGuns = activeFlakGuns;
	Mod.PrivateGameData = priv;

	local td = game.Map.Territories[targetTerritoryID];
	local event = WL.GameOrderEvent.Create(playerID, message, {}, {});
	event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);

	local annotations = {};
	for territoryID, _ in pairs(affectedTerritories) do
		annotations[territoryID] = WL.TerritoryAnnotation.Create(".", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan));
	end
	annotations[targetTerritoryID] = WL.TerritoryAnnotation.Create("Flak", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan));
	event.TerritoryAnnotationsOpt = annotations;

	addNewOrder(event);
end

---Counts how many active Flak Guns (excluding friendly ones, unless friendly fire is enabled) cover territoryID.
---@param game GameServerHook
---@param activeFlakGuns ActiveFlakGun[]
---@param orderPlayerID PlayerID
---@param territoryID TerritoryID
---@return integer
local function CountFlakGunHits(game, activeFlakGuns, orderPlayerID, territoryID)
	local hitCount = 0;
	for _, flakGun in ipairs(activeFlakGuns) do
		local isFriendly = Mod.Settings.FlakGunFriendlyFire ~= true and ArePlayersFriendly(game, flakGun.PlayerOwnerId, orderPlayerID);
		if (not isFriendly and flakGun.AffectedTerritories[territoryID]) then
			hitCount = hitCount + 1;
		end
	end
	return hitCount;
end

---Skips the airlift order entirely (its armies never move), firing an explanatory event.
---@param order GameOrderPlayCardAirlift
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
---@param territoryID TerritoryID
---@param locationDescription string # e.g. "out of Alaska" / "into Alaska"
local function CancelAirliftOrder(order, skipThisOrder, addNewOrder, territoryID, locationDescription)
	skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage); --suppress the meaningless/detailless 'Mod skipped order' message, since the below message provides the details

	local message = "Airlift " .. locationDescription .. " was shot down by a Flak Gun";
	local event = WL.GameOrderEvent.Create(order.PlayerID, message, {}, {});
	event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Airlift Shot down", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)) };
	addNewOrder(event);
end

---@class FlakGunDamageHit
---@field DamagePercent number
---@field MinDamage number

---Applies every hit's percentage damage in sequence (compounding) to startingArmies, then clamps the result so
---total damage is never less than the sum of each hit's minimum damage.
---@param hits FlakGunDamageHit[]
---@param startingArmies integer
---@return integer remainingArmies
local function ApplyCompoundingDamage(hits, startingArmies)
	local remainingArmies = startingArmies;
	local totalMinDamage = 0;
	for _, hit in ipairs(hits) do
		remainingArmies = math.floor(remainingArmies * (1 - hit.DamagePercent) + 0.5);
		totalMinDamage = totalMinDamage + hit.MinDamage;
	end
	local minimumRemainingArmies = math.max(0, startingArmies - totalMinDamage);
	return math.min(remainingArmies, minimumRemainingArmies);
end

---Damages the armies transported by an airlift, applying one hit per Flak Gun that scored a damaging hit.
---@param order GameOrderPlayCardAirlift
---@param addNewOrder fun(order: GameOrder)
---@param armiesAirlifted Armies
---@param hits FlakGunDamageHit[]
---@param toTerritoryName string
local function DamageAirliftedArmies(order, addNewOrder, armiesAirlifted, hits, toTerritoryName)
	local remainingArmies = ApplyCompoundingDamage(hits, armiesAirlifted.NumArmies);

	local territoryModification = WL.TerritoryModification.Create(order.ToTerritoryID);
	territoryModification.SetArmiesTo = remainingArmies;

	local message = "Airlift into " .. toTerritoryName .. " was damaged by a Flak Gun(s)";
	local event = WL.GameOrderEvent.Create(order.PlayerID, message, {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.ToTerritoryID] = WL.TerritoryAnnotation.Create("Airlift Damaged", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Cordovan)) };
	addNewOrder(event);
end

---Checks an about-to-resolve Airlift order against every Flak Gun fired this turn, when Airlift Interaction is
---enabled. Its Airlift Source and Airlift Destination choices each independently either cancel the airlift
---outright or damage the transported armies. A cancel takes priority over damage, and Source is checked before
---Destination.
---@param game GameServerHook
---@param order GameOrderPlayCardAirlift
---@param result GameOrderPlayCardAirliftResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl)
---@param addNewOrder fun(order: GameOrder)
function FlakGunApplication.HandleAirliftTargetedByFlakGun(game, order, result, skipThisOrder, addNewOrder)
	if (not Mod.Settings.FlakGunAirliftInteractionEnabled) then return; end;

	---@type ActiveFlakGun[]
	local activeFlakGuns = (Mod.PrivateGameData --[[@as FlakGunPrivateGameData]]).ActiveFlakGuns or {};
	if (#activeFlakGuns == 0) then return; end;

	local sourceHits = CountFlakGunHits(game, activeFlakGuns, order.PlayerID, order.FromTerritoryID);
	local destinationHits = CountFlakGunHits(game, activeFlakGuns, order.PlayerID, order.ToTerritoryID);

	if (sourceHits > 0 and Mod.Settings.FlakGunSourceCancelsAirlift) then
		local fromTerritoryName = game.Map.Territories[order.FromTerritoryID].Name;
		CancelAirliftOrder(order, skipThisOrder, addNewOrder, order.FromTerritoryID, "out of " .. fromTerritoryName);
		return; --airlift never left, nothing more to do
	end

	if (destinationHits > 0 and Mod.Settings.FlakGunDestinationCancelsAirlift) then
		local toTerritoryName = game.Map.Territories[order.ToTerritoryID].Name;
		CancelAirliftOrder(order, skipThisOrder, addNewOrder, order.ToTerritoryID, "into " .. toTerritoryName);
		return; --airlift never arrives, nothing more to do
	end

	local hits = {};
	if (sourceHits > 0 and Mod.Settings.FlakGunSourceDamagesArmies) then
		for _ = 1, sourceHits do
			table.insert(hits, { DamagePercent = Mod.Settings.FlakGunSourceDamagePercent or 0, MinDamage = Mod.Settings.FlakGunSourceMinDamage or 0 });
		end
	end
	if (destinationHits > 0 and Mod.Settings.FlakGunDestinationDamagesArmies) then
		for _ = 1, destinationHits do
			table.insert(hits, { DamagePercent = Mod.Settings.FlakGunDestinationDamagePercent or 0, MinDamage = Mod.Settings.FlakGunDestinationMinDamage or 0 });
		end
	end

	if (#hits == 0) then return; end;

	local armiesAirlifted = result.ArmiesAirlifted;
	if (armiesAirlifted == nil or armiesAirlifted.IsEmpty) then return; end;

	local toTerritoryName = game.Map.Territories[order.ToTerritoryID].Name;
	DamageAirliftedArmies(order, addNewOrder, armiesAirlifted, hits, toTerritoryName);
end

--safety net for Client_GameCommit's proactive discard (e.g. AI players, or a client that never ran the hook):
--discards any Temp. Flak Gun cards still sitting unused in a player's hand, so they don't carry over into the
--next turn before this turn's active streaks hand out fresh ones
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function FlakGunApplication.DiscardUnusedTemporaryFlakGunCards(game, addNewOrder)
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
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder)
function FlakGunApplication.GiveTemporaryFlakGunCards(game, addNewOrder)
	local priv = Mod.PrivateGameData --[[@as FlakGunPrivateGameData]];
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
