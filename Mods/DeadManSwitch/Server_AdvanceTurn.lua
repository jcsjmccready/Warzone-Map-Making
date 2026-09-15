require("Utilities");

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
        local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;

		if (existingStructures == nil) then return; end;

        local numberOfDMS = 0;
		if (existingStructures[structureID] ~= nil) then
			numberOfDMS = numberOfDMS + existingStructures[structureID];
		end

		--If no DMS here, abort.
		if (numberOfDMS == 0) then return; end;

        --If an attack of 0, abort, so skipped orders don't destroy the DMS
		if (result.ActualArmies.IsEmpty) then return; end;

		-- abort if on same team and ally triggers is disabled
        local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
        local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
		local ownerTeam = WL.PlayerID.Neutral;
		if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
	        ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
		end

		if(attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~=-1 and ownerTeam ~=-1 and attackerTeam == ownerTeam and Mod.Settings.AllyTriggers == false) then
			return;
		end;

		local structures = {};

		-- copy old structures but skip dms
		for key, value in pairs(existingStructures or {}) do
			if(key ~= structureID) then
				structures[key] = value;
			end;
		end

		structures[structureID] = 0;
		local territoryModification = WL.TerritoryModification.Create(order.To);
		territoryModification.SetStructuresOpt = structures;

		Trigger_Primary_Action(territoryModification, game, order, result, addNewOrder, numberOfDMS);
		Trigger_Secondary_Actions(territoryModification, game, order, result, addNewOrder, numberOfDMS);
    end
end

function Add_Dms_Triggered_Event(order, territoryModification, addNewOrder)
	local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Dead Man's Switch", {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered DMS", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Triggered";
	addNewOrder(event, true);
end

function Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, cardName)
	-- this should be impossible to reach but safety net, in case the required card isn't enabled in the game settings
	addNewOrder(WL.GameOrderEvent.Create(order.PlayerID, cardName .. " card not available - DMS action cancelled", {}, {territoryModification}), true);
end

function Trigger_Primary_Action(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	if (Mod.Settings.isDamageTypeBomb) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Bomb] ~= nil then
        	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;

			Add_Dms_Triggered_Event(order, territoryModification, addNewOrder);

			for _ = 1, numberOfDMS do
				local instance = WL.NoParameterCardInstance.Create(WL.CardID.Bomb);
				addNewOrder(WL.GameOrderReceiveCard.Create(defendingPlayer, {instance}));
				addNewOrder(WL.GameOrderPlayCardBomb.Create(instance.ID, defendingPlayer, order.To));
			end
		else
			Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, "Bomb");
        end
	elseif (Mod.Settings.isDamageTypeFlat) then
		local damageAmount = Mod.Settings.FlatDamage * numberOfDMS;
		local damageArmies = WL.Armies.Create(damageAmount + result.AttackingArmiesKilled.NumArmies);
		territoryModification.SetArmiesTo = result.ActualArmies.Subtract(damageArmies).NumArmies;

		Add_Dms_Triggered_Event(order, territoryModification, addNewOrder);

	elseif (Mod.Settings.isDamageTypeBlockade) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Blockade] ~= nil then
        	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

			Add_Dms_Triggered_Event(order, territoryModification, addNewOrder);

			-- blockade cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
			local privateGameData = Mod.PrivateGameData;
			if (privateGameData.PendingBlockade == nil) then privateGameData.PendingBlockade = {}; end;

			for _ = 1, numberOfDMS do
				table.insert(privateGameData.PendingBlockade, { PlayerID = attackingPlayer, TerritoryID = order.To });
			end

			Mod.PrivateGameData = privateGameData;
		else
			Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, "Blockade");
        end
	elseif (Mod.Settings.isDamageTypeEmergencyBlockade) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.EmergencyBlockade] ~= nil then
        	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

			Add_Dms_Triggered_Event(order, territoryModification, addNewOrder);

			for _ = 1, numberOfDMS do
				local instance = WL.NoParameterCardInstance.Create(WL.CardID.EmergencyBlockade);
				addNewOrder(WL.GameOrderReceiveCard.Create(attackingPlayer, {instance}));
				addNewOrder(WL.GameOrderPlayCardAbandon.Create(instance.ID, attackingPlayer, order.To));
			end
		else
			Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, "Emergency Blockade");
        end
	elseif (Mod.Settings.isDamageTypeNuke) then
		local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
		local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

		Add_Dms_Triggered_Event(order, territoryModification, addNewOrder);

		for _ = 1, numberOfDMS do
			local payload = "Nuke|Invoke|" .. defendingPlayer .. "|" .. attackingPlayer .. "|" .. order.To;
			addNewOrder(WL.GameOrderCustom.Create(defendingPlayer, "Nuke", payload, nil));
		end
	elseif (Mod.Settings.isDamageTypePercent) then
		local armiesAfterAttack = result.ActualArmies.NumArmies - result.AttackingArmiesKilled.NumArmies;
		local remainingArmies = armiesAfterAttack;

		for _ = 1, numberOfDMS do
			remainingArmies = math.floor(remainingArmies * (1 - Mod.Settings.PercentageDamage) + 0.5);
		end

		local minimumRemainingArmies = math.max(0, armiesAfterAttack - (Mod.Settings.PercentageMinDamage * numberOfDMS));
		territoryModification.SetArmiesTo = math.min(remainingArmies, minimumRemainingArmies);

		Add_Dms_Triggered_Event(order, territoryModification, addNewOrder);
	end
