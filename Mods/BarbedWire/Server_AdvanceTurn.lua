require("Utilities");

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

	HandleAttackTransferInTriggeredBarbedWire(game, order, result, skipThisOrder, addNewOrder);
	HandleAttackTransferToBarbedWire(game, order, result, addNewOrder);
end

---Server_AdvanceTurn_End hook
---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function Server_AdvanceTurn_End(game, addNewOrder)
	BuildStructures(game, addNewOrder);
	ResetTriggeredBarbedWire(game, addNewOrder);
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param skipThisOrder fun(modOrderControl: EnumModOrderControl) # Allows you to skip the current order
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function HandleAttackTransferInTriggeredBarbedWire(game, order, result, skipThisOrder, addNewOrder)
	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	if (Mod.Settings.BarbedWireTanksIgnore and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
		local hasTank = false;
		for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
			if specialUnit ~= nil and specialUnit.proxyType == "CustomSpecialUnit" and specialUnit.Name == "Tank" then
				hasTank = true;
				break;
			end
		end

		if hasTank then
			return; -- tanks ignore barbed wire, so don't block movement
		end
	end

	-- movement blocking logic below

    local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
    local existingStructures = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;

	if (existingStructures == nil) then return; end;


    local numberOfTriggeredBarbedWire = 0;
	if (existingStructures[triggeredBarbedWireStructId] ~= nil) then
		numberOfTriggeredBarbedWire = numberOfTriggeredBarbedWire + existingStructures[triggeredBarbedWireStructId];
	end

	--If no barbed wire here, abort.
	if (numberOfTriggeredBarbedWire == 0) then return; end;

	-- block this attack
	result.ActualArmies = WL.Armies.Create(0);
	local event = WL.GameOrderEvent.Create(order.PlayerID, 'Movement blocked by barbed wire', {}, {});
	event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Armies stuck", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Blocked"
	addNewOrder(event);
end

---@param game GameServerHook
---@param order GameOrder
---@param result GameOrderResult
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function HandleAttackTransferToBarbedWire(game, order, result, addNewOrder)

	if (order.proxyType ~= 'GameOrderAttackTransfer') then
		return;
	end

	-- handle tank destroy logic - track structures to not create a new triggered barbed wire if it was destroyed by a tank
	local remainingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
	if (Mod.Settings.BarbedWireTanksDestroy and result.ActualArmies ~= nil and result.ActualArmies.SpecialUnits ~= nil) then
		local hasTank = false;
		for _, specialUnit in ipairs(result.ActualArmies.SpecialUnits) do
			if specialUnit ~= nil and specialUnit.proxyType == "CustomSpecialUnit" and specialUnit.Name == "Tank" then
				hasTank = true;
				break;
			end
		end

		if (hasTank) then
			local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
			local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
			
			-- tank removes any barbed wire structures on the territory it attacks
			local existingStructuresTo = game.ServerGame.LatestTurnStanding.Territories[order.To].Structures;
			local isExistingBarbedWireTo = 
				existingStructuresTo ~= nil and
				((existingStructuresTo[triggeredBarbedWireStructId] ~= nil and existingStructuresTo[triggeredBarbedWireStructId] > 0) 
				or (existingStructuresTo[primedBarbedWireStructId] ~= nil and existingStructuresTo[primedBarbedWireStructId] > 0));
			if(isExistingBarbedWireTo) then
				local structuresTo = {};
				structuresTo[primedBarbedWireStructId] = 0;
				structuresTo[triggeredBarbedWireStructId] = 0;

				-- copy old structures but skip wire
				for key, value in pairs(existingStructuresTo or {}) do
					if(key ~= primedBarbedWireStructId and key ~= triggeredBarbedWireStructId) then
						structuresTo[key] = value;
					end
				end
				
				local territoryModificationTo = WL.TerritoryModification.Create(order.To);
				territoryModificationTo.SetStructuresOpt = structuresTo;
				remainingStructuresTo = structuresTo;
				
				local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModificationTo});
				event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
				event.Icon = "Destroyed";
				addNewOrder(event, true);
			end
			
			-- tank removes any barbed wire structures on the territory it attacks from
			local existingStructuresFrom = game.ServerGame.LatestTurnStanding.Territories[order.From].Structures;
			local isExistingBarbedWireFrom = 
				existingStructuresFrom ~= nil and
				((existingStructuresFrom[triggeredBarbedWireStructId] ~= nil and existingStructuresFrom[triggeredBarbedWireStructId] > 0) 
				or (existingStructuresFrom[primedBarbedWireStructId] ~= nil and existingStructuresFrom[primedBarbedWireStructId] > 0));
			if(isExistingBarbedWireFrom) then
				local structuresFrom = {};
				structuresFrom[primedBarbedWireStructId] = 0;
				structuresFrom[triggeredBarbedWireStructId] = 0;

				-- copy old structures but skip wire
				for key, value in pairs(existingStructuresFrom or {}) do
					if(key ~= primedBarbedWireStructId and key ~= triggeredBarbedWireStructId) then
						structuresFrom[key] = value;
					end
				end
				
				local territoryModificationFrom = WL.TerritoryModification.Create(order.From);
				territoryModificationFrom.SetStructuresOpt = structuresFrom;
				
				local event = WL.GameOrderEvent.Create(order.PlayerID, 'Barbed wire destroyed', {}, {territoryModificationFrom});
				event.TerritoryAnnotationsOpt = { [order.From] = WL.TerritoryAnnotation.Create("Barbed wire destroyed", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
				event.Icon = "Destroyed";
				addNewOrder(event, true);
			end
		end
	end

	-- change primed barbed wire to triggered barbed wire if the territory was attacked and the attack was successful
	if (not result.IsAttack or not result.IsSuccessful) then
		return;
	end

    local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
    local existingStructures = remainingStructuresTo;

	if (existingStructures == nil) then return; end;

    local numberOfPrimedBarbedWire = 0;
	if (existingStructures[primedBarbedWireStructId] ~= nil) then
		numberOfPrimedBarbedWire = numberOfPrimedBarbedWire + existingStructures[primedBarbedWireStructId];
	end

	--If no barbed wire here, abort.
	if (numberOfPrimedBarbedWire == 0) then return; end;

    --If an attack of 0, abort, so skipped orders don't trigger the barbed wire
	if (result.ActualArmies.IsEmpty) then return; end;

	-- abort if on same team and ally triggers is disabled
    local territoryOwnerPlayerID = game.ServerGame.LatestTurnStanding.Territories[order.To].OwnerPlayerID;
    local attackerTeam = game.ServerGame.Game.Players[order.PlayerID].Team;

	local ownerTeam = WL.PlayerID.Neutral;
	if (game.ServerGame.Game.Players[territoryOwnerPlayerID] ~= nil) then
		ownerTeam = game.ServerGame.Game.Players[territoryOwnerPlayerID].Team;
	end

	if(attackerTeam ~= nil and ownerTeam ~= nil and attackerTeam ~=-1 and ownerTeam ~=-1 and attackerTeam == ownerTeam and Mod.Settings.BarbedWireAllyTriggers == false) then
		return;
	end;

	local structures = {};

	-- primed barbed wire now becomes triggered barbed wire
	-- store triggered ids to not reset them at the end of the turn.
	local triggeredTerritoryId = order.To;
	local privateGameData = Mod.PrivateGameData;
	if (privateGameData.TriggeredTerritoryIds == nil) then privateGameData.TriggeredTerritoryIds = {}; end;
	table.insert(privateGameData.TriggeredTerritoryIds, triggeredTerritoryId);

	-- copy old structures but skip wire
	for key, value in pairs(existingStructures or {}) do
		if(key ~= primedBarbedWireStructId) then
			structures[key] = value;
		end
	end

	structures[primedBarbedWireStructId] = 0;
    local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	structures[triggeredBarbedWireStructId] = numberOfPrimedBarbedWire;

	local territoryModification = WL.TerritoryModification.Create(order.To);
	territoryModification.SetStructuresOpt = structures;

	local event = WL.GameOrderEvent.Create(order.PlayerID, "Triggered a Barbed Wire", {}, {territoryModification});
	event.TerritoryAnnotationsOpt = { [order.To] = WL.TerritoryAnnotation.Create("Triggered Barbed Wire", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Mahogany)) };
	event.Icon = "Triggered";
	addNewOrder(event, true);
	Mod.PrivateGameData = privateGameData;

end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function ResetTriggeredBarbedWire(game, addNewOrder)
	local triggeredBarbedWireStructId = WL.StructureType.Custom("TriggeredBarbedWire");
	local primedBarbedWireStructId = WL.StructureType.Custom("PrimedBarbedWire");
	local anyReset = false;

	local privateGameData = Mod.PrivateGameData;
	local triggeredTerritoryIds = privateGameData.TriggeredTerritoryIds or {};
	local triggeredTerritorySet = {};

	for _, territoryId in pairs(triggeredTerritoryIds) do
		triggeredTerritorySet[territoryId] = true;
	end

	local territoryModifications = {};
	for _, territory in pairs(game.ServerGame.LatestTurnStanding.Territories) do
		if not triggeredTerritorySet[territory.ID] then
			local structures = territory.Structures;
			if (structures ~= nil and structures[triggeredBarbedWireStructId] ~= nil and structures[triggeredBarbedWireStructId] > 0) then
				structures[primedBarbedWireStructId] = (structures[primedBarbedWireStructId] or 0) + structures[triggeredBarbedWireStructId];
				structures[triggeredBarbedWireStructId] = 0;
				anyReset = true;
				local territoryModification = WL.TerritoryModification.Create(territory.ID);
				territoryModification.SetStructuresOpt = structures;

				table.insert(territoryModifications, territoryModification);
			end
		end
	end
	if (anyReset) then
		local event = WL.GameOrderEvent.Create(WL.PlayerID.Neutral, "Reset Barbed Wire", {}, territoryModifications);
		event.Icon = "Reset";
		addNewOrder(event);
	end


	privateGameData.TriggeredTerritoryIds = nil;
	Mod.PrivateGameData = privateGameData;
end

---@param game GameServerHook
---@param addNewOrder fun(order: GameOrder) # Adds a game order, will be processed before any of the rest of the orders
function BuildStructures(game, addNewOrder)

	local structureID = WL.StructureType.Custom("PrimedBarbedWire");

	local privateGameData = Mod.PrivateGameData;
	local pending = privateGameData.PendingBarbedWire;

	if (pending == nil) then return; end;

	-- Split pending builds into ones we can still build and ones we removed because ownership changed.
	local removedPendingBarbedWire = {};
	local remainingPendingBarbedWire = {};
	for _,pendingDms in pairs(pending) do
		if (pendingDms.PlayerID ~= game.ServerGame.LatestTurnStanding.Territories[pendingDms.TerritoryID].OwnerPlayerID) then
			table.insert(removedPendingBarbedWire, pendingDms);
		else
			table.insert(remainingPendingBarbedWire, pendingDms);
		end
	end

	pending = remainingPendingBarbedWire;

	-- We will now build a barbed wire for each pending barbed wire. However, we need to take care to ensure that if there are two build orders for the same territory that we build both of them,
	--	so we first group by the territory ID so we get all build orders for the same territory together.
	for territoryID,pendingBarbedWireGroup in pairs(groupBy(pending, function(t) return t.TerritoryID; end)) do

		local numBarbedWireToBuild = #pendingBarbedWireGroup;

		local structures = game.ServerGame.LatestTurnStanding.Territories[territoryID].Structures;

		if (structures == nil) then structures = {}; end;
		if (structures[structureID] == nil) then
			structures[structureID] = numBarbedWireToBuild;
		else
			structures[structureID] = structures[structureID] + numBarbedWireToBuild;
		end

		local territoryModification = WL.TerritoryModification.Create(territoryID);
		territoryModification.SetStructuresOpt = structures;

		local pendingBarbedWire = first(pendingBarbedWireGroup);
		if (pendingBarbedWire ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingBarbedWire.PlayerID, pendingBarbedWire.Message, {}, {territoryModification});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Build Barbed Wire", 8, GetColourIntegerFromHex(BUTTON_COLOURS.DarkGreen)) };
			event.Icon = "Build";

			addNewOrder(event);
		end
	end

	for territoryID,pendingBarbedWireGroup in pairs(groupBy(removedPendingBarbedWire, function(t) return t.TerritoryID; end)) do
		local pendingBarbedWire = first(pendingBarbedWireGroup);
		if (pendingBarbedWire ~= nil) then
			local event = WL.GameOrderEvent.Create(pendingBarbedWire.PlayerID, "Unable to build Barbed Wire on " .. game.Map.Territories[territoryID].Name, {}, {});

			local td = game.Map.Territories[territoryID];
			event.JumpToActionSpotOpt = WL.RectangleVM.Create(td.MiddlePointX, td.MiddlePointY, td.MiddlePointX, td.MiddlePointY);
			event.TerritoryAnnotationsOpt = { [territoryID] = WL.TerritoryAnnotation.Create("Unable to build Barbed Wire", 8, GetColourIntegerFromHex(BUTTON_COLOURS.Red)) };
			event.Icon = "BuildFailed";

			addNewOrder(event);
		end
	end

	privateGameData.PendingBarbedWire = nil;
	Mod.PrivateGameData = privateGameData;
end