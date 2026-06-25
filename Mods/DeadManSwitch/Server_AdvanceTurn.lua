require("Utilities");

-- test ally triggers
-- structure not being removed on server-side
-- force bomb setting not working

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateDMS_")) then

        local targetTerritoryID = tonumber(string.sub(order.ModData, 11))
		if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
			return; --not our territory
		end

		-- store pending build orders for end of turn
		local pendingDMS = {};
		pendingDMS.PlayerID = order.PlayerID;
		pendingDMS.Message = order.Description;
		pendingDMS.TerritoryID = targetTerritoryID;

		local privateGameData = Mod.PrivateGameData;
		if (privateGameData.PendingDMS == nil) then privateGameData.PendingDMS = {}; end;
		table.insert(privateGameData.PendingDMS, pendingDMS);

		Mod.PrivateGameData = privateGameData;
    end

	-- --Check if this is an attack against a territory with a dms.
	if (order.proxyType == 'GameOrderAttackTransfer' and result.IsAttack and result.IsSuccessful) then
        local structureID = WL.StructureType.Custom("Dead Man's Switch");
        local structures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;

		if (structures == nil) then return; end;

        local numberOfDMS = 0;
		if (structures[structureID] ~= nil) then
			numberOfDMS = numberOfDMS + structures[structureID];
		end

		--If no DMS here, abort.
		if (numberOfDMS == 0) then return; end;

        --If an attack of 0, abort, so skipped orders don't destroy the DMS
		if (result.ActualArmies.IsEmpty) then return; end;

		-- abort if on same team and ally triggers is disabled
        local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
        local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
        local ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
		if(attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~=-1 and ownerTeam ~=-1 and attackerTeam == ownerTeam and Mod.Settings.AllyTriggers == false) then
			return;
		end;

		Trigger_Dms_Damage(structureID, game, order, result, addNewOrder, numberOfDMS);
    end
end

function Trigger_Dms_Damage(structureID, game, order, result, addNewOrder, numberOfDMS)
	local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
	local structures = {};

	for key, value in pairs(existingStructures or {}) do
		if(key ~= structureID) then
			structures[key] = value;
		end;
	end

	structures[structureID] = 0;
	local territoryModification = WL.TerritoryModification.Create(order.To);
	territoryModification.SetStructuresOpt = structures;

	if (Mod.Settings.isDamageTypeBomb) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Bomb] ~= nil then
        	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;

			local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification});
			event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
			addNewOrder(event, true);

			for _ = 1, numberOfDMS do
				local instance = WL.NoParameterCardInstance.Create(WL.CardID.Bomb);
				addNewOrder(WL.GameOrderReceiveCard.Create(defendingPlayer, {instance}));
				addNewOrder(WL.GameOrderPlayCardBomb.Create(instance.ID, defendingPlayer, order.To));
			end
		else
			addNewOrder(WL.GameOrderEvent.Create(order.PlayerID, "Bomb card not available - DMS cancelled", {}, {territoryModification}), true); -- this should be impossible to reach but safety net
        end
	elseif (Mod.Settings.isDamageTypeFlat) then
		local damageAmount = Mod.Settings.FlatDamage * numberOfDMS;
		local damageArmies = WL.Armies.Create(damageAmount + result.AttackingArmiesKilled.NumArmies);
		territoryModification.SetArmiesTo = result.ActualArmies.Subtract(damageArmies).NumArmies;

		local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification});
		event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
		addNewOrder(event, true);

	elseif (Mod.Settings.isDamageTypePercent) then
		local armiesAfterAttack = result.ActualArmies.NumArmies - result.AttackingArmiesKilled.NumArmies;
		local remainingArmies = armiesAfterAttack;

		for _ = 1, numberOfDMS do
			remainingArmies = math.floor(remainingArmies * (1 - Mod.Settings.PercentageDamage) + 0.5);
		end

		local minimumRemainingArmies = math.max(0, armiesAfterAttack - Mod.Settings.PercentageMinDamage);
		territoryModification.SetArmiesTo = math.min(remainingArmies, minimumRemainingArmies);

		local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification});
		event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
		addNewOrder(event, true);
	end

	local values = GetTableValues(structures);
	print(values);
	local loggingEvent = WL.GameOrderEvent.Create(order.PlayerID, values, {}, {territoryModification});
	addNewOrder(loggingEvent, true);

end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
end

function BuildStructures(game, addNewOrder)

	local structureID = WL.StructureType.Custom("Dead Man's Switch");

	local privateGameData = Mod.PrivateGameData;
	local pending = privateGameData.PendingDMS;

	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPendingDMS = {};
	local remainingPendingDMS = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPendingDMS, pendingDms);
		else
			table.insert(remainingPendingDMS, pendingDms);
		end
	end

	pending = remainingPendingDMS;

	-- We will now build a DMS for each pending DMS. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingDmsGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numDmsToBuild = #pendingDmsGroup;

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = numDmsToBuild;
		else
			structures[structureID] = structures[structureID] + numDmsToBuild;
		end

		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingDms = first(pendingDmsGroup);
		if (pendingDms ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, pendingDms.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };

			addNewOrder(event);
		end
	end

	for territoryID,pendingDmsGroup in pairs(groupBy(removedPendingDMS, function(t) return t.TerritoryID; end)) do
		local pendingDms = first(pendingDmsGroup);
		if (pendingDms ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingDms.PlayerID, "Unable to build Dead Man's Switch on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };

			addNewOrder(event);
		end
	end

	privateGameData.PendingDMS = nil;
	Mod.PrivateGameData = privateGameData;
end