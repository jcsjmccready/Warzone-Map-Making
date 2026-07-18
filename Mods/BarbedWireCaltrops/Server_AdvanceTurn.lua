require("Utilities");

-- todo: implement tank caltrop trigger logic
-- todo: imeplement tank caltrop move block logic
-- todo: handle blockading the struct

---Server_AdvanceTurn_Order
---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_Order(game, order, result, skipThisOrder, addNewOrder)

    if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateBarbedWire_")) then

        local targetTerritoryID = tonumber(string.sub(order.ModData, 18))
		if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
			return; --not our territory
		end

		-- store pending build orders for end of turn
		local pendingBarbedWire = {};
		pendingBarbedWire.PlayerID = order.PlayerID;
		pendingBarbedWire.Message = order.Description;
		pendingBarbedWire.TerritoryID = targetTerritoryID;

		local privateGameData = Mod.PrivateGameData;
		if (privateGameData.PendingBarbedWire == nil) then privateGameData.PendingBarbedWire = {}; end;
		table.insert(privateGameData.PendingBarbedWire, pendingBarbedWire);

		Mod.PrivateGameData = privateGameData;
    end

	if (order.proxyType == 'GameOrderPlayCardCustom' and startsWith(order.ModData, "CreateTankCaltrop_")) then

        local targetTerritoryID = tonumber(string.sub(order.ModData, 19))
		if (game.ServerGame.LatestTurnStanding.Territories[targetTerritoryID].OwnerPlayerID ~= order.PlayerID) then
			return; --not our territory
		end

		-- store pending build orders for end of turn
		local pendingTankCaltrop = {};
		pendingTankCaltrop.PlayerID = order.PlayerID;
		pendingTankCaltrop.Message = order.Description;
		pendingTankCaltrop.TerritoryID = targetTerritoryID;

		local privateGameData = Mod.PrivateGameData;
		if (privateGameData.PendingTankCaltrop == nil) then privateGameData.PendingTankCaltrop = {}; end;
		table.insert(privateGameData.PendingTankCaltrop, pendingTankCaltrop);

		Mod.PrivateGameData = privateGameData;
    end

	HandleAttackTransferInTriggeredStructure(game, order, result, skipThisOrder, addNewOrder);
	HandleAttackTransferToStructure(game, order, result, addNewOrder);
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
	ResetTriggeredStructures(game, addNewOrder);
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
---@param order GameOrder
---@param territoryID TerritoryID
---@return table | nil # The remaining structures after removing barbed wire, or nil if there was none
function OrderDestroysBarbedWire(game, addNewOrder, order, territoryID)
	local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
	local existingStructures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

	if (existingStructures == nil) then return nil; end;

	local isExistingBarbedWire =
		existingStructures ~= nil and
		((existingStructures[triggeredBarbedWireStructId] ~= nil and existingStructures[triggeredBarbedWireStructId] > 0)
		or (existingStructures[primedBarbedWireStructId] ~= nil and existingStructures[primedBarbedWireStructId] > 0));
	if (not isExistingBarbedWire) then return nil; end;

	local structures = {};
	structures[primedBarbedWireStructId] = 0;
	structures[triggeredBarbedWireStructId] = 0;

	for key, value in pairs(existingStructures or {}) do
		if(key ~= primedBarbedWireStructId and key ~= triggeredBarbedWireStructId) then
			structures[key] = value;
		end
	end

	local territoryModification = WL.TerritoryModification.Create(territoryID);
	territoryModification.SetStructuresOpt = structures;

	local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	addNewOrder(event, true);

	return structures;
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function HandleAttackTransferInTriggeredStructure(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	-- count structs
    local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	local triggeredTankCaltropStructId = WL.StructureType.Custom("TriggeredTankCaltrop");
    local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;

	if (existingStructures == nil) then return; end;
    
	local numberOfTriggeredBarbedWire = 0;
	if(Mod.Settings.IncludeBarbedWire) then
		if (existingStructures[triggeredBarbedWireStructId] ~= nil) then
		numberOfTriggeredBarbedWire = numberOfTriggeredBarbedWire + existingStructures[triggeredBarbedWireStructId];
		end
	end

    local numberOfTriggeredTankCaltrop = 0;
	if(Mod.Settings.IncludeTankCaltrop) then
		if (existingStructures[triggeredTankCaltropStructId] ~= nil) then
			numberOfTriggeredTankCaltrop = numberOfTriggeredTankCaltrop + existingStructures[triggeredTankCaltropStructId];
		end
	end

	--If no barbed wire or tank caltrop, abort.
	if (numberOfTriggeredBarbedWire == 0 and numberOfTriggeredTankCaltrop == 0) then return; end;

	-- count blockable units
	local orderTankCount = 0;
	if(Mod.Settings.IncludeTankCaltrop or Mod.Settings.BarbedWireTanksIgnore) then --implicit include barbed wire check
		if (result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
			for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
				if specialUnit ~= nil and specialUnit.Name == "Tank" then
					orderTankCount = orderTankCount + 1;
				end
			end
		end
	end

	local orderTroopCount = result.ActualArmies.NumArmies;
	
	-- movement blocking logic below
	-- determine whether to skip order or modify order based on remaining units
	local remainingTankCount = orderTankCount;
	local remainingTroopCount = orderTroopCount;
	
	if(numberOfTriggeredTankCaltrop > 0) then
		remainingTankCount = 0;
	end
	if(numberOfTriggeredBarbedWire > 0) then
		if(Mod.Settings.BarbedWireTanksIgnore and remainingTankCount > 0) then
			return; -- tanks present with 'tanks allowing troops to leave barbed wire' setting
		end
		remainingTroopCount = 0;
	end

	if(remainingTroopCount == 0 and remainingTankCount == 0) then
		-- skip order and annotate movement blocked
		skipThisOrder(WL.ModOrderControl.SkipAndSupressSkippedMessage);
		local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by barbed wire/tank caltrops', {}, {});
		event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Armies stuck", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
		addNewOrder(event);
	elseif(remainingTroopCount == 0 and remainingTankCount ~= 0) then
		-- modify order to only include tanks
		local tankSpecialUnits = {};
		if (result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
			for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
				if specialUnit ~= nil and specialUnit.Name == "Tank" then
					table.insert(tankSpecialUnits, specialUnit);
				end
			end
		end
		order.NumArmies = WL.Armies.Create(0, tankSpecialUnits);

		local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by barbed wire', {}, {});
		event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Troops stuck", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
		addNewOrder(event);
	else
		--modify order to only include troops
		order.NumArmies = WL.Armies.Create(remainingTroopCount);
		local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by tank caltrops', {}, {});
		event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Tanks stuck", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
		addNewOrder(event);
	end
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function HandleAttackTransferToStructure(game, order, result, addNewOrder)

	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	-- count structs
    local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
    local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
	local primedTankCaltropStructId = WL.StructureType.Custom("PrimedTankCaltrop");
	local triggeredTankCaltropStructId = WL.StructureType.Custom("TriggeredTankCaltrop");

    local existingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;

	if (existingStructuresTo == nil) then return; end;

	local numberOfPrimedTankCaltrop = 0;
	if(Mod.Settings.IncludeTankCaltrop) then
		if (existingStructuresTo[primedTankCaltropStructId] ~= nil) then
			numberOfPrimedTankCaltrop = numberOfPrimedTankCaltrop + existingStructuresTo[primedTankCaltropStructId];
		end
	end

	local orderHasTank = false;
	local orderHasNonTankSU = false;
	if(Mod.Settings.IncludeTankCaltrop or Mod.Settings.BarbedWireTanksDestroy) then --implicit include barbed wire check
		if (result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
			for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
				if specialUnit ~= nil then
					if (specialUnit.Name == "Tank")then
						orderHasTank = true;
					else
						orderHasNonTankSU = true;
					end
				end
			end
		end
	end

	local orderHasTroops = result.ActualArmies.NumArmies ~= 0;
	local orderHasWireTrigger = orderHasTroops or orderHasNonTankSU;

	-- -- handle tank destroy logic - track structures to not create a new triggered barbed wire if it was destroyed by a tank
	local remainingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
	if(Mod.Settings.BarbedWireTanksDestroy and orderHasTank) then
		remainingStructuresTo = OrderDestroysBarbedWire(game, addNewOrder, order, order.To) or remainingStructuresTo;
		OrderDestroysBarbedWire(game, addNewOrder, order, order.From);
	end

	-- -- change primed barbed wire to triggered barbed wire if the territory was attacked and the attack was successful
	if (not result.IsAttack or not result.IsSuccessful) then
		return;
	end

    local existingStructures = remainingStructuresTo;
	if (existingStructures == nil) then return; end;

    local numberOfPrimedBarbedWire = 0;
	if (existingStructures[primedBarbedWireStructId] ~= nil) then
		numberOfPrimedBarbedWire = numberOfPrimedBarbedWire + existingStructures[primedBarbedWireStructId];
	end

    --If an attack of 0, abort, so skipped orders don't trigger the barbed wire
	if (result.ActualArmies.IsEmpty) then return; end;

	-- abort if on same team and ally triggers is disabled
    local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
    local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;
    local ownerTeam = WL.PlayerID.Neutral;
	if(game.ServerGame.Game.Players[territoryOwnerPlayerID]) then
		ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
	end
	if(attackerTeam ~= nil 
		and ownerTeam ~= nil 
		and attackerTeam ~=-1
		and ownerTeam ~=-1
		and attackerTeam == ownerTeam 
		and Mod.Settings.BarbedWireAllyTriggers == false
	 	and Mod.Settings.TankCaltropAllyTriggers == false) then
		return;
	end;

	local structures = {};

	-- primed now becomes triggered 
	-- store triggered ids to not reset them at the end of the turn.
	local triggeredTerritoryId = order.To;
	local privateGameData = Mod.PrivateGameData;

	if (privateGameData.TriggeredBarbedWireTerritoryIds == nil) then privateGameData.TriggeredBarbedWireTerritoryIds = {}; end;
	if (privateGameData.TriggeredTankCaltropTerritoryIds == nil) then privateGameData.TriggeredTankCaltropTerritoryIds = {}; end;

	-- copy old structures but skip some
	for key, value in pairs(existingStructures or {}) do
		if((key ~= primedBarbedWireStructId and orderHasWireTrigger) or (key ~= primedTankCaltropStructId and orderHasTank)) then
			structures[key] = value;
		end
	end

	local triggeredWire = false;
	local triggeredCaltrop = false;
	if(orderHasWireTrigger and Mod.Settings.IncludeBarbedWire) then
		structures[primedBarbedWireStructId] = 0;
		structures[triggeredBarbedWireStructId] = numberOfPrimedBarbedWire;
		table.insert(privateGameData.TriggeredBarbedWireTerritoryIds, triggeredTerritoryId);
		triggeredWire = true;
	end
	if(orderHasTank and Mod.Settings.IncludeTankCaltrop) then
		structures[primedTankCaltropStructId] = 0;
		structures[triggeredTankCaltropStructId] = numberOfPrimedTankCaltrop;
		table.insert(privateGameData.TriggeredTankCaltropTerritoryIds, triggeredTerritoryId);
		triggeredCaltrop = true;
	end

	local territoryModification = WL.TerritoryModification.Create(order.To);
	territoryModification.SetStructuresOpt = structures;

	local message = "ERROR";
	if (triggeredWire and triggeredCaltrop) then
		message = "Triggered a Barbed Wire and Tank Caltrop";
	elseif (triggeredWire) then
		message = "Triggered a Barbed Wire";
	else
		message = "Triggered a Tank Caltrop";
	end

	local event = WL.GameOrderEvent.Create(order.PlayerID, message, {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create(message, 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	addNewOrder(event, true);
	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function ResetTriggeredStructures(game, addNewOrder)
	local privateGameData = Mod.PrivateGameData;

	if(Mod.Settings.IncludeBarbedWire) then
		local primedStructId = WL.StructureType.Custom("PrimedBarbedWire");
		local triggeredStructId = WL.StructureType.Custom("TriggeredBarbedWire");
		local triggeredTerritoryIds = privateGameData.TriggeredBarbedWireTerritoryIds or {};
		ResetStructure(game, addNewOrder, primedStructId, triggeredStructId, "Barbed Wire", triggeredTerritoryIds)
		privateGameData.TriggeredBarbedWireTerritoryIds = nil;
	end
	if(Mod.Settings.IncludeTankCaltrop) then
		local primedStructId = WL.StructureType.Custom("PrimedTankCaltrop");
		local triggeredStructId = WL.StructureType.Custom("TriggeredTankCaltrop");
		local triggeredTerritoryIds = privateGameData.TriggeredTankCaltropTerritoryIds or {};

		ResetStructure(game, addNewOrder, primedStructId, triggeredStructId, "Tank Caltrops", triggeredTerritoryIds);
		privateGameData.TriggeredTankCaltropTerritoryIds = nil;
	end

	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
---@param primedStructId EnumValue
---@param triggeredStructId EnumValue
---@param structName string
---@param triggeredTerritoryIds any
function ResetStructure(game, addNewOrder, primedStructId, triggeredStructId, structName, triggeredTerritoryIds)
	local anyReset = false;
	local triggeredTerritorySet = {};

	for _, territoryId in pairs(triggeredTerritoryIds) do
		triggeredTerritorySet[territoryId] = true;
	end

	local territoryModifications = {};
	for _, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if not triggeredTerritorySet[territory.ID] then
			local structures = territory.Structures;
			if (structures ~= nil and structures[triggeredStructId] ~= nil and structures[triggeredStructId] > 0) then
				structures[primedStructId] = (structures[primedStructId] or 0) + structures[triggeredStructId];
				structures[triggeredStructId] = 0;
				anyReset = true;
				local territoryModification = WL.TerritoryModification.Create(territory.ID);
				territoryModification.SetStructuresOpt = structures;

				table.insert(territoryModifications, territoryModification);
			end
		end
	end
	if (anyReset) then
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Reset ".. structName, {}, territoryModifications);
		addNewOrder(event);
	end
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function BuildStructures(game, addNewOrder)
	local privateGameData = Mod.PrivateGameData;
	if(Mod.Settings.IncludeBarbedWire) then
		BuildStructureType(game, addNewOrder, privateGameData.PendingBarbedWire, WL.StructureType.Custom("PrimedBarbedWire"), "Barbed Wire");
		privateGameData.PendingBarbedWire = nil;
	end
	if(Mod.Settings.IncludeTankCaltrop) then
		BuildStructureType(game, addNewOrder, privateGameData.PendingTankCaltrop, WL.StructureType.Custom("PrimedTankCaltrop"), "Tank Caltrop");
		privateGameData.PendingTankCaltrop = nil;
	end

	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function BuildStructureType(game, addNewOrder, pending, structureID, structureName)
	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPendingStructure = {};
	local remainingPendingStructure = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPendingStructure, pendingDms);
		else
			table.insert(remainingPendingStructure, pendingDms);
		end
	end

	pending = remainingPendingStructure;

	-- We will now build a structure for each pending structure. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingStructureGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numStructureToBuild = #pendingStructureGroup;

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = numStructureToBuild;
		else
			structures[structureID] = structures[structureID] + numStructureToBuild;
		end

		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingStructure = first(pendingStructureGroup);
		if (pendingStructure ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingStructure.PlayerID, pendingStructure.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build ".. structureName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };

			addNewOrder(event);
		end
	end

	for territoryID,pendingStructureGroup in pairs(groupBy(removedPendingStructure, function(t) return t.TerritoryID; end)) do
		local pendingStructure = first(pendingStructureGroup);
		if (pendingStructure ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingStructure.PlayerID, "Unable to build " .. structureName .. " on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build " .. structureName, 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };

			addNewOrder(event);
		end
	end
end