end

function Trigger_Secondary_Actions(territoryModification, game, order, result, addNewOrder, numberOfDMS)
	-- these trigger actions are independent toggles and can stack with each other and with the damage type above
	if (Mod.Settings.isDamageTypeSanction) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Sanctions] ~= nil then
        	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
        	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

			for _ = 1, numberOfDMS do
				local instance = WL.NoParameterCardInstance.Create(WL.CardID.Sanctions);
				addNewOrder(WL.GameOrderReceiveCard.Create(defendingPlayer, {instance}));
				addNewOrder(WL.GameOrderPlayCardSanctions.Create(instance.ID, defendingPlayer, attackingPlayer));
			end
		else
			Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, "Sanction");
        end
	end

	if (Mod.Settings.isDamageTypeDiplomacy) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Diplomacy] ~= nil then
        	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
        	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

			-- diplomacy cards are normally played at the end of the turn, so store them for end of turn instead of playing them immediately
			local privateGameData = Mod.PrivateGameData;
			if (privateGameData.PendingDiplomacy == nil) then privateGameData.PendingDiplomacy = {}; end;

			for _ = 1, numberOfDMS do
				table.insert(privateGameData.PendingDiplomacy, { PlayerID = defendingPlayer, PlayerOne = defendingPlayer, PlayerTwo = attackingPlayer });
			end

			Mod.PrivateGameData = privateGameData;
		else
			Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, "Diplomacy");
        end
	end

	if (Mod.Settings.isDamageTypeSpy) then
		-- unable to programatically play cards without them being enabled
        if game.Settings.Cards ~= nil and game.Settings.Cards[WL.CardID.Spy] ~= nil then
        	local defendingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
        	local attackingPlayer = game.ServerGame.LatestTurnStanding.Territories[order.From].OwnerPlayerID;

			for _ = 1, numberOfDMS do
				local instance = WL.NoParameterCardInstance.Create(WL.CardID.Spy);
				addNewOrder(WL.GameOrderReceiveCard.Create(defendingPlayer, {instance}));
				addNewOrder(WL.GameOrderPlayCardSpy.Create(instance.ID, defendingPlayer, attackingPlayer));
			end
		else
			Add_Dms_Cancelled_Card_Action_Event(order, territoryModification, addNewOrder, "Spy");
        end
	end
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
	PlayPendingBlockades(addNewOrder);
	PlayPendingDiplomacy(addNewOrder);
end

function PlayPendingBlockades(addNewOrder)

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

function PlayPendingDiplomacy(addNewOrder)

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
			event.Icon = "Build";

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
			event.Icon = "BuildFailed";

			addNewOrder(event);
		end
	end

	privateGameData.PendingDMS = nil;
	Mod.PrivateGameData = privateGameData;
